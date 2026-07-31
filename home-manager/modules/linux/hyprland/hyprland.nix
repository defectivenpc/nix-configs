{ pkgs, lib, ... }:

let
  # Official NixOS artwork from nixpkgs. Curated and work-safe by provenance —
  # no fetching images from the open internet at build or run time, and the set
  # is pinned by the flake lock like everything else.
  #
  # To widen the pool with the GNOME set (photographic, also official/curated),
  # append `pkgs.gnome-backgrounds` to this list.
  wallpaperPackages =
    let
      art = pkgs.nixos-artwork.wallpapers;
    in
    [
      # Dark and neutral — these sit best against the gruvbox palette.
      art.nineish-dark-gray
      art.simple-dark-gray
      art.gradient-grey
      # Warm accent that echoes gruvbox's yellow/green.
      art.nineish-solarized-dark
      # Cooler NixOS blues, kept for variety.
      art.waterfall
      art.moonscape
      art.stripes
      art.mosaic-blue
    ];

  # Filenames and subdirectories differ per package (nix-wallpaper-*.png vs
  # NixOS-Gradient-grey.png, share/backgrounds vs share/artwork), so collect by
  # search rather than hardcoding paths.
  wallpaperPool = pkgs.runCommand "wallpaper-pool" { } ''
    mkdir -p "$out"
    ${lib.concatMapStringsSep "\n" (p: ''
      find -L ${lib.escapeShellArg p} -type f \( -iname '*.png' -o -iname '*.jpg' \) \
        -exec cp -n {} "$out"/ \;
    '') wallpaperPackages}
    chmod -R u+w "$out"
    if [ -z "$(ls -A "$out")" ]; then
      echo "wallpaper pool is empty — package layouts changed?" >&2
      exit 1
    fi
  '';

  # A fixed image for the lock screen — deliberately not the rotating one, so
  # the lock screen looks the same every time regardless of what the timer
  # last picked.
  lockWallpaper = pkgs.runCommand "lock-wallpaper.png" { } ''
    src=$(find -L ${pkgs.nixos-artwork.wallpapers.nineish-dark-gray} \
      -type f -iname '*.png' | head -1)
    [ -n "$src" ] || { echo "no png in nineish-dark-gray" >&2; exit 1; }
    cp "$src" "$out"
  '';

  # Picks a random wallpaper and cross-fades to it. Used both by the rotation
  # timer and once at session start.
  rotateWallpaper = pkgs.writeShellScript "rotate-wallpaper" ''
    img=$(${pkgs.findutils}/bin/find -L ${wallpaperPool} -type f | ${pkgs.coreutils}/bin/shuf -n1)
    [ -n "$img" ] || exit 0
    exec ${pkgs.swww}/bin/swww img "$img" \
      --transition-type any --transition-duration 2 --transition-fps 60
  '';
in
{
  services = {
    hypridle = {
      enable = true;
      # hypridle aborts on startup (SIGABRT, core dump) if it has no listeners
      # configured, which had it in a systemd restart loop. Sleep/suspend
      # targets are masked on these machines, so this only does DPMS.
      settings = {
        general = {
          # Games and video players hold an idle inhibitor (see the
          # `idleinhibit fullscreen` window rule); honour it.
          ignore_dbus_inhibit = false;
          ignore_systemd_inhibit = false;
        };

        lock_cmd = "pidof hyprlock || hyprlock";

        listener = [
          {
            # Lock first, then blank. Sleep/suspend are masked on these
            # machines, so without this nothing ever locks the session.
            timeout = 900; # 15 min
            on-timeout = "loginctl lock-session";
          }
          {
            timeout = 1800; # 30 min
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
        ];
      };
    };

    # swww rather than hyprpaper: hyprpaper needs every image preloaded into
    # memory up front and has no transition support, which makes rotation
    # awkward. swww is built for exactly this.
    swww.enable = true;
  };

  systemd.user = {
    services.wallpaper-rotate = {
      Unit = {
        Description = "Set a random wallpaper";
        After = [ "swww.service" ];
        Requires = [ "swww.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${rotateWallpaper}";
      };
      # Also fire once when the session comes up, not only on the timer.
      Install.WantedBy = [ "graphical-session.target" ];
    };

    timers.wallpaper-rotate = {
      Unit.Description = "Rotate the wallpaper periodically";
      Timer = {
        OnUnitActiveSec = "30m";
        # Without this the first rotation waits a full interval after the
        # service's initial run.
        OnActiveSec = "30m";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  # Was an exec-once pointing at a hardcoded ~/.nix-profile/libexec path, which
  # breaks the moment the package or username moves. A user unit can reference
  # the store path directly, which hyprland.conf cannot (it is read verbatim
  # via builtins.readFile).
  systemd.user.services.polkit-kde-agent = {
    Unit = {
      Description = "polkit-kde-authentication-agent-1";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # If hyprlock ever misbehaves, Ctrl+Alt+F2 to a TTY and `pkill hyprlock`
  # still works — it does not grab the VT.
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 5;
      };
      background = [
        {
          path = "${lockWallpaper}";
          blur_passes = 2;
          blur_size = 6;
        }
      ];
      input-field = [
        {
          size = "280, 45";
          outline_thickness = 2;
          dots_center = true;
          outer_color = "rgb(d8a657)";
          inner_color = "rgb(282828)";
          font_color = "rgb(d4be98)";
          fail_color = "rgb(ea6962)";
          check_color = "rgb(a9b665)";
          placeholder_text = "";
        }
      ];
    };
  };

  # $menu passes no --style, so wofi picks this up from XDG config.
  xdg.configFile."wofi/style.css".source = ../../../rawConfigs/wofi/style.css;

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    extraConfig = builtins.readFile ./hyprland.conf;
    systemd.enable = true;
  };
}
