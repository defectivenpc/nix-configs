{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware/bigtux.nix
    ./lib/base.nix
  ];

  environment.systemPackages = with pkgs; [
    tmux
    zellij
  ];

  services = {
    jellyfin = {
      enable = true;
      openFirewall = true;
    };
  };

  nix = {
    settings = {
      max-jobs = lib.mkDefault 4;
      trusted-users = [
        "root"
        "@wheel"
      ];
    };

  };

  networking = {
    firewall.enable = true;
    firewall.allowedTCPPorts = [
      80
      53
      443
    ];
    firewall.allowedUDPPorts = [
      53
      51000
    ];
    hostName = "bigtux";
    networkmanager.enable = true;
    interfaces.enp7s0.useDHCP = true;
  };

  fileSystems."/mnt/nas1/share" = {
    device = "10.10.106.50:/srv/share";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nfsvers=4.2"
    ];
  };

  fileSystems."/mnt/nas1/repositories" = {
    device = "10.10.106.50:/srv/repositories";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nfsvers=4.2"
    ];
  };

  fileSystems."/mnt/nas1/media" = {
    device = "10.10.106.50:/srv/media";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nfsvers=4.2"
    ];
  };

  boot.supportedFilesystems = [ "nfs" ];

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

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAlxuKI8DZvdMA7dHTXG9NATaw9D2RGMQqQKwef4m2oeHFI/r+cPHICtC0SYYk6woPSjjZR7PtiP2VSn0eoX3yk= YubiKey #26922176 PIV Slot 9a (touch: cached)"
    ];
  };
}
