{ config, pkgs, ... }:

{
  imports = [
    ./neovim
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
    nixpkgs-fmt
    nixd
    zip
    dhall
    dhall-json
    semgrep
    silver-searcher
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
    nixfmt-rfc-style
  ];

  home.sessionVariables = {
    SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
    SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/yubikey-agent/yubikey-agent.sock";
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
        # entirely (including YubiKey touch). Master lingers 10m after the
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
