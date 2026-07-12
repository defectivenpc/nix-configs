{ pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  imports = [
    ./modules/base.nix
  ]
  ++ lib.optionals (!isDarwin) [
    ./modules/linux
    ./modules/personal
  ];

  nixpkgs.config = {
    allowUnfree = true;
  }
  // lib.optionalAttrs (!isDarwin) {
    allowBroken = true;
    permittedInsecurePackages = [ "openssl-1.0.2u" ];
  };

  nixpkgs.overlays = lib.optionals isDarwin [
    (_: super: {
      direnv = super.direnv.overrideAttrs (_: {
        doCheck = false;
      });
    })
  ];

  home.username = "whitehead";
  home.homeDirectory = if isDarwin then "/Users/whitehead" else "/home/whitehead";
  home.stateVersion = if isDarwin then "25.05" else "24.05";

  home.packages = lib.optionals isDarwin (with pkgs; [ claude-code ]);

  home.file = lib.optionalAttrs (!isDarwin) {
    ".config/nixpkgs/config.nix".text = ''
      {
        allowUnfree = true;
      }
    '';
  };

  home.pointerCursor = lib.mkIf (!isDarwin) {
    gtk.enable = true;
    x11.enable = true;
    name = "Nordzy-cursors";
    package = pkgs.nordzy-cursor-theme;
    size = 24;
  };

  gtk.iconTheme = lib.mkIf (!isDarwin) {
    name = "Nordzy";
    package = pkgs.nordzy-icon-theme;
  };

  manual.manpages.enable = false;
}
