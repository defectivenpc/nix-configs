{ config, ... }:
let
  yubikey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAlxuKI8DZvdMA7dHTXG9NATaw9D2RGMQqQKwef4m2oeHFI/r+cPHICtC0SYYk6woPSjjZR7PtiP2VSn0eoX3yk= YubiKey #26922176 PIV Slot 9a (touch: cached)";
in
{
  imports = [ ./sops.nix ];

  sops.secrets.family-password = {
    neededForUsers = true;
  };

  users.users.family = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "video"
    ];
    openssh.authorizedKeys.keys = [ yubikey ];
    hashedPasswordFile = config.sops.secrets.family-password.path;
  };
}
