{
  description = "Darwin system flake for whitehead's mac";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
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
      system = "aarch64-darwin";
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      configuration =
        { pkgs, ... }:
        {
          imports = [
            ../modules/base.nix
          ];
          environment.systemPackages = with pkgs; [
            neovim
            home-manager
            ghostty-bin
          ];

          nix.settings.experimental-features = "nix-command flakes";

          system.configurationRevision = self.rev or self.dirtyRev or null;
          system.stateVersion = 6;

          nixpkgs.hostPlatform = system;

          system.primaryUser = "whitehead";
          system.defaults.dock = {
            static-only = true;
            autohide = true;
          };

          services.yabai = {
            enable = true;

            config = {
              focus_follows_mouse = "autoraise";
              mouse_follows_focus = "off";
              window_placement = "second_child";
              window_opacity = "off";
              top_padding = 0;
              bottom_padding = 5;
              left_padding = 5;
              right_padding = 5;
              window_gap = 5;
              layout = "bsp";
            };
          };

          services.skhd = {
            enable = true;
            skhdConfig = ''
              alt - h : yabai -m window --focus west
              alt - l : yabai -m window --focus east
              alt - k : yabai -m window --focus north
              alt - j : yabai -m window --focus south
              shift + alt - h : yabai -m window --swap west
              shift + alt - l : yabai -m window --swap east
              shift + alt - k : yabai -m window --swap north
              shift + alt - j : yabai -m window --swap south
              alt - b : open -a "Brave Browser"
              alt - c : $(yabai -m window $(yabai -m query --windows --window | jq -re ".id") --close)
              alt - return : open -n /Applications/Nix\ Apps/Ghostty.app
            '';
          };

        };
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#simple
      darwinConfigurations."simple" = nix-darwin.lib.darwinSystem {
        modules = [
          configuration
          home-manager.darwinModules.home-manager
          {
            home-manager.users.whitehead = import ../home-manager;
            home-manager.extraSpecialArgs = {
              inherit pkgs-unstable;
              isDarwin = true;
            };
          }
        ];
      };
    };
}
