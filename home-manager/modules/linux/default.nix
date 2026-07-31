{ pkgs, pkgs-unstable, ... }:

{

  imports = [
    ./hyprland
  ];

  home.packages = with pkgs; [
    traceroute
    audacity
    ffmpeg_6-full
    gphoto2
    mpv
    v4l-utils
    (pkgs.wrapOBS {
      plugins = with pkgs.obs-studio-plugins; [
        wlrobs
        obs-backgroundremoval
        obs-pipewire-audio-capture
        obs-vaapi # optional AMD hardware acceleration
        obs-gstreamer
        obs-vkcapture
      ];
    })

    dnsutils
    texliveFull
    google-chrome
    transmission_4-gtk
    brightnessctl
    # Screenshot + media keybinds in hyprland.conf.
    grim
    slurp
    playerctl
    zlib
    xsel
    imagemagick
    wofi
    pavucontrol
    pulseaudio
    brave
    chromium
    libreoffice
    vlc
    inkscape-with-extensions
    gimp
    blender
    # Was kdePackages.polkit-kde-agent-1, which came along with Plasma 6. Plasma
    # is gone, and something has to answer polkit or every privileged prompt
    # (mounting a disk, the KDE apps below) silently fails instead of asking.
    hyprpolkitagent
    # $fileManager (SUPER+E) is thunar now, enabled as a NixOS module in
    # nixos/lib/gui.nix — installing it here as a bare package would skip the
    # D-Bus service registration and its plugins.
    cliphist
    hyprpicker
    libnotify
    wdisplays
    deno
    nerd-fonts.dejavu-sans-mono
    lm_sensors
    hyprpanel
    shotcut
    qidi-slicer-bin
    wireguard-tools
    hugo
    # DaVinci Resolve's bundled Qt5 can't init its wayland plugin (aborts
    # in QGuiApplicationPrivate::createPlatformIntegration on cosmic).
    # Force xcb via XWayland so it launches cleanly.
    (pkgs.symlinkJoin {
      name = "davinci-resolve-studio-xcb";
      paths = [ pkgs-unstable.davinci-resolve-studio ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/davinci-resolve-studio \
          --set QT_QPA_PLATFORM xcb
      '';
    })
    gamescope
  ];

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
    };
  };

  # Dark by default: the portal reports color-scheme=dark (what the `z`
  # wrapper and browsers query) and GTK apps pick the dark stylesheet.
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };
}
