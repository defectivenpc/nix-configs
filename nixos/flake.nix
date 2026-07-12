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

      hmModule = {
        home-manager.users.whitehead = import ../home-manager;
        home-manager.extraSpecialArgs = {
          inherit pkgs-unstable;
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
        }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules =
            [
              (standardOverlays { inherit extraOverlays; })
              ./machines/${hostname}/${hostname}.nix
            ]
            ++ lib.optionals includeSops [ sops-nix.nixosModules.sops ]
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
              hmModule
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
        authority = mkHost { hostname = "authority"; };
        nas1 = mkHost { hostname = "nas1"; };
        nas2 = mkHost { hostname = "nas2"; };
        sowell = mkHost { hostname = "sowell"; };
        router = mkHost { hostname = "router"; };

        # Legacy hosts (bare — no facter/disko/sops/HM yet).
        bob = mkBareHost { hostname = "bob"; };
        tom = mkBareHost { hostname = "tom"; };
        bigtux = mkBareHost { hostname = "bigtux"; };
      };

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
