{
  config,
  pkgs,
  ...
}:

{

  imports = [
    ./modules/base.nix
  ];

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
    overlays = [
      (_: super: {
        direnv = super.direnv.overrideAttrs (_: {
          doCheck = false;
        });
      })
    ];
  };

  home.stateVersion = "25.05";
  home.homeDirectory = "/Users/whitehead";
  home.username = "whitehead";
  home.packages = with pkgs; [
    claude-code
  ];

  #manual.manpages.enable = true;
}
