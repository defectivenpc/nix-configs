# Saves follow you between machines; bulk game files do not.
#
# Split:
#   nas1 (NFS)  userdata/, config/, compatdata/  — small, must roam
#   GAMES (SSD) steamapps/                       — huge, re-downloadable
#
# compatdata (Proton prefixes) is arguably save data, but it is also thousands
# of small files that a game rewrites constantly. It goes on NFS because a save
# inside a prefix is otherwise stranded on one machine; if this turns out to be
# too slow in practice, move just that one line back to the local disk.
#
# The NAS is never allowed to block boot: the mount is a nofail automount, and
# the wiring below degrades to local directories when nas1 is unreachable.

{ pkgs, ... }:

let
  nas = "10.10.106.50";
  steamRoot = "/home/player/.local/share/Steam";
in
{
  # Pulls in rpc-statd, which on-demand NFS mounting needs.
  boot.supportedFilesystems = [ "nfs" ];

  fileSystems."/mnt/saves" = {
    device = "${nas}:/mnt/gaming";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nofail"
      "_netdev"
      "nfsvers=4.2"
      "x-systemd.idle-timeout=600"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=10s"
      # soft + bounded retries: a NAS reboot mid-game gives Steam an EIO it can
      # report, rather than a D-state hang that takes the compositor with it.
      "soft"
      "timeo=50"
      "retrans=2"
    ];
  };

  systemd.services.gaming-home-setup = {
    description = "Point Steam at NFS saves (or local fallback)";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [
      "var-lib-games.mount"
      "home-player.mount"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Everything under /mnt/saves is written as uid 1000, matching the
      # anonuid on nas1's export. Nothing here ever writes as root.
      User = "player";
      Group = "users";
    };
    path = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    script = ''
      set -u

      mkdir -p ${steamRoot}/steamapps

      # Bulk library on the local disk when it exists.
      if mountpoint -q /var/lib/games; then
        rm -rf ${steamRoot}/steamapps/common
        ln -sfn /var/lib/games/steamlib ${steamRoot}/steamapps/common
      fi

      # Touching the path triggers the automount; timeout bounds a dead NAS.
      nasUp=0
      if timeout 15 ls /mnt/saves >/dev/null 2>&1; then
        nasUp=1
      else
        echo "nas1 unreachable — saves will stay LOCAL to this machine and will not roam" >&2
      fi

      link_or_local() {
        src="/mnt/saves/$1"
        dest="$2"
        if [ "$nasUp" = 1 ]; then
          mkdir -p "$src"
          # Only replace a plain directory if it is empty, so a previous
          # offline session's saves are never silently thrown away.
          if [ -d "$dest" ] && [ ! -L "$dest" ]; then
            rmdir "$dest" 2>/dev/null || {
              echo "$dest has local contents; leaving it alone (not syncing to nas1)" >&2
              return 0
            }
          fi
          ln -sfn "$src" "$dest"
        else
          [ -L "$dest" ] && rm -f "$dest"
          mkdir -p "$dest"
        fi
      }

      link_or_local userdata   ${steamRoot}/userdata
      link_or_local config     ${steamRoot}/config
      link_or_local compatdata ${steamRoot}/steamapps/compatdata
    '';
  };

  # If the NAS was down at boot, this is the one command to run afterwards.
  environment.shellAliases.resync-saves = "sudo systemctl restart gaming-home-setup";
}
