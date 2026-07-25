# The same gaming OS, delivered on a USB stick instead of over the network.
#
# For machines whose firmware cannot PXE at all. Everything above the boot
# medium is identical — it imports gaming.nix, so the session, GPU handling,
# GAMES adoption and nas1 saves are literally the same modules the netbooted
# image uses. Only the root delivery differs:
#
#   netboot : small initrd -> HTTP fetch -> cache on GAMECACHE   (../http-store.nix)
#   USB     : squashfs sits on the medium itself                 (upstream iso-image.nix)
#
# Both end at the same place: a read-only squashfs with a tmpfs overlay on
# /nix/store and a tmpfs /. Nothing is written to the stick at runtime, so it
# stays a plain `dd` target you can re-flash at any time.
#
# This composes iso-image.nix directly rather than installation-cd-base.nix,
# for two reasons:
#
#   * installation-cd-base pulls in profiles/installation-device.nix, which
#     creates a `nixos` autologin user and installer tooling that fight the
#     `player`/greetd setup in gaming.nix.
#   * it also sets `fileSystems = mkImageMediaOverride config.lib.isoFileSystems`,
#     a whole-attrset override at priority 60 whose job is to erase a host's
#     hardware-config mounts. That would take the GAMES and NFS saves mounts
#     with it. iso-image.nix on its own sets `fileSystems` at normal priority
#     with per-entry overrides, which merges with ours correctly.

{ lib, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
    "${modulesPath}/profiles/base.nix"
    ./gaming.nix
  ];

  # Broad driver coverage: the whole point is booting unknown hardware. The
  # netboot path gets this from ../http-store.nix, which is not in play here.
  hardware.enableAllHardware = lib.mkDefault true;

  isoImage = {
    makeEfiBootable = true;
    makeUsbBootable = true;
    # Stage 1 finds the medium by this label, so it needs to be distinctive
    # and stable — a machine with the netboot GAMECACHE/GAMES partitions
    # attached must not confuse them for the boot medium.
    volumeID = "GAMEBOOT";
    # Match the netboot image's tradeoff: level 19 costs a lot of build time
    # for a few percent, and this gets rebuilt as often as the netboot one.
    squashfsCompression = "zstd -Xcompression-level 15";
    appendToMenuLabel = " Gaming";
  };

  image.baseName = lib.mkForce "gaming-usb";

  # Handy to have on the same stick, given it is the recovery option for a
  # machine that could not netboot in the first place.
  boot.loader.grub.memtest86.enable = true;
}
