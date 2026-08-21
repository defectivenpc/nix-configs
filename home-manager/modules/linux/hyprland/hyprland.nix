{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  # mises has two AMD GPUs: the discrete Navi 48 at 03:00.0, which both monitors
  # are plugged into, and the Granite Ridge iGPU at 7b:00.0. Left alone,
  # aquamarine opens and drives both, so the session pays multi-GPU setup and
  # buffer-copy costs for a card that has no displays on it. Pin it to the card
  # that does.
  #
  # /dev/dri/dgpu is a udev symlink created in nixos/machines/mises/mises.nix.
  # AQ_DRM_DEVICES splits its value on ':', so the obvious stable name --
  # /dev/dri/by-path/pci-0000:03:00.0-card -- is torn into three nonexistent
  # paths, aquamarine finds no GPU, and Hyprland aborts before it ever opens a
  # display. Hence a colon-free symlink rather than the by-path name, and not
  # /dev/dri/card1 either: card numbering is not stable across boots.
  #
  # /dev/dri/evdi0 is the DisplayLink virtual card backing the Elgato Prompter
  # (see nixos/lib/displaylink.nix). It has to be listed explicitly: this
  # variable is an allowlist, so pinning to the dGPU alone leaves the Prompter
  # detected by DisplayLinkManager but never scanned out by the compositor --
  # the black-screen failure everyone hits. The card is pre-created at boot via
  # evdi's initial_device_count, so this path exists whether or not the
  # Prompter is actually plugged in, and aquamarine never sees a missing node.
  gpuPin = lib.optionalString (
    osConfig.networking.hostName == "mises"
  ) "env = AQ_DRM_DEVICES,/dev/dri/dgpu:/dev/dri/evdi0\n";
  # Official NixOS artwork from nixpkgs. Pinned by the flake lock like
  # everything else, and available with no network — this is the fallback pool
  # the rotation uses when the fetched cache is empty (no API key, no network,
  # or a fresh machine that hasn't run wallpaper-fetch yet).
  #
  # To widen it with the GNOME set (photographic, also official/curated),
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

  # Builds the motivational set: Pexels photography with a ZenQuotes quote
  # composited over it. Kept as a separate shell file rather than an inline
  # nix string because the script is full of `${...}` and `$(...)`, every one
  # of which would need escaping as `''${...}` inside a nix '' literal.
  #
  # The fonts are pinned to store paths rather than passed as family names.
  # ImageMagick resolves family names through fontconfig, which depends on the
  # ambient environment of whatever spawned it — fine interactively, not fine
  # in a user unit that inherits almost nothing.
  wallpaperFetch = pkgs.writeShellApplication {
    name = "wallpaper-fetch";
    runtimeInputs = with pkgs; [
      curl
      jq
      imagemagick
      coreutils
      findutils
    ];
    text =
      let
        dejavu = "${pkgs.dejavu_fonts}/share/fonts/truetype";
      in
      ''
        : "''${WALLPAPER_FONT:=${dejavu}/DejaVuSerif.ttf}"
        : "''${WALLPAPER_FONT_BOLD:=${dejavu}/DejaVuSerif-Bold.ttf}"
      ''
      + builtins.readFile ./wallpaper-fetch.sh;
  };

  # Undoes the workspace evacuation that a monitor disconnect causes — see the
  # header of the script for why `dpms off' counts as a disconnect here.
  restoreWorkspaces = pkgs.writeShellApplication {
    name = "restore-workspaces";
    runtimeInputs = with pkgs; [
      jq
      hyprland
    ];
    text = builtins.readFile ./restore-workspaces.sh;
  };

  # Picks a random wallpaper and cross-fades to it. Used both by the rotation
  # timer and once at session start.
  #
  # Prefers the fetched cache and only falls back to the nix pool when it is
  # empty — mixing the two would put flat NixOS gradients in the same rotation
  # as photography, which reads as a bug rather than as variety. The fallback
  # exists so a machine with no API key still gets a wallpaper.
  rotateWallpaper = pkgs.writeShellScript "rotate-wallpaper" ''
    cache="''${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-fetch/images"
    dir=${wallpaperPool}
    if [ -n "$(${pkgs.findutils}/bin/find "$cache" -maxdepth 1 -type f -print -quit 2>/dev/null)" ]; then
      dir="$cache"
    fi
    img=$(${pkgs.findutils}/bin/find -L "$dir" -type f | ${pkgs.coreutils}/bin/shuf -n1)
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

          # hypridle reads this as `general:lock_cmd'. Sitting one level up,
          # as a sibling of `general', it parsed as an unknown top-level key
          # and was silently dropped -- the 900s listener logged `Running
          # loginctl lock-session' and `Got Lock from dbus', then nothing.
          # The session has not actually been locking on idle.
          #
          # Both binaries are pinned to the store because this unit runs with
          # `Environment=' empty and inherits whatever PATH the systemd user
          # manager happens to hold; a bare `hyprlock' is not guaranteed to
          # resolve, and failing to resolve here means failing to lock.
          # pidof guards against stacking a second instance on repeat Locks.
          lock_cmd = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
        };

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
            # Blanking here destroys the wl_output globals outright rather
            # than just powering the panels down -- hypridle's own log shows
            # `removed iface 63/64' a second after `dpms on', then two fresh
            # `got iface: wl_output' three seconds later. astal does not
            # survive that round trip: the bars are torn down and the rebuild
            # trips `astal_hyprland_monitor_get_id: assertion self != NULL',
            # leaving hyprpanel with a null monitor ("no window with name
            # bar-0", "No focused monitor available"). The workspaces module
            # is the only one that resolves per-monitor, so it alone comes
            # back empty -- the workspace numbers vanish while the clock and
            # the system readouts keep updating.
            #
            # Nothing reattaches that reference, so the panel has to be
            # rebuilt. Sleep past the ~3s it takes the outputs to reappear;
            # restarting into the gap leaves the new instance just as
            # monitorless as the old one.
            #
            # The same teardown strands workspaces on the wrong panel — only
            # the `default:true' one is pulled back on reconnect — hence the
            # restore, after the same sleep: it can only move a workspace to a
            # monitor that is already back.
            on-resume = "hyprctl dispatch dpms on && sleep 5 && ${restoreWorkspaces}/bin/restore-workspaces && systemctl --user restart hyprpanel.service";
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

    services.wallpaper-fetch = {
      Unit.Description = "Build motivational wallpapers from Pexels + ZenQuotes";
      Service = {
        Type = "oneshot";
        ExecStart = "${wallpaperFetch}/bin/wallpaper-fetch";
        # Every failure path in the script exits 0 on purpose, so a non-zero
        # exit here means a real bug rather than a flaky network.
        TimeoutStartSec = "10m";
      };
    };

    # Note there is no WantedBy on the service: the timer alone pulls it in.
    # Running at session start too would mean a burst of API calls on every
    # login, and the cache holds days of images — there is nothing to catch up
    # on at boot.
    timers.wallpaper-fetch = {
      Unit.Description = "Refresh the motivational wallpaper cache";
      Timer = {
        OnCalendar = "daily";
        # Missed runs (machine off overnight) fire on next boot rather than
        # waiting a full day.
        Persistent = true;
        # Don't hammer the API the instant the timer is due.
        RandomizedDelaySec = "30m";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  # Was an exec-once pointing at a hardcoded ~/.nix-profile/libexec path, which
  # breaks the moment the package or username moves. A user unit can reference
  # the store path directly, which hyprland.conf cannot (it is read verbatim
  # via builtins.readFile).
  #
  # polkit-kde-agent-1 until Plasma 6 was removed; hyprpolkitagent is the
  # equivalent that does not drag KDE back in.
  systemd.user.services.polkit-agent = {
    Unit = {
      Description = "hyprpolkitagent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # Same reasoning as hyprpanel: don't burn the start limit against a
      # display that is mid-restart and end up permanently failed.
      StartLimitIntervalSec = 0;
    };
    Service = {
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Restart = "on-failure";
      RestartSec = 3;
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
    extraConfig = gpuPin + builtins.readFile ./hyprland.conf;
    systemd.enable = true;
  };
}
