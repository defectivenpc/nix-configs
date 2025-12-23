{
  config,
  pkgs,
  extra,
  pkgs-unstable,
  cosmicLib,
  ...
}:

{

  imports = [
    # ./programs/emacs.nix
    ./programs/hyprpanel.nix
  ];

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = true;
      permittedInsecurePackages = [
        "openssl-1.0.2u"
      ];
    };
  };

  home.stateVersion = "24.05";
  home.homeDirectory = "/home/whitehead";
  home.username = "whitehead";
  home.packages = with pkgs; [
    traceroute
    audacity
    age-plugin-yubikey
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
    dhall
    dhall-json
    semgrep
    silver-searcher
    wofi
    pavucontrol
    pulseaudio
    brave
    chromium
    librewolf
    ltex-ls
    zip
    unzip
    libreoffice
    nixd
    nixpkgs-fmt
    sops
    age
    vlc
    inkscape-with-extensions
    gimp
    blender
    docker-compose
    kdePackages.polkit-kde-agent-1
    glance
    htop
    wdisplays
    #Language servers
    yaml-language-server
    marksman
    ltex-ls
    vscode-langservers-extracted
    ripgrep
    nodejs
    deno
    nerd-fonts.dejavu-sans-mono
    lm_sensors
    hyprpanel
    # terminal
    lazygit
    lazysql
    ghostty
    # formatters
    tflint
    taplo
    shotcut
    kdePackages.kdenlive
    k9s
    kubectl
    kanidm
    cilium-cli
    kubetail
    qidi-slicer-bin
    wireguard-tools
    screen
    hugo
    pkgs-unstable.davinci-resolve-studio
  ];

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    name = "Nordzy-cursors";
    package = pkgs.nordzy-cursor-theme;
    size = 24;
  };

  gtk.iconTheme = {
    name = "Nordzy";
    package = pkgs.nordzy-icon-theme;
  };

  # home.sessionVariables = {
  #   EDITOR = "emc";
  # };

  programs = {
    waybar.enable = true;
    git = (import ./programs/git.nix);
    direnv = {
      enable = true;
      enableNushellIntegration = false;
      nix-direnv.enable = true;
    };
    ssh.forwardAgent = true;
    tmux = {
      enable = true;
      keyMode = "vi";
      historyLimit = 10000;
      shortcut = "a";
      extraConfig = ''
        set -g mouse on
      '';
    };
    zellij = (import ./programs/zellij.nix);
    kitty = (import ./programs/kitty.nix);
    nushell = (import ./programs/nushell.nix);
    ghostty = {
      enable = true;
      settings = {
        background-blur-radius = 20;
        theme = "catppuccin-mocha";
        window-theme = "dark";
        background-opacity = 1;
        minimum-contrast = 1.1;
        font-family = "DejaVu Sans Mono";
        font-size = 11;
        scrollback-limit = 524288000;
        gtk-titlebar = false;
        command = "nu";
      };

    };
    carapace = {
      enable = true;
      enableZshIntegration = true;
    };

    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        add_newline = true;
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };
      };
    };
    neovim = (
      import ./programs/neovim.nix {
        pkgs = pkgs;
        lib = pkgs.lib;
      }
    );
  };

  services = {
    hypridle.enable = true;
    # emacs = {
    #   enable = true;
    #   socketActivation.enable = true;
    #   client.enable = true;
    # };
  };

  xdg.configFile."waybar/config".source = ./rawConfigs/waybar/waybar.conf;
  xdg.configFile."wofi/style.css".source = ./rawConfigs/wofi/style.css;
  xdg.configFile."waybar/style.css".source = ./rawConfigs/waybar/style.css;
  xdg.configFile."hypr/hyprland.conf".source = ./rawConfigs/hypr/hyprland.conf;
  xdg.configFile."nixpkgs/config.nix".source = ./rawConfigs/nixpkgs/config.nix;
  xdg.configFile.nvim.source = ./rawConfigs/nvim;

  manual.manpages.enable = false;

  wayland.desktopManager.cosmic.shortcuts = [
    {
      action = cosmicLib.cosmic.mkRON "enum" "Close";
      key = "Super+C";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        value = [
          "brave"
        ];
        variant = "Spawn";
      };
      description = cosmicLib.cosmic.mkRON "optional" "Open Brave";
      key = "Super+B";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        value = [
          "ghostty"
        ];
        variant = "Spawn";
      };
      description = cosmicLib.cosmic.mkRON "optional" "Open terminal";
      key = "Super+Enter";
    }
  ];
}
