{ pkgs, ... }:

let
  yubikey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAlxuKI8DZvdMA7dHTXG9NATaw9D2RGMQqQKwef4m2oeHFI/r+cPHICtC0SYYk6woPSjjZR7PtiP2VSn0eoX3yk= YubiKey #26922176 PIV Slot 9a (touch: cached)";
in
{
  # Ephemeral rescue shell. Boots into a full NixOS console with ssh + the
  # tools you'd reach for when a machine is misbehaving. No password on the
  # console; ssh is key-only.

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.whitehead = {
    isNormalUser = true;
    initialHashedPassword = "";
    extraGroups = [ "wheel" "networkmanager" "video" ];
    openssh.authorizedKeys.keys = [ yubikey ];
  };

  users.users.root = {
    initialHashedPassword = "";
    openssh.authorizedKeys.keys = [ yubikey ];
  };

  environment.systemPackages = with pkgs; [
    tmux
    vim
    htop
    iproute2
    iputils
    dnsutils
    curl
    wget
    rsync
    smartmontools
    lsof
    strace
    tcpdump
    file
    pciutils
    usbutils
    nvme-cli
    ethtool
    parted
    gptfdisk
    e2fsprogs
    dosfstools
    btrfs-progs
    zfs
  ];
}
