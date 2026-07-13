#!/usr/bin/env bash
# Generate a fresh age key for a host, deploy it, and update sops config.
#
# Usage:  nixos/scripts/rekey-host.sh <hostname> [ssh-target]
#
# What it does:
#   1. Generates a new age key pair.
#   2. Adds/replaces the host's entry in nixos/secrets/hosts.yaml (sops-encrypted).
#   3. Adds/replaces the host's alias in .sops.yaml `keys:` block and, if a
#      placeholder exists, uncomments the host in the users.yaml creation_rule.
#   4. Deploys the private key to <ssh-target>:/var/lib/sops-nix/key.txt via ssh.
#   5. Runs `sops updatekeys` on every file under nixos/secrets/ so the new
#      recipient list takes effect.
#
# Idempotent: re-run for the same host to rotate its key.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <hostname> [ssh-target]" >&2
  exit 1
fi

HOST=$1
TARGET=${2:-$HOST}

# Resolve paths relative to this script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$NIXOS_DIR/.." && pwd)"

SOPS_YAML="$REPO_ROOT/.sops.yaml"
SECRETS_DIR="$NIXOS_DIR/secrets"
HOSTS_FILE="$SECRETS_DIR/hosts.yaml"

for cmd in age-keygen sops ssh scp awk sed; do
  command -v "$cmd" >/dev/null || {
    echo "error: required command '$cmd' not found on PATH" >&2
    exit 1
  }
done

# yq (mikefarah's Go implementation). Prefer a pre-installed `yq-go` or `yq`
# from mikefarah; otherwise fall back to running it out of nixpkgs.
if command -v yq-go >/dev/null; then
  yq_cmd() { yq-go "$@"; }
elif command -v yq >/dev/null && yq --version 2>&1 | grep -q 'mikefarah'; then
  yq_cmd() { yq "$@"; }
else
  yq_cmd() {
    nix --extra-experimental-features "nix-command flakes" run nixpkgs#yq-go -- "$@"
  }
fi

tmp=$(mktemp -d)
chmod 700 "$tmp"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

log() { printf '==> %s\n' "$*"; }

log "generating fresh age key for $HOST"
age-keygen -o "$tmp/key.txt" 2>/dev/null
chmod 600 "$tmp/key.txt"
PUBKEY=$(age-keygen -y "$tmp/key.txt")
log "    public: $PUBKEY"

# ---- Update .sops.yaml ----------------------------------------------------
log "updating $SOPS_YAML"

if grep -qE "^  - &${HOST} " "$SOPS_YAML"; then
  # Existing anchor: replace the recipient.
  sed -i -E "s|^  - &${HOST} .*|  - \&${HOST} ${PUBKEY}|" "$SOPS_YAML"
  echo "    updated existing &${HOST}"
elif grep -qE "^  # - &${HOST}[[:space:]]" "$SOPS_YAML"; then
  # Commented placeholder: uncomment + set the recipient.
  sed -i -E "s|^  # - &${HOST}[[:space:]].*|  - \&${HOST} ${PUBKEY}|" "$SOPS_YAML"
  echo "    uncommented &${HOST}"
else
  # Insert a new anchor after &yubikey.
  sed -i -E "/^  - &yubikey /a\\
  - \&${HOST} ${PUBKEY}" "$SOPS_YAML"
  echo "    inserted new &${HOST}"
fi

# Uncomment or insert the host as a recipient under users.yaml's creation_rule.
if grep -qE "^          - \*${HOST}$" "$SOPS_YAML"; then
  echo "    *${HOST} already listed under users.yaml recipients"
elif grep -qE "^          # - \*${HOST}$" "$SOPS_YAML"; then
  sed -i -E "s|^          # - \*${HOST}$|          - *${HOST}|" "$SOPS_YAML"
  echo "    uncommented *${HOST} under users.yaml recipients"
