{ pkgs, ... }:

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

  services = {
    displayManager = {
      gdm.enable = true;

    };
    desktopManager = {
      cosmic.enable = true;
      gnome.enable = true;
      plasma6.enable = true;
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
