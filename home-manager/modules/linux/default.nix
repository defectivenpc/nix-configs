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
    zlib
    xsel
    imagemagick
    wofi
    pavucontrol
    pulseaudio
    brave
    chromium
    ltex-ls
    libreoffice
    vlc
    inkscape-with-extensions
    gimp
    blender
    kdePackages.polkit-kde-agent-1
    wdisplays
    deno
    nerd-fonts.dejavu-sans-mono
    lm_sensors
    hyprpanel
    lazygit
    lazysql
    ghostty
    shotcut
    kdePackages.kdenlive
    qidi-slicer-bin
    wireguard-tools
    screen
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
    };
  };
}
