# Local disk policy for the gaming image: adopt by label, never by guesswork.
#
# A disk with neither label is left completely alone — that is the whole point
# of keeping these machines' SSDs "dumb". Both mounts are nofail, so a machine
# with no local storage at all still boots (see http-store.nix's RAM mode).

{ ... }:

{
  # Steam library + persistent home. Provisioned by provision-gaming-disk.
  fileSystems."/var/lib/games" = {
    device = "/dev/disk/by-label/GAMES";
    fsType = "ext4";
    options = [
      "nofail"
      "noatime"
      "x-systemd.device-timeout=10s"
      "x-systemd.mount-timeout=15s"
    ];
  };

  # When netbooted, the initrd already mounted this to fetch the store;
  # re-declaring it makes the cache visible and prunable at runtime, and
  # mounting the same ext4 device at a second mountpoint is fine — it is one
  # superblock either way. When booted from USB nothing has touched it, and
  # this is simply how you inspect or clear a machine's netboot cache.
  fileSystems."/var/cache/netboot-store" = {
    device = "/dev/disk/by-label/GAMECACHE";
    fsType = "ext4";
    options = [
      "nofail"
      "noatime"
      "x-systemd.device-timeout=10s"
    ];
  };

  # When GAMES is absent these land on the tmpfs root instead, which is why
  # the image still works on an unprovisioned machine — you just cannot keep
  # a game library across reboots.
  systemd.tmpfiles.rules = [
    "d /var/lib/games          0755 player users -"
    "d /var/lib/games/home     0700 player users -"
    "d /var/lib/games/steamlib 0755 player users -"
  ];

  # Persistent home on GAMES: shader caches, in-flight downloads, and anything
  # Steam writes that is too big or too chatty to put on NFS.
  fileSystems."/home/player" = {
    device = "/var/lib/games/home";
    fsType = "none";
    options = [
      "bind"
      "nofail"
      "x-systemd.requires-mounts-for=/var/lib/games"
    ];
  };
}
