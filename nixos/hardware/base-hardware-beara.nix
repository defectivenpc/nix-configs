{ pkgs, modulesPath, ... }:
{
  imports = [ ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "amdgpu" ];
  boot.extraModulePackages = [ ];
  hardware.enableAllFirmware = true;
  hardware.firmware = [
    pkgs.linux-firmware
  ];
}
