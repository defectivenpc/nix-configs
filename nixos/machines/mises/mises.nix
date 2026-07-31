{ pkgs, config, ... }:
{
  imports = [
    ../../lib/base.nix
    ../../lib/gui.nix
    ../../lib/amdgpu.nix
    ../../lib/shell.nix
    ../../lib/printer.nix
    ../../lib/networking.nix
    ../../lib/virtualization.nix
    ../../lib/vial.nix
  ];

  networking.hostName = "mises";
  services.desktopManager.cosmic.enable = true;
  #services.displayManager.cosmic-greeter.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # RDNA4 (RX 9070 XT / gfx1201) needs ROCm 6.5+; stable nixpkgs pins 6.4.3
    # which enumerates the card but fails at OpenCL context creation. Pull
    # rocm-clr from unstable to get a version that actually works.
    extraPackages = [
      pkgs.unstable.rocmPackages.clr.icd
    ];
    extraPackages32 = [
      pkgs.unstable.rocmPackages.clr.icd
    ];
  };

  # Kernel 6.12 has partial RDNA4 support; 6.14+ has the full stack. Pull the
  # latest kernel from unstable for the same reason as ROCm above.
  boot.kernelPackages = pkgs.unstable.linuxPackages_latest;

  security.pki.certificateFiles = [
    ../../certs/praxiotic-prod-ca.crt
    ../../certs/praxiotic-local-ca.crt
  ];

  nixpkgs.config.allowUnfree = true;

  systemd.tmpfiles.rules = [
    "d /mnt/extra1 0777 whitehead users"
  ];

  fileSystems."/mnt/share" = {
    device = "10.10.106.50:/mnt/share";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nfsvers=4.2"
    ];
  };

  fileSystems."/mnt/media" = {
    device = "10.10.106.50:/mnt/media";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nfsvers=4.2"
    ];
  };

  fileSystems."/mnt/ops-backups" = {
    device = "10.10.106.50:/mnt/ops-backups";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nfsvers=4.2"
    ];
  };

  fileSystems."/mnt/project-backups" = {
    device = "10.10.106.50:/mnt/project-backups";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nfsvers=4.2"
    ];
  };

  # optional, but ensures rpc-statsd is running for on demand mounting
  boot.supportedFilesystems = [ "nfs" ];

  services.xserver.videoDrivers = [ "amdgpu" ];

  services.resolved.enable = true;

  boot.kernelParams = [
    "video=DP-1:2560x1440@120"
    "video=HDMI-A-1:2560x1440@120"
    "kvm_amd"
  ];

  security.polkit.enable = true;

  services.netbird = {
    enable = true;
    package = pkgs.netbird-pinned;
  };

}
