{
  description = "My NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
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
            { config.facter.reportPath = ../../hardware/facter/mises.json; }
            {
              home-manager.users.whitehead = import ../../../home-manager/home.nix;
              home-manager.extraSpecialArgs = {
                inherit pkgs-unstable;
              };
            }
            ./disko.nix
            ./mises.nix
          ];
        };
      };
      packages.x86_64-linux = rec {

      };
    };
}
