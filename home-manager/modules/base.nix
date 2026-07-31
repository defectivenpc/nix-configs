{ config, pkgs, ... }:

{
  imports = [
    ./neovim
    ./emacs.nix
    ./ghostty.nix
    ./git.nix
    ./zellij.nix
    ./zsh.nix
    ./development/java.nix
  ];

  home.packages = with pkgs; [
    age-plugin-yubikey
    tflint
    taplo
    k9s
    kubectl
    cilium-cli
    kubetail
    screen
    lazygit
    lazysql
    vscode-langservers-extracted
    yaml-language-server
    marksman
    ltex-ls
    htop
    glance
    docker-compose
    age
    sops
    nixd
    zip
    dhall
    dhall-json
    semgrep
    unzip
    jdt-language-server
    ripgrep
    isort
    black
    prettierd
    nodejs
    fd
    tree-sitter
    cue
    cuelsp
    nickel
    nls
    nix-converter
    glab

    # treefmt (../../treefmt.toml) plus the per-language backends it drives.
    treefmt
    nixfmt-rfc-style
    stylua
    shfmt
    prettier

    bat
    just
    difftastic
    watchexec
    tealdeer
  ];

  # The NixOS-level nix.gc (nixos/lib/base.nix) runs as root, so it only prunes
  # /nix/var/nix/profiles. Modern Nix keeps this user's profile and the
  # home-manager generations under ~/.local/state/nix/profiles, which root's
  # collector has no idea about — they sat there pinning store paths until
  # collected by hand. This is the user-level counterpart; matching retention
  # to the system one keeps the two in step.
  #
  # Persistent (the default) matters on the laptops: a weekly timer that fires
  # while the machine is asleep would otherwise just be skipped.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
    # Don't collide with the root collector, which also runs on a weekly timer.
    randomizedDelaySec = "45min";
  };

  # SSH_AUTH_SOCK is deliberately NOT set here. nixos/lib/base.nix exports it
  # only when it is unset, so an inherited agent (e.g. a forwarded one, since
  # forwardAgent is on below) wins over the local yubikey-agent. Setting it
  # unconditionally here would override that guard.
  home.sessionVariables = {
    SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
  };

  programs = {
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks."*" = {
        forwardAgent = true;
        addKeysToAgent = "no";
        compression = false;
        # Keep the connection alive on flaky links.
        serverAliveInterval = 60;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        # Persistent multiplexed control connections: first ssh to a host
        # opens a master; subsequent ssh/scp/rsync reuse it and skip auth
        # entirely (including YubiKey touch). Master lingers 8h after the
        # last session exits, then cleans itself up.
        controlMaster = "auto";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "8h";
      };
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    # Ctrl-R history search, Ctrl-T file insert, Alt-C directory jump.
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
      # `c`, not the default `z` — `z` is the zellij launcher in zellij.nix.
      options = [
        "--cmd"
        "c"
      ];
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
  };

}
