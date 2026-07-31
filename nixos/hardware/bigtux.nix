{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "vfio-pci"
  ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [
    "kvm-intel"
    "vfio_virqfd"
    "vfio_pci"
    "vfio_iommu_type1"
    "vfio"
  ];
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "video=vesafb:off,efifb:off"
    "nofb"
  ];
  boot.blacklistedKernelModules = [
    "nvidia"
    "nouveau"
  ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/684a18c7-b973-4b63-aed6-d07dcde223ec";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0468-8CA9";
    fsType = "vfat";
  };

  fileSystems."/mnt/media" = {
    device = "/dev/disk/by-label/storage1";
    fsType = "btrfs";
  };

  fileSystems."/mnt/backups" = {
    device = "10.10.10.8:/mnt/md0/backups";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=600"
    ];
  };

  swapDevices = [ ];

  # High-DPI console
  console.font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
}
