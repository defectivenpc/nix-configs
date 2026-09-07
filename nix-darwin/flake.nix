{
  description = "Darwin system flake shared across whitehead's macs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
    }:
    let
      inherit (nixpkgs) lib;

      system = "aarch64-darwin";
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      mkMac =
        {
          primaryUser,
          users,
          withClaudeCode ? false,
          extraModules ? [ ],
        }:
        nix-darwin.lib.darwinSystem {
          modules = [
            ../modules/darwin/base.nix
            home-manager.darwinModules.home-manager
            {
              nixpkgs.hostPlatform = system;
              system.configurationRevision = self.rev or self.dirtyRev or null;

              system.primaryUser = primaryUser;

              users.users = lib.genAttrs users (user: {
                name = user;
                home = "/Users/${user}";
              });

              home-manager.backupFileExtension = "hm-bak";
              home-manager.extraSpecialArgs = {
                inherit pkgs-unstable withClaudeCode;
                isDarwin = true;
                isHeadless = false;
              };
              home-manager.users = lib.genAttrs users (user: {
                imports = [ ../home-manager ];
                _module.args.username = user;
              });
            }
          ]
          ++ extraModules;
        };
    in
    {
      lib.mkMac = mkMac;

      darwinModules = {
        base = ../modules/darwin/base.nix;
        input = ../modules/darwin/input.nix;
        tiling = ../modules/darwin/tiling.nix;
      };

      templates.work = {
        path = ./templates/work;
        description = "Private per-laptop overlay flake for a work mac";
      };

      darwinConfigurations."personal-mac" = mkMac {
        primaryUser = "whitehead";
        users = [ "whitehead" ];
        withClaudeCode = true;
        extraModules = [ ../modules/darwin/tiling.nix ];
      };
    };
}
