{ ... }:

{
  services = {
    hypridle.enable = true;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    extraConfig = builtins.readFile ./hyprland.conf;
    systemd.enable = true;
  };
}
