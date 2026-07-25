{ pkgs, pkgs-unstable, ... }:

{
  home.packages = [
    (import ./claude-code.nix { inherit pkgs pkgs-unstable; })
  ];
}
