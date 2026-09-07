{
  pkgs,
  pkgs-unstable,
  lib,
  isDarwin ? false,
  isHeadless ? false,
  withClaudeCode ? false,
  username,
  ...
}:
let
  # Single source of truth: applied to home-manager builds via nixpkgs.config
  # below, and written verbatim to ~/.config/nixpkgs/config.nix so ad-hoc
  # nix-shell / nix-env invocations see identical settings.
  nixpkgsConfig = {
    allowUnfree = true;
  };
in
{
  imports = [
    ./modules/base.nix
  ]
  ++ lib.optionals (!isDarwin && !isHeadless) [
    ./modules/linux
    ./modules/personal
  ];

  nixpkgs.config = nixpkgsConfig;

  nixpkgs.overlays = lib.optionals isDarwin [
    (_: super: {
      direnv = super.direnv.overrideAttrs (_: {
        doCheck = false;
      });
    })
  ];

  home.username = username;
  home.homeDirectory = if isDarwin then "/Users/${username}" else "/home/${username}";
  home.stateVersion = if isDarwin then "25.05" else "24.05";

  home.packages = lib.optionals (isDarwin && withClaudeCode) [
    (import ./modules/personal/claude-code.nix { inherit pkgs pkgs-unstable; })
  ];

  home.file = lib.optionalAttrs (!isDarwin) {
    ".config/nixpkgs/config.nix".text = lib.generators.toPretty { } nixpkgsConfig;
  };

  home.pointerCursor = lib.mkIf (!isDarwin && !isHeadless) {
    gtk.enable = true;
    x11.enable = true;
    name = "Nordzy-cursors";
    package = pkgs.nordzy-cursor-theme;
    size = 24;
  };

  gtk.iconTheme = lib.mkIf (!isDarwin && !isHeadless) {
    name = "Nordzy";
    package = pkgs.nordzy-icon-theme;
  };

  manual.manpages.enable = false;
}
