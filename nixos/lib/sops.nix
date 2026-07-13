{ config, ... }:
{
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = false;

  # Shared user password hashes live in nixos/secrets/users.yaml and are
  # encrypted to every host as a recipient. Per-host extras live in their
  # own file (e.g. nixos/secrets/authority.yaml) and are wired up in that
  # machine's module.
  sops.defaultSopsFile = ../secrets/users.yaml;

  sops.secrets.whitehead-password = {
    neededForUsers = true;
  };
}
