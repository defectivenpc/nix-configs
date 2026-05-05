{
  config,
  pkgs,
  extra,
  pkgs-unstable,
  cosmicLib,
  ...
}:

{

  imports = [
    ./modules/base.nix
    ./modules/linux
    ./modules/personal
  ];

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = true;
      permittedInsecurePackages = [
        "openssl-1.0.2u"
      ];
    };
  };

  home.file.".config/nixpkgs/config.nix".text = ''
    { 
      allowUnfree = true;
    }
  '';

  home.stateVersion = "24.05";
  home.homeDirectory = "/home/whitehead";
  home.username = "whitehead";

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    name = "Nordzy-cursors";
    package = pkgs.nordzy-cursor-theme;
    size = 24;
  };

  gtk.iconTheme = {
    name = "Nordzy";
    package = pkgs.nordzy-icon-theme;
  };

  # home.sessionVariables = {
  #   EDITOR = "emc";
  # };

  # services = {
  #   hypridle.enable = true;
  # emacs = {
  #   enable = true;
  #   socketActivation.enable = true;
  #   client.enable = true;
  # };
  # };

  #xdg.configFile."waybar/config".source = ./rawConfigs/waybar/waybar.conf;
  #xdg.configFile."wofi/style.css".source = ./rawConfigs/wofi/style.css;
  #xdg.configFile."waybar/style.css".source = ./rawConfigs/waybar/style.css;
  #xdg.configFile."hypr/hyprland.conf".source = ./rawConfigs/hypr/hyprland.conf;
  #xdg.configFile."nixpkgs/config.nix".source = ./rawConfigs/nixpkgs/config.nix;

  manual.manpages.enable = false;
}
