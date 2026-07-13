{ pkgs, ... }:

let
  yubikey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAlxuKI8DZvdMA7dHTXG9NATaw9D2RGMQqQKwef4m2oeHFI/r+cPHICtC0SYYk6woPSjjZR7PtiP2VSn0eoX3yk= YubiKey #26922176 PIV Slot 9a (touch: cached)";
in
{
  # Preseed environment for running nixos-anywhere against the target from
  # your operator machine. This image comes up on the target, exposes ssh,
  # and stands still — you drive the install from elsewhere.

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
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ yubikey ];
  };

  users.users.root = {
    initialHashedPassword = "";
    openssh.authorizedKeys.keys = [ yubikey ];
  };

  environment.systemPackages = with pkgs; [
    nix
    nixos-facter
    git
    disko
    curl
    tmux
    vim
    parted
    gptfdisk
    e2fsprogs
    dosfstools
    smartmontools
  ];
}
