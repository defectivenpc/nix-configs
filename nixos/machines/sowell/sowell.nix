{ pkgs, ... }:
{
  imports = [
    ../../lib/base.nix
    ../../lib/gui.nix
    ../../lib/nvidiagpu.nix
    ../../lib/laptop.nix
    ../../lib/driver.nix
    ../../lib/virtualization.nix
    ../../lib/users.nix
  ];
  networking.hostName = "sowell";
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_drm"
    "nvidia_uvm"
    "nvidia_modeset"
    "snd_pci_acp6x"
    "kvm-amd"
  ];

  hardware.enableAllFirmware = true;
  hardware.firmware = [
    pkgs.linux-firmware
  ];
  swapDevices = [
    {
      device = "/swapfile";
      size = 32 * 1024;
    }
  ];
  services.power-profiles-daemon.enable = false;
  virtualisation.libvirtd.enable = true;
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  networking.nat.enable = true;
  programs.virt-manager.enable = true;

  users.groups.libvirtd.members = [ "whitehead" ];

  virtualisation.spiceUSBRedirection.enable = true;
}
