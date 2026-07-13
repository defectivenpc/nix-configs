# Secrets

All sops-encrypted secrets live under this directory. Encryption rules are defined in the repo-root [`.sops.yaml`](../../.sops.yaml).

## Layout

| File | Purpose | Recipients |
|---|---|---|
| `users.yaml` | Shared password hashes (`whitehead-password`, `family-password`) | YubiKey + every host that needs to decrypt user passwords |
| `hosts.yaml` | Central inventory of per-host age keys; consumed by `../fresh-install.sh` during nixos-anywhere installs | YubiKey only |
| `authority.yaml` | authority-only extras (YubiKey PIN/PUK, JWK provisioner key) | YubiKey + authority |
| `nas2.yaml` | nas2-only extras (ZFS syncoid ssh key) | YubiKey + nas2 |

Additional per-host files should follow the pattern: name them `<host>.yaml`, add a matching `creation_rules` entry to `.sops.yaml` with just YubiKey + that host's age key, then reference them from the host module via `sops.secrets.<name>.sopsFile = ../../secrets/<host>.yaml;`.

## Wiring in NixOS modules

`lib/sops.nix` sets `sops.defaultSopsFile = ../secrets/users.yaml`, so every secret defined without an explicit `sopsFile` is looked up in `users.yaml`. Host-specific secrets set `sopsFile` per-secret (see `machines/nas2/nas2.nix` for an example).

- `lib/users.nix` — defines the `whitehead` user + `sops.secrets.whitehead-password`. Auto-included by `mkHost` in `flake.nix`.
- `lib/family-user.nix` — defines the `family` user + `sops.secrets.family-password`. Opt-in per host: add `../../lib/family-user.nix` to that host's `imports`.

## Adding or rotating a host key

Use the helper script — it generates a fresh age key, deploys it, updates `hosts.yaml`, updates `.sops.yaml`, and rekeys `nixos/secrets/*.yaml` so the new recipient list takes effect.

```
nixos/scripts/rekey-host.sh <hostname> [ssh-target]
```

Idempotent: re-running against an existing host rotates its key. Requires `age`, `sops`, `ssh`, `scp`, and `python3` on your operator machine, plus the YubiKey plugged in so `sops updatekeys` can decrypt-then-re-encrypt.

If the script fails partway through `sops updatekeys` (usually because a file is encrypted to a dead recipient), delete the affected file, recreate it after all hosts are keyed, and re-run.

## Bootstrap workflow (first-time setup after the reorg)

The reorg deleted all the old per-host `whitehead-password` files. Before any host with `includeSops = true` can activate a new generation, `users.yaml` must exist and contain hashes for the users declared on that host.

### 1. Generate password hashes

```
mkpasswd -m sha-512
# type password, hit enter — copy the resulting $6$… hash
```

Do this twice: once for `whitehead`, once for `family`.

### 2. Create `nixos/secrets/users.yaml`

```
cd ~/nix-config
sops nixos/secrets/users.yaml
```

sops will open your `$EDITOR` on a fresh file, encrypting to the recipients matched by `.sops.yaml` (currently YubiKey + authority + nas2). Paste:

```yaml
whitehead-password: "$6$…hash for whitehead…"
family-password: "$6$…hash for family…"
```

Save and exit — sops encrypts on save.

### 3. Add per-host age keys to `.sops.yaml`

Every host that runs a NixOS build using `mkHost` needs to be able to decrypt `users.yaml`. Right now only authority + nas2 are recipients.

For each additional host:

**If the host already has an age key** (only nas1 falls in this bucket — its key is in `hosts.yaml`):

```
# from an operator machine with the YubiKey plugged in
sops -d --extract '["hosts"]["nas1"]["age"]["publicKey"]' nixos/secrets/hosts.yaml
# copy the age1… output
```

Add it as an anchor + reference in `.sops.yaml`:

```yaml
keys:
  ...
  - &nas1 age1…
creation_rules:
  - path_regex: nixos/secrets/users\.yaml$
    key_groups:
      - age:
          - *yubikey
          - *authority
          - *nas2
          - *nas1     # <-- add
```

Then rekey the file so nas1 can decrypt it:

```
sops updatekeys nixos/secrets/users.yaml
```

**If the host does not yet have an age key** (mises, beara, sowell, buster, bigtux, router, all k8s nodes):

Generate one. On the host itself (or if you're bootstrapping via `fresh-install.sh`, generate during install):

```
# on the host, converting its SSH host key to an age key:
nix run nixpkgs#ssh-to-age -- -private-key -i /etc/ssh/ssh_host_ed25519_key > /var/lib/sops-nix/key.txt
chmod 600 /var/lib/sops-nix/key.txt

# then derive the corresponding public age recipient:
nix run nixpkgs#ssh-to-age -- -i /etc/ssh/ssh_host_ed25519_key.pub
```

Copy the resulting `age1…` into `.sops.yaml` (both as an anchor and as a recipient of `users.yaml`), and run `sops updatekeys nixos/secrets/users.yaml`.

For **new** installs, add the host's private key to `hosts.yaml` first so `fresh-install.sh` seeds `/var/lib/sops-nix/key.txt` automatically:

```
sops nixos/secrets/hosts.yaml
```

Then in the editor:

```yaml
hosts:
  <newhost>:
    age:
      publicKey: age1…
      privateKey: AGE-SECRET-KEY-1…
```

### 4. Rebuild

Once `users.yaml` exists and the target host is a recipient:

```
sudo nixos-rebuild switch --flake .#mises
```

sops-nix decrypts `users.yaml` at activation using `/var/lib/sops-nix/key.txt` and writes `whitehead-password` (and, on hosts that import `family-user.nix`, `family-password`) into `/run/secrets/`. NixOS points `users.users.<name>.hashedPasswordFile` at those paths.

## Rotating a password

```
sops nixos/secrets/users.yaml
# edit, save
sudo nixos-rebuild switch --flake .#<host>
```

Then `passwd` on the host will use the new hash immediately.

## Adding a new host to the recipient set later

```
# 1. add its age recipient anchor + alias to .sops.yaml (both keys: block and users.yaml creation_rule)
# 2. rekey affected files:
sops updatekeys nixos/secrets/users.yaml
# 3. rebuild the new host
```

## Notes / gotchas

- `hosts.yaml` is intentionally YubiKey-only. It contains raw age private keys that are used to bootstrap new machines; no running host should ever be able to decrypt it. Access requires physically inserting the YubiKey on an operator machine.
- If `sops.secrets.<name>` is declared but the encrypted file doesn't contain that key, sops-nix fails at activation. If you add a new secret name, add its entry to `users.yaml` (or the appropriate host file) *before* rebuilding.
- Bob, tom, bigtux are currently built with `mkBareHost` (`includeSops = false`), so they don't decrypt anything and don't need to be recipients until you migrate them to `mkHost`.
