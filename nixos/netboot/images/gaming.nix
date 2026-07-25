# Ephemeral gaming OS, netbooted, stateless, boots on any of the desktops.
#
# Root is a tmpfs and the Nix store is a read-only squashfs fetched over HTTP
# (see ../http-store.nix), so nothing here survives a reboot except what lives
# on the labelled local partitions or on nas1.
#
# Deliberately does NOT import ../../lib/base.nix or ../../lib/gui.nix:
#
#   * base.nix pulls in lib/auto-update.nix (nixos-rebuild against a read-only
#     store), systemd-boot (there is no ESP), and nix.gc/auto-optimise-store,
#     all meaningless on an ephemeral image.
#   * gui.nix enables COSMIC *and* GNOME *and* Plasma 6 *and* Hyprland at once.
#     On a normal machine that is disk you already paid for; here it is a
#     multi-GB download to every machine on every rebuild. One desktop only.
#
# The gaming-relevant parts of gui.nix (pipewire with 32-bit ALSA, gamemode,
# steam + gamescope, disabled sleep targets) are reproduced below. If that
# duplication starts to drift, factor a lib/gaming-core.nix out of gui.nix and
# import it from both.

{
  config,
  pkgs,
  lib,
  ...
}:

let
  yubikey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAlxuKI8DZvdMA7dHTXG9NATaw9D2RGMQqQKwef4m2oeHFI/r+cPHICtC0SYYk6woPSjjZR7PtiP2VSn0eoX3yk= YubiKey #26922176 PIV Slot 9a (touch: cached)";

  # ---------------------------------------------------------------------------
  # AUTH: single shared password until centralized auth exists.
  #
  # This is the ONLY place credentials are defined, so the swap later is
  # localized. Note it ships in the world-readable Nix store on the boot
  # server — acceptable for a LAN-only image, and a reason not to put anything
  # else sensitive in here.
  #
  # sops-nix is NOT a drop-in replacement here: lib/sops.nix expects an age key
  # at /var/lib/sops-nix/key.txt, which does not exist on a tmpfs root and
  # cannot be baked into a squashfs that every machine downloads. The real
  # answer is central auth (the `idm` record already exists), at which point
  # this becomes a pam/sssd config and the literal disappears.
  # ---------------------------------------------------------------------------
  defaultPassword = "changeme";

  # Chooses the GL/GBM vendor from what gpu-vendor-detect found, then hands off
  # to the gamescope Steam session. Static env would break one vendor or the
  # other, see gaming-gpu.nix.
  #
  # The session command is read out of the steam.desktop entry that
  # programs.steam.gamescopeSession.enable registers, rather than hardcoded:
  # `steam-gamescope` is its own derivation inside the steam module's `let`,
  # not something `programs.steam.package` exposes, so there is no option to
  # reference it by. Reading the Exec line keeps us honest across upgrades.
  steamSession = pkgs.writeShellScript "gaming-session" ''
    vendor=$(cat /run/gpu-vendor 2>/dev/null || echo other)
    if [ "$vendor" = nvidia ]; then
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export GBM_BACKEND=nvidia-drm
    fi

    sessionFile=${config.services.displayManager.sessionData.desktops}/share/wayland-sessions/steam.desktop
    sessionExec=$(${pkgs.gnugrep}/bin/grep -m1 '^Exec=' "$sessionFile" | ${pkgs.coreutils}/bin/cut -d= -f2-)
    if [ -z "$sessionExec" ]; then
      echo "no Exec= in $sessionFile — falling back to a plain desktop session" >&2
      exit 1
    fi

    # Steam wants a session bus; greetd hands us a bare PAM session.
    exec ${pkgs.dbus}/bin/dbus-run-session $sessionExec
  '';
in
{
  imports = [
    ./gaming-gpu.nix
    ./gaming-disks.nix
    ./gaming-saves.nix
  ];

  networking.hostName = lib.mkForce "gamebox";
  networking.useDHCP = true;
  networking.firewall.enable = false; # LAN-only netboot appliance

  # Stateless image: track nixpkgs rather than inheriting base.nix's 24.05.
  system.stateVersion = "25.11";
  nixpkgs.config.allowUnfree = true;

  # ---------------- user ----------------
  # uid/gid are pinned because nas1's export squashes to anonuid=1000,
  # anongid=100. Change them here and saves land as `nobody`.
  users.mutableUsers = false;
  users.users.player = {
    isNormalUser = true;
    uid = 1000;
    group = "users";
    home = "/home/player";
    createHome = true;
    description = "Gaming";
    extraGroups = [
      "wheel"
      "video"
      "audio"
      "input"
      "gamemode"
    ];
    initialPassword = defaultPassword;
    openssh.authorizedKeys.keys = [ yubikey ];
  };
  users.users.root = {
    initialPassword = defaultPassword;
    openssh.authorizedKeys.keys = [ yubikey ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # ---------------- session ----------------
  # Straight into Big Picture. Quitting Steam drops to the greeter, where the
  # Plasma session is the escape hatch to a normal desktop.
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${steamSession}";
        user = "player";
      };
      default_session = {
        command = lib.concatStringsSep " " [
          "${pkgs.tuigreet}/bin/tuigreet"
          "--time"
          "--remember"
          "--asterisks"
          "--sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
        ];
        user = "greeter";
      };
    };
  };

  services.desktopManager.plasma6.enable = true;

  # ---------------- gaming core ----------------
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  programs.gamemode.enable = true;
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
  hardware.steam-hardware.enable = true; # controller udev rules

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;
  services.system76-scheduler.enable = true;

  # A netbooted machine that suspends wakes up with a store it can no longer
  # re-fetch cleanly; same reasoning as gui.nix.
  systemd.targets.sleep.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  environment.systemPackages = with pkgs; [
    mangohud
    protonup-qt
    vulkan-tools
    mesa-demos
    vim
    htop
    pciutils
    usbutils
    curl
    gptfdisk
    e2fsprogs
    parted
    (import ../provision-disks.nix { inherit pkgs; })
  ];

  hardware.enableRedistributableFirmware = true;
  boot.supportedFilesystems = [
    "ntfs"
    "ext4"
  ];

  # Every byte here is downloaded by every machine on every rebuild.
  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;
  documentation.info.enable = false;

  fonts.packages = with pkgs; [
    dejavu_fonts
    noto-fonts
    noto-fonts-color-emoji
  ];

  time.timeZone = "US/Mountain";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
}
