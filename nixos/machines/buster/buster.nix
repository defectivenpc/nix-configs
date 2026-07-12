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

  networking.hostName = "buster";

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [
    ];
  };

  boot.kernelPackages = pkgs.unstable.linuxPackages_latest;
  services.xserver.videoDrivers = [ "amdgpu" ];
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
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAlxuKI8DZvdMA7dHTXG9NATaw9D2RGMQqQKwef4m2oeHFI/r+cPHICtC0SYYk6woPSjjZR7PtiP2VSn0eoX3yk= YubiKey #26922176 PIV Slot 9a (touch: cached)"
    ];
  };

  users.users.stephen = {
    isNormalUser = true;
    extraGroups = [
      "video"
    ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAlxuKI8DZvdMA7dHTXG9NATaw9D2RGMQqQKwef4m2oeHFI/r+cPHICtC0SYYk6woPSjjZR7PtiP2VSn0eoX3yk= YubiKey #26922176 PIV Slot 9a (touch: cached)"
    ];
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAlxuKI8DZvdMA7dHTXG9NATaw9D2RGMQqQKwef4m2oeHFI/r+cPHICtC0SYYk6woPSjjZR7PtiP2VSn0eoX3yk= YubiKey #26922176 PIV Slot 9a (touch: cached)"
    ];
  };
  security.pam.services.kwallet = {
    name = "kwallet";
    enableKwallet = true;
  };

}
