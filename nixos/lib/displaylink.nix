{ ... }:

{
  # The Elgato Prompter (USB 17e9:ff1a) is a DisplayLink device, not a plain
  # USB-C/HDMI monitor. Elgato does not support Linux and ships no Camera Hub
  # for it, but the panel underneath is an ordinary 9" 1024x600 display, so the
  # standard DisplayLink stack drives it as a normal second screen and anything
  # can be put on it (a browser, a scrolling-text app, a terminal).
  #
  # That stack is two halves and needs both:
  #   * evdi, an out-of-tree kernel module exposing a virtual DRM card;
  #   * DisplayLinkManager, Synaptics' proprietary userspace daemon that reads
  #     that card and pushes compressed frames over USB.
  # The in-tree udl/udlfb drivers do NOT cover this device -- they only handle
  # the DL-1xx generation, which is why the Prompter sits on the bus with no
  # driver bound until this module is enabled.
  #
  # Merges with the "amdgpu" entry in mises.nix; the NixOS module keys off the
  # presence of "displaylink" in this list rather than an enable flag.
  services.xserver.videoDrivers = [ "displaylink" ];

  # evdi creates DRM cards on demand and defaults to zero at boot. Force one to
  # exist up front so /dev/dri/evdi0 below is present before Hyprland starts:
  # AQ_DRM_DEVICES is read once at launch, so a card that appears later (when
  # the Prompter is plugged in) would never be picked up.
  boot.extraModprobeConfig = ''
    options evdi initial_device_count=1
  '';

  # Hyprland is pinned to an explicit device allowlist (see the AQ_DRM_DEVICES
  # comment in home-manager/modules/linux/hyprland/hyprland.nix), which means
  # any card not named there is invisible to the compositor. Give the evdi card
  # a stable, colon-free name to add to that list -- card numbering is not
  # stable across boots, and AQ_DRM_DEVICES splits its value on ':', so
  # /dev/dri/by-path/ names cannot be used.
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="card[0-9]*", KERNELS=="evdi.0", SYMLINK+="dri/evdi0"
  '';
}
