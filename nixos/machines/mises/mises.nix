{ pkgs, config, ... }:
{
  imports = [
    ../../lib/base.nix
    ../../lib/gui.nix
    ../../lib/amdgpu.nix
    #./lib/users.nix
    ../../lib/shell.nix
    #./lib/sops.nix
    ../../lib/printer.nix
    ../../lib/networking.nix
    ../../lib/virtualization.nix
  ];

  networking.hostName = "mises";
  services.desktopManager.cosmic.enable = true;
  #services.displayManager.cosmic-greeter.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [
      pkgs.rocmPackages.clr.icd
    ];
  };

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

  # sops.defaultSopsFile = ./host-secrets/mises-secrets.yaml;
  # sops.secrets.whitehead-password = { };
  # sops.secrets.whitehead-password.neededForUsers = true;
  #
  security.polkit.enable = true;

  users.users.whitehead = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "docker"
      "libvirtd"
      "kvm"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCrOpJm3+B7/pyGi+pzn2HbatpFY7tCDpwBcr8orQOd9B0GXTIuTKeV2lGS9Zb1TUqngo9uR2JXv0o51IZOao0zjGgug2udFvB0mQNALCrEosHVzTGopkeuiF9ZKlaHO5vbzi9zfDWs9/1A1YTa7JFt8Qrgi4EqycOli540jlvvxkEDN3PDz/36YaXCqzqj3e5tX6Nmh8xCEq70+oyA9oZ/gTMLFjLLlSigZPn0Ex3KjRpiap3LkPZGt7LPZEFWXrMMKLhzOhM7yuMewHSiYMp4s6gJursUK3etcxSHn+HeXcMdtte9XRi91PwIhnHR/oqUpP+wNpwm26qRmVeOmn2J YubiKey #26922176 PIV Slot 9a"
    ];
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCrOpJm3+B7/pyGi+pzn2HbatpFY7tCDpwBcr8orQOd9B0GXTIuTKeV2lGS9Zb1TUqngo9uR2JXv0o51IZOao0zjGgug2udFvB0mQNALCrEosHVzTGopkeuiF9ZKlaHO5vbzi9zfDWs9/1A1YTa7JFt8Qrgi4EqycOli540jlvvxkEDN3PDz/36YaXCqzqj3e5tX6Nmh8xCEq70+oyA9oZ/gTMLFjLLlSigZPn0Ex3KjRpiap3LkPZGt7LPZEFWXrMMKLhzOhM7yuMewHSiYMp4s6gJursUK3etcxSHn+HeXcMdtte9XRi91PwIhnHR/oqUpP+wNpwm26qRmVeOmn2J YubiKey #26922176 PIV Slot 9a"
    ];
  };
  security.pam.services.kwallet = {
    name = "kwallet";
    enableKwallet = true;
  };

}
