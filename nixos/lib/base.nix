{ pkgs, ... }:

{

  nixpkgs.config.allowUnfree = true;

  boot = {
    loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 5;
      efi.canTouchEfiVariables = true;
    };
    supportedFilesystems = [ "ntfs" ];
  };

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    settings = {
      trusted-public-keys = [
        "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      substituters = [
        "https://cache.iog.io"
        "https://nix-community.cachix.org"
      ];
      trusted-users = [ "@wheel" ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
    };
  };

  environment.systemPackages = with pkgs; [
    wget
    vim
    git
    tree
    home-manager
    linux-firmware
    yubikey-manager
    mdadm
    pciutils
    usbutils
    sops
    step-cli
    xkcdpass
    htop
    iotop
    ghostty
    mbuffer
    smartmontools
    pv
    piv-agent
  ];

  services.pcscd.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];

  systemd.user.sockets.piv-agent = {
    description = "piv-agent socket activation";
    socketConfig = {
      ListenStream = "%t/piv-agent/ssh.socket";
      SocketMode = "0600";
      DirectoryMode = "0700";
      RuntimeDirectory = "piv-agent";
    };
    wantedBy = [ "sockets.target" ];
  };

  systemd.user.services.piv-agent = {
    description = "piv-agent service";
    requires = [ "piv-agent.socket" ];
    after = [ "piv-agent.socket" ];
    serviceConfig = {
      ExecStart = "${pkgs.piv-agent}/bin/piv-agent serve --agent-types=ssh=0";
      Type = "simple";
    };
  };

  environment.extraInit = ''
    if [ -z "$SSH_AUTH_SOCK" -a -n "$XDG_RUNTIME_DIR" ]; then
      export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/piv-agent/ssh.socket"
    fi
  '';

  fonts.packages = with pkgs; [
    dejavu_fonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    font-awesome_5
  ];

  hardware = {
    enableRedistributableFirmware = true;
  };

  security.rtkit.enable = true;

  services = {
    openssh.enable = true;
    printing.enable = true;
    avahi = {
      enable = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
      nssmdns4 = true;
      openFirewall = true;
    };
    acpid.enable = true;
    keyd = {
      enable = true;
      keyboards.default = {
        ids = [ "*" ];
        settings = {
          main = {
            capslock = "layer(meta)";
            leftalt = "layer(control)";
            leftcontrol = "layer(alt)";
          };
        };
      };
    };
  };

  time.timeZone = "US/Mountain";

  system.stateVersion = "24.05";

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "latarcyrheb-sun32";
    keyMap = "us";
  };
}