else
  # Insert *<host> after the last recipient line of users.yaml's creation_rule.
  # We locate the block by matching `users\.yaml$` and appending after the
  # last `          - *…` line that follows it (before the next blank line).
  awk -v host="$HOST" '
    BEGIN { inblock = 0; last_recip = 0 }
    /users\.yaml/ && /path_regex/ { inblock = 1 }
    inblock && /- path_regex/ && !/users\.yaml/ { inblock = 0 }
    inblock && /^          - \*/ { last_recip = NR }
    { line[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        print line[i]
        if (i == last_recip) printf "          - *%s\n", host
      }
    }
  ' "$SOPS_YAML" > "$tmp/sops-yaml.new" && mv "$tmp/sops-yaml.new" "$SOPS_YAML"
  echo "    inserted *${HOST} into users.yaml recipients"
fi

# ---- Update nixos/secrets/hosts.yaml -------------------------------------
log "updating $HOSTS_FILE"

mkdir -p "$SECRETS_DIR"

plain="$tmp/hosts-plain.yaml"
if [ -f "$HOSTS_FILE" ]; then
  if ! sops -d "$HOSTS_FILE" > "$plain" 2>"$tmp/sops-err"; then
    cat "$tmp/sops-err" >&2
    echo "error: cannot decrypt existing $HOSTS_FILE with current identities." >&2
    echo "       Delete it (rm $HOSTS_FILE) and re-run this script." >&2
    exit 1
  fi
else
  echo "hosts: {}" > "$plain"
fi

# Merge in this host's key using yq. Setting a multi-line string writes it
# using yq's default block style (`|`), which is what we want for the key body.
export HOST PUBKEY
KEY_TEXT=$(cat "$tmp/key.txt")
export KEY_TEXT
yq_cmd eval -i '
  .hosts[strenv(HOST)].age.publicKey  = strenv(PUBKEY) |
  .hosts[strenv(HOST)].age.privateKey = strenv(KEY_TEXT) |
  .hosts[strenv(HOST)].age.privateKey style="literal"
' "$plain"

# Encrypt back into place. Use --filename-override so sops picks the
# hosts.yaml creation_rule (yubikey-only). Fall back to a rename dance
# if --filename-override isn't supported.
if sops -e --filename-override "$HOSTS_FILE" "$plain" > "$HOSTS_FILE.new" 2>/dev/null; then
  mv "$HOSTS_FILE.new" "$HOSTS_FILE"
else
  cp "$plain" "$HOSTS_FILE"
  sops -e -i "$HOSTS_FILE"
fi
echo "    hosts.yaml updated"

# ---- Deploy key to target host -------------------------------------------
log "deploying key to root@${TARGET}:/var/lib/sops-nix/key.txt"
# Split each ssh call into a single command — avoids shell-syntax surprises
# on hosts where root's login shell isn't bash (e.g. nushell doesn't support
# `&&`, though it does accept `;`).
ssh "root@${TARGET}" 'install -d -m 700 -o root -g root /var/lib/sops-nix'
scp -q "$tmp/key.txt" "root@${TARGET}:/var/lib/sops-nix/key.txt"
ssh "root@${TARGET}" 'chmod 600 /var/lib/sops-nix/key.txt'
ssh "root@${TARGET}" 'chown root:root /var/lib/sops-nix/key.txt'

# ---- Rekey remaining secrets so new recipient list applies ---------------
log "running sops updatekeys on nixos/secrets/*.yaml"
for f in "$SECRETS_DIR"/*.yaml; do
  [ -f "$f" ] || continue
  # hosts.yaml was just written with the current recipient list.
  [ "$f" = "$HOSTS_FILE" ] && continue
  echo "    updatekeys $(basename "$f")"
  if ! sops updatekeys -y "$f" 2>&1 | sed 's/^/        /'; then
    echo "    (updatekeys failed for $f; skipping)"
  fi
done

log "done."
echo
echo "Verify on the host:"
echo "  ssh root@${TARGET} 'sudo cat /var/lib/sops-nix/key.txt | age-keygen -y -'"
echo "  expected: ${PUBKEY}"
