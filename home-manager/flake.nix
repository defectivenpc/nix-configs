{
  description = "Home Manager configuration of whitehead";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay.url = "github:nix-community/emacs-overlay";

  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      cosmic-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = (import nixpkgs) {
        inherit system;
      };
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      homeConfigurations."whitehead" = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgs;

        extraSpecialArgs = {
          inherit pkgs-unstable;
        };
        modules = [
          ./home.nix
          cosmic-manager.homeManagerModules.cosmic-manager
        ];

        extraSpecialArgs = { inherit nixpkgs-unstable; };
      };

      homeConfigurations."whitehead-darwin" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { system = "aarch64-darwin"; };

        modules = [
          ./home-darwin.nix
        ];

        extraSpecialArgs = { inherit pkgs-unstable; };
      };
    };
}
