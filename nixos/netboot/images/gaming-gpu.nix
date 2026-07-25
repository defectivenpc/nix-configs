# One image, both GPU vendors.
#
# The machines this boots are split between AMD (mises, buster) and Nvidia
# (beara, sowell, bob), and the whole point is "boot the gaming OS on whichever
# hardware" without picking a menu entry per machine. So both stacks ship in
# the same squashfs — roughly 1.5-2 GB extra on the wire — and the vendor is
# resolved at boot.
#
# What is and is not conditional:
#
#   * Kernel modules: udev autoloads by PCI modalias, so amdgpu binds on AMD
#     and nvidia binds on Nvidia with no help from us. The nvidia module also
#     force-loads via boot.kernelModules; on an AMD box that module loads,
#     probes no devices, and sits there costing ~30 MB. Harmless, and cheaper
#     than fighting the upstream module.
#   * Userspace GL/GBM vendor selection is NOT safe to set statically —
#     GBM_BACKEND=nvidia-drm on an AMD box breaks the compositor outright.
#     Hence the detect service below, consumed by the session wrapper in
#     gaming.nix.
#
# If this coexistence ever turns flaky in practice, the escape is cheap:
# mkHttpStoreImage is parameterised by name, so splitting into gaming-amd and
# gaming-nvidia costs one flake entry and one extra menu line.

{ config, pkgs, ... }:

{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    # Pulls in a GTK stack we would otherwise be shipping over the network
    # for a settings panel nobody opens on a Big Picture box.
    nvidiaSettings = false;
  };

  # amdgpu first so X's autoconfiguration prefers it where both are viable;
  # "nvidia" must be present or hardware.nvidia does nothing at all.
  services.xserver.videoDrivers = [
    "amdgpu"
    "modesetting"
    "nvidia"
  ];

  boot.initrd.kernelModules = [ "amdgpu" ];

  # Writes the vendor of the GPU actually present, for the session wrapper.
  systemd.services.gpu-vendor-detect = {
    description = "Detect the installed GPU vendor";
    wantedBy = [ "multi-user.target" ];
    before = [ "greetd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      vendor=other
      # 0x03 = display controller class; 10de = Nvidia, 1002 = AMD.
      if ${pkgs.pciutils}/bin/lspci -mn | grep -q '"03[0-9a-f][0-9a-f]" "10de"'; then
        vendor=nvidia
      elif ${pkgs.pciutils}/bin/lspci -mn | grep -q '"03[0-9a-f][0-9a-f]" "1002"'; then
        vendor=amd
      fi
      echo "$vendor" > /run/gpu-vendor
      echo "detected GPU vendor: $vendor"
    '';
  };
}
