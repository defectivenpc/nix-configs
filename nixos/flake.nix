{
  description = "My NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-netbird.url = "github:NixOS/nixpkgs/ce4782aae889ce0f1ab3cfcfe6193ec294580d84";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      nixpkgs-netbird,
      nixos-generators,
      nixos-facter-modules,
      disko,
      sops-nix,
      home-manager,
      deploy-rs,
      ...
    }@inputs:

    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = nixpkgs.legacyPackages.${system};

      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      standardOverlays =
        { extraOverlays ? [ ] }:
        {
          nixpkgs.overlays = [
            (final: prev: {
              unstable = import nixpkgs-unstable {
                inherit system;
                config.allowUnfree = true;
              };
            })
          ] ++ extraOverlays;
          nix.settings = {
            substituters = [ "https://cosmic.cachix.org/" ];
            trusted-public-keys = [ "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE=" ];
          };
        };

      hmModuleFor =
        { isHeadless ? false }:
        {
          home-manager.users.whitehead = import ../home-manager;
          home-manager.extraSpecialArgs = {
            inherit pkgs-unstable isHeadless;
            isDarwin = false;
          };
        };

      mkHost =
        {
          hostname,
          extraModules ? [ ],
          extraOverlays ? [ ],
          includeHM ? true,
          includeFacter ? true,
          includeDisko ? true,
          includeSops ? true,
          isHeadless ? false,
        }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules =
            [
              (standardOverlays { inherit extraOverlays; })
              ./machines/${hostname}/${hostname}.nix
            ]
            ++ lib.optionals includeSops [
              sops-nix.nixosModules.sops
              ./lib/users.nix
            ]
            ++ lib.optionals includeFacter [
              nixos-facter-modules.nixosModules.facter
              { config.facter.reportPath = ./hardware/facter/${hostname}.json; }
            ]
            ++ lib.optionals includeDisko [
              disko.nixosModules.disko
              ./machines/${hostname}/disko.nix
            ]
            ++ lib.optionals includeHM [
              home-manager.nixosModules.home-manager
              (hmModuleFor { inherit isHeadless; })
            ]
            ++ extraModules;
        };

      # Legacy bare-metal hosts: no overlays/sops/facter/disko/HM.
      mkBareHost =
        { hostname, extraModules ? [ ] }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./machines/${hostname}/${hostname}.nix ] ++ extraModules;
        };

    in
    {

      nixosConfigurations = {
        mises = mkHost {
          hostname = "mises";
          extraOverlays = [
            (final: prev: {
              netbird-pinned =
                (import nixpkgs-netbird {
                  inherit system;
                  config.allowUnfree = true;
                }).netbird;
            })
          ];
        };
        beara = mkHost { hostname = "beara"; };
        buster = mkHost { hostname = "buster"; };
        authority = mkHost { hostname = "authority"; isHeadless = true; };
        nas1 = mkHost { hostname = "nas1"; isHeadless = true; };
        nas2 = mkHost { hostname = "nas2"; isHeadless = true; };
        sowell = mkHost { hostname = "sowell"; };
        router = mkHost { hostname = "router"; isHeadless = true; };

        # Legacy hosts (bare — no facter/disko/sops/HM yet).
        bob = mkBareHost { hostname = "bob"; };
        tom = mkBareHost { hostname = "tom"; };
        bigtux = mkBareHost { hostname = "bigtux"; };
      };

      deploy = {
        # Global defaults — override per-node as needed.
        sshUser = "root";
        user = "root";
        # Keep an activation timeout that's generous for slow hosts, and
        # let deploy-rs auto-rollback if the new profile fails to come up.
        autoRollback = true;
        magicRollback = true;
        # Confirmation timeout (seconds) after activation; if the operator
        # loses connectivity before confirming, deploy-rs reverts.
        confirmTimeout = 180;

        nodes = {
          router = {
            hostname = "router.onepunch";
            profiles.system.path =
              deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.router;
          };

          nas1 = {
            hostname = "nas1.onepunchtech.io";
            profiles.system.path =
              deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.nas1;
          };
        };
      };

      # Validate every deploy node at `nix flake check` time.
      checks = builtins.mapAttrs (_: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      packages.x86_64-linux = rec {
        installIso = nixos-generators.nixosGenerate {
          system = system;
          modules = [
            ./installIso.nix
          ];
          format = "iso";
        };

        installTest = pkgs.writeScriptBin "installTest" ''
          nix run github:nix-community/nixos-anywhere -- --flake .#router -- --generate-hardware-config nixos-facter ./hardware/facter/router.json --target-host root@192.168.122.130
        '';

        runVM = pkgs.writeScriptBin "runVM" ''
          ${pkgs.qemu}/bin/qemu-system-x86_64 \
            -enable-kvm \
            -m 2048 \
            -nic user,model=virtio \
            -cdrom ${installIso}/iso/*.iso
        '';
      };
    };
}
