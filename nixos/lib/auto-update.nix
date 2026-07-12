{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.nixAutoUpdate;

  stateDir = "/var/lib/nix-auto-update";

  hostname = config.networking.hostName;

  runScript = pkgs.writeShellApplication {
    name = "nix-auto-update-run";
    runtimeInputs = with pkgs; [
      git
      nix
      nvd
      coreutils
      util-linux
      systemd
    ];
    text = ''
      set -euo pipefail

      REPO="${cfg.repoPath}"
      FLAKE_URL="${cfg.flakeUrl}"
      BRANCH="${cfg.branch}"
      SUBDIR="${cfg.flakeSubdir}"
      STATE="${stateDir}"
      HOST="${hostname}"

      mkdir -p "$STATE"

      status_file="$STATE/last-status"
      log_file="$STATE/last-run.log"
      failure_log="$STATE/last-failure.log"
      motd_file="$STATE/motd"

      write_status() {
        printf '%s\n' "$1" > "$status_file"
      }

      write_motd() {
        printf '%s\n' "$1" > "$motd_file"
      }

      on_failure() {
        write_status "failed"
        journalctl -u nix-auto-update.service -n 200 --no-pager > "$failure_log" || true
        write_motd "nix-auto-update: LAST RUN FAILED — see $failure_log"
      }
      trap on_failure ERR

      : > "$log_file"
      exec > >(tee -a "$log_file") 2>&1

      echo "[auto-update] starting at $(date -Is) for host $HOST"

      if [ ! -d "$REPO/.git" ]; then
        echo "[auto-update] cloning $FLAKE_URL to $REPO"
        rm -rf "$REPO"
        git clone --branch "$BRANCH" "$FLAKE_URL" "$REPO"
      fi

      cd "$REPO"
      echo "[auto-update] fetching origin"
      git fetch --prune origin
      # Drop any local lockfile drift from previous runs before checkout.
      git reset --hard "origin/$BRANCH"

      cd "$REPO/$SUBDIR"
      echo "[auto-update] running nix flake update"
      nix flake update

      echo "[auto-update] building .#$HOST"
      nix build --no-link --print-out-paths ".#nixosConfigurations.$HOST.config.system.build.toplevel" > "$STATE/next-path.tmp"
      NEXT=$(cat "$STATE/next-path.tmp")
      rm -f "$STATE/next-path.tmp"

      echo "[auto-update] registering GC root: $STATE/next -> $NEXT"
      nix-store --add-root "$STATE/next" --indirect --realise "$NEXT" >/dev/null

      REV=$(git -C "$REPO" rev-parse HEAD)
      printf '%s\n' "$REV" > "$STATE/next-rev"
      date -Is > "$STATE/next-built-at"
      write_status "ok"

      current="/run/current-system"
      if [ -e "$current" ] && [ "$(readlink -f "$current")" != "$NEXT" ]; then
        {
          echo "nix-auto-update: new system prebuilt (rev $REV, built $(cat "$STATE/next-built-at"))"
          echo "  run 'nix-auto-update diff' to see changes, 'nix-auto-update switch' to activate"
          echo "  --- nvd diff (head) ---"
          nvd diff "$current" "$NEXT" 2>/dev/null | head -20 || true
        } > "$motd_file"
      else
        echo "nix-auto-update: prebuild matches current system (nothing new to switch to)" > "$motd_file"
      fi

      echo "[auto-update] done"
    '';
  };

  cli = pkgs.writeShellApplication {
    name = "nix-auto-update";
    runtimeInputs = with pkgs; [
      nvd
      systemd
      coreutils
    ];
    text = ''
      set -euo pipefail

      STATE="${stateDir}"
      REPO="${cfg.repoPath}"
      SUBDIR="${cfg.flakeSubdir}"
      HOST="${hostname}"

      cmd="''${1:-status}"

      case "$cmd" in
        status)
          if [ ! -e "$STATE/last-status" ]; then
            echo "nix-auto-update: never run"
            exit 0
          fi
          echo "last-status: $(cat "$STATE/last-status")"
          [ -f "$STATE/next-rev" ] && echo "next-rev:    $(cat "$STATE/next-rev")"
          [ -f "$STATE/next-built-at" ] && echo "built-at:    $(cat "$STATE/next-built-at")"
          if [ -L "$STATE/next" ]; then
            echo "next-path:   $(readlink -f "$STATE/next")"
          fi
          ;;
        diff)
          if [ ! -L "$STATE/next" ]; then
            echo "nix-auto-update: no prebuilt system available" >&2
            exit 1
          fi
          nvd diff /run/current-system "$STATE/next"
          ;;
        switch)
          if [ ! -L "$STATE/next" ]; then
            echo "nix-auto-update: no prebuilt system to switch to" >&2
            exit 1
          fi
          if [ "$(id -u)" -ne 0 ]; then
            echo "nix-auto-update switch: must run as root (use sudo)" >&2
            exit 1
          fi
          exec /run/current-system/sw/bin/nixos-rebuild switch --flake "$REPO/$SUBDIR#$HOST"
          ;;
        run-now)
          exec systemctl start nix-auto-update.service
          ;;
        discard)
          if [ "$(id -u)" -ne 0 ]; then
            echo "nix-auto-update discard: must run as root (use sudo)" >&2
            exit 1
          fi
          rm -f "$STATE/next" "$STATE/next-rev" "$STATE/next-built-at" "$STATE/motd"
          echo "discarded"
          ;;
        *)
          cat <<EOF
Usage: nix-auto-update <subcommand>

Subcommands:
  status   Print last run status, next-rev, and built-at
  diff     Show nvd diff between /run/current-system and the prebuilt system
  switch   Switch to the prebuilt system (requires root)
  run-now  Trigger the auto-update service immediately
  discard  Drop the prebuilt system GC root (requires root)
EOF
          [ "$cmd" = "help" ] || [ "$cmd" = "--help" ] || [ "$cmd" = "-h" ] || exit 1
          ;;
      esac
    '';
  };

in
{
  options.services.nixAutoUpdate = {
    enable = lib.mkEnableOption "weekly prebuild of the flake into /var/lib/nix-auto-update/next";

    flakeUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/onepunchtech/nix-configs.git";
      description = "Git URL to clone/fetch from. Public HTTPS assumed.";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "master";
      description = "Branch to track.";
    };

    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/nix-config";
      description = "Local clone path (system-owned).";
    };

    flakeSubdir = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "Subdirectory containing the flake, relative to repoPath.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "Sun 03:00";
      description = "systemd OnCalendar expression.";
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "2h";
      description = "Jitter added to the timer.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0755 root root -"
    ];

    systemd.services.nix-auto-update = {
      description = "Prebuild the latest nix-config flake for this host";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${runScript}/bin/nix-auto-update-run";
        Nice = 19;
        IOSchedulingClass = "idle";
        TimeoutStartSec = "6h";
        ProtectHome = true;
        PrivateTmp = true;
      };
      path = with pkgs; [
        git
        nix
        nvd
        coreutils
        systemd
      ];
    };

    systemd.timers.nix-auto-update = {
      description = "Weekly nix-auto-update prebuild";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        RandomizedDelaySec = cfg.randomizedDelaySec;
        Persistent = true;
      };
    };

    environment.systemPackages = [
      cli
      pkgs.nvd
    ];

    programs.bash.loginShellInit = ''
      if [ -f ${stateDir}/motd ]; then
        cat ${stateDir}/motd
      fi
    '';

    programs.zsh.loginShellInit = ''
      if [ -f ${stateDir}/motd ]; then
        cat ${stateDir}/motd
      fi
    '';
  };
}
