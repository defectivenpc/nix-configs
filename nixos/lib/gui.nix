{
  config,
  lib,
  pkgs,
  ...
}:

{

  environment.systemPackages = with pkgs; [
    brightnessctl
    gtk-engine-murrine
    gtk_engines
    gsettings-desktop-schemas
    lxappearance
    libsForQt5.qt5.qtwayland
    kdePackages.qtwayland
    wl-clipboard
    brave
    gamescope
    gamemode
    mangohud
    protonup-qt
  ];

  # Electron/Chromium apps (Brave, Chrome, VSCode) default to XWayland, which
  # costs them fractional scaling, correct DPI and a frame of input latency.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  nixpkgs.overlays = [
    (self: super: {
      wl-clipboard-x11 = super.stdenv.mkDerivation rec {
        pname = "wl-clipboard-x11";
        version = "5";

        src = super.fetchFromGitHub {
          owner = "brunelli";
          repo = "wl-clipboard-x11";
          rev = "v${version}";
          sha256 = "1y7jv7rps0sdzmm859wn2l8q4pg2x35smcrm7mbfxn5vrga0bslb";
        };

        dontBuild = true;
        dontConfigure = true;
        propagatedBuildInputs = [ super.wl-clipboard ];
        makeFlags = [ "PREFIX=$(out)" ];
      };
      xsel = self.wl-clipboard-x11;
      xclip = self.wl-clipboard-x11;
    })
  ];

  # GNOME and Plasma 6 are gone. Neither was ever the session actually used --
  # Hyprland is -- but both were installed in full, and Plasma's share of that
  # was not free: drkonqi, its crash handler, kept running under Hyprland and
  # turned a hypridle restart loop into 1.07 million files (39 GiB) under
  # ~/.cache/drkonqi. Removing plasma6 takes drkonqi with it, along with the
  # plasma-* user units that were still being pulled into graphical-session.
  #
  # COSMIC stays; it was not part of the ask.
  services = {
    desktopManager = {
      cosmic.enable = true;
    };

    # greetd + ReGreet in place of GDM. GDM's greeter *is* gnome-shell, so it
    # was the single largest thing keeping GNOME installed. ReGreet is one GTK4
    # window, and being GTK it inherits the same theme/icons/cursor as the
    # session rather than looking like a stock GNOME login.
    greetd = {
      enable = true;
      settings.default_session = {
        # The module defaults this to cage, but only with mkDefault. Hyprland
        # is already built for these hosts, so reusing it avoids pulling in
        # cage and a second wlroots for the sake of one login window.
        command = "${lib.getExe config.programs.hyprland.package} --config /etc/greetd/hyprland.conf";
        user = "greeter";
      };
    };

    system76-scheduler.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # $fileManager for hyprland.conf, replacing dolphin. Dolphin is Qt and pulled
  # ~1.8G of KDE Frameworks behind it for a file browser; thunar is 326M, is GTK
  # so it matches the rest of the session's theming without a second toolkit to
  # configure, and is a NixOS module rather than a bare package -- which is what
  # gets the D-Bus service and the plugins below registered properly.
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      # Right-click extract/compress.
      thunar-archive-plugin
      # Handles removable media (auto-mount, camera/USB actions). Without it
      # plugging in a drive does nothing visible.
      thunar-volman
    ];
  };

  # Thumbnails. Thunar shows generic icons for every image and video without it.
  services.tumbler.enable = true;

  # Trash support, plus mounting MTP/SMB/network shares from the sidebar.
  services.gvfs.enable = true;

  # The greeter runs as the `greeter` user, so it cannot see the home-manager
  # GTK config and would otherwise come up stock Adwaita/Adwaita/Cantarell --
  # a light login screen in front of a dark session. Mirror what
  # home-manager/modules/linux sets for the real session. Setting these via the
  # module options rather than settings.GTK also gets the theme packages
  # installed system-wide, which the greeter needs to actually resolve them.
  programs.regreet = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Nordzy";
      package = pkgs.nordzy-icon-theme;
    };
    cursorTheme = {
      name = "Nordzy-cursors";
      package = pkgs.nordzy-cursor-theme;
    };
  };

  # The compositor the greeter runs inside. Deliberately minimal: no wallpaper
  # daemon, no animations, no logo -- ReGreet paints the whole screen, and
  # anything else here is just latency between power-on and the password field.
  #
  # `hyprctl dispatch exit` is what makes this work as a greeter at all: without
  # it Hyprland lingers after ReGreet exits and greetd never gets to hand over
  # to the real session.
  environment.etc."greetd/hyprland.conf".text = ''
    misc {
        disable_hyprland_logo = true
        disable_splash_rendering = true
        force_default_wallpaper = 0
    }

    animations {
        enabled = false
    }

    exec-once = ${lib.getExe pkgs.greetd.regreet}; hyprctl dispatch exit
  '';

  # The gtk backend is the only installed portal impl that serves
  # org.freedesktop.appearance (dark mode). It is purely D-Bus activated, so a
  # portal restart under load can blow the 25s activation timeout, leaving the
  # frontend with no Settings interface at all -- every app then falls back to
  # light and, being long-lived, stays there. Start it with the session instead.
  systemd.user.services.xdg-desktop-portal-gtk = {
    overrideStrategy = "asDropin";
    wantedBy = [ "graphical-session.target" ];
  };

  xdg.portal.config.Hyprland."org.freedesktop.impl.portal.Settings" = [ "gtk" ];

  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        # Bump the game to the top of the scheduler and the highest realtime
        # I/O class the moment gamemoded activates.
        renice = 10;
        ioprio = 0;
        softrealtime = "auto";
        inhibit_screensaver = 1;
      };
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send -a gamemode 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send -a gamemode 'GameMode ended'";
      };
    };
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
    # Wires MangoHud/gamemode/proton-ge into the Steam runtime so
    # `gamemoderun mangohud %command%` works from Steam launch options.
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  # gamescope needs CAP_SYS_NICE to set realtime priority on its render thread;
  # without it every launch logs a priority warning and falls back to normal
  # scheduling.
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # Proton/Wine and several Unity and Source-engine titles map far more
  # discrete regions than the 65530 default allows and crash on startup.
  boot.kernel.sysctl."vm.max_map_count" = 2147483642;

  # Steam Play shader pre-caching and large game installs blow past the default
  # per-process file descriptor limit.
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "524288";
    }
  ];

  networking.firewall = {
    enable = false;
  };

  systemd.targets.sleep.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
}
