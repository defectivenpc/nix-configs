{
  description = "Local overrides for this work mac";

  inputs.base.url = "github:onepunchtech/nix-configs?dir=nix-darwin";

  outputs =
    { base, ... }:
    {
      darwinConfigurations.work = base.lib.mkMac {
        primaryUser = "mwhitehead";
        users = [
          "mwhitehead"
          "admin-mwhitehead"
        ];
        extraModules = [ ./local.nix ];
      };
    };
}
