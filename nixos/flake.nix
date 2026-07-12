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
      pkgs = nixpkgs.legacyPackages.${system};

      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

    in
    {

      nixosConfigurations = {

        mises = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          modules = [
            {
              nixpkgs.overlays = [
                (final: prev: {
                  unstable = import nixpkgs-unstable {
                    inherit system;
                    config.allowUnfree = true;
                  };
                  netbird-pinned = (import nixpkgs-netbird {
                    inherit system;
                    config.allowUnfree = true;
                  }).netbird;
                })
              ];
              nix.settings = {
                substituters = [ "https://cosmic.cachix.org/" ];
                trusted-public-keys = [ "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE=" ];
              };
            }
            sops-nix.nixosModules.sops
            nixos-facter-modules.nixosModules.facter
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            { config.facter.reportPath = ./hardware/facter/mises.json; }
            {
              home-manager.users.whitehead = import ../home-manager/home.nix;
              home-manager.extraSpecialArgs = {
                inherit pkgs-unstable;
              };
            }
            ./machines/mises/disko.nix
            ./machines/mises/mises.nix
          ];
        };

        beara = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          modules = [
            {
              nixpkgs.overlays = [
                (final: prev: {
                  unstable = import nixpkgs-unstable {
                    inherit system;
                    config.allowUnfree = true;
                  };
                })
              ];
              nix.settings = {
                substituters = [ "https://cosmic.cachix.org/" ];
                trusted-public-keys = [ "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE=" ];
              };
            }
            sops-nix.nixosModules.sops
            nixos-facter-modules.nixosModules.facter
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            { config.facter.reportPath = ./hardware/facter/beara.json; }
            {
              home-manager.users.whitehead = import ../home-manager/home.nix;
              home-manager.extraSpecialArgs = {
                inherit pkgs-unstable;
              };
            }
            ./machines/beara/disko.nix
            ./machines/beara/beara.nix
          ];
        };

        bob = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./bob.nix
          ];
        };
        tom = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./tom.nix
          ];
        };
        sowell = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            sops-nix.nixosModules.sops
            nixos-facter-modules.nixosModules.facter
            disko.nixosModules.disko
            {
              _module.args.disks = [ "/dev/nvme0n1" ];
            }
            {
              config.facter.reportPath = ./hardware/facter/sowell.json;
            }
            ./disko/basic.nix
            ./sowell.nix
          ];
        };
        router = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            sops-nix.nixosModules.sops
            nixos-facter-modules.nixosModules.facter
            disko.nixosModules.disko
            { config.facter.reportPath = ./hardware/facter/router.json; }
            {
              _module.args.disks = [ "/dev/nvme0n1" ];
            }
            ./disko/basic.nix
            ./machines/router.nix
          ];
        };

        bigtux = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./bigtux.nix
          ];
        };

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
          # create tmp directory
          # decrypt secrets to directory
          # write ssh keys from secrets to directory
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
