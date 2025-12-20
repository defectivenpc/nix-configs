{ config, pkgs, ... }:

{

  home.packages = with pkgs; [
    grc
    python3
    lsd
  ];

  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      initContent = ''
        if [ -f "$HOME/.secrets.env" ]; then
          source "$HOME/.secrets.env"
        fi

        if [ -f "$HOME/.extra.env" ]; then
          source "$HOME/.extra.env"
        fi
      '';
      shellAliases = {
        ls = "lsd";
        ll = "ls -l";
        z = "zellij -l welcome";
      };
      #plugins = [
      # {
      #   name = "vi-mode";
      #   src = pkgs.zsh-vi-mode;
      #   file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      # }
      #];
      zplug = {
        enable = true;
        plugins = [
          { name = "zpm-zsh/colorize"; }
          { name = "kutsan/zsh-system-clipboard"; }
          { name = "jeffreytse/zsh-vi-mode"; }
          { name = "unixorn/warhol.plugin.zsh"; }
        ];
      };

    };
  };
}
