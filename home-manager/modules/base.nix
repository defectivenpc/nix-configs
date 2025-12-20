{ config, pkgs, ... }:

{
  imports = [
    ./neovim
    ./ghostty.nix
    ./git.nix
    ./nushell
    ./zellij.nix
    ./zsh.nix
    ./development/java.nix
  ];

  home.packages = with pkgs; [
    kanidm_1_7
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
    nixfmt
  ];

  home.sessionVariables = {
    SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
  };

  programs = {
    ssh.forwardAgent = true;
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

  services.yubikey-agent.enable = true;
}
