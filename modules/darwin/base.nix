{ pkgs, ... }:

{
  imports = [
    ../base.nix
    ./input.nix
  ];

  environment.systemPackages = with pkgs; [
    neovim
    home-manager
    ghostty-bin
  ];

  nix.settings.experimental-features = "nix-command flakes";

  system.stateVersion = 6;

  programs.zsh.enable = true;

  system.defaults.dock = {
    static-only = true;
    autohide = true;
  };
}
