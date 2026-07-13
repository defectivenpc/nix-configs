{
  config,
  pkgs,
  lib,
  isHeadless ? false,
  ...
}:

{

  home.packages = with pkgs; [
    grc
    python3
    lsd
  ];

  programs.zsh = {
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
    };

    # Plugins built at eval time from pinned sources — no runtime git clones,
    # works on headless hosts with no internet egress.
    plugins = [
      {
        name = "zsh-vi-mode";
        src = pkgs.zsh-vi-mode;
        file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      }
      {
        name = "warhol";
        src = pkgs.fetchFromGitHub {
          owner = "unixorn";
          repo = "warhol.plugin.zsh";
          rev = "58c70d31b859d1cd595c5d4477d616dcc557e480";
          sha256 = "0m05ps61cjya77d2lgkldfww29ybrs6i18f9fl40ssmsjbrmaqql";
        };
      }
      {
        name = "colorize";
        src = pkgs.fetchFromGitHub {
          owner = "zpm-zsh";
          repo = "colorize";
          rev = "1f1d49e02156c76a5feb796d598b37b7d0cffd69";
          sha256 = "0yp67gc2xpv7y95j6kdm0mm9r28f4xm3ba83z3kd3yj5q7di9d9f";
        };
      }
    ]
    # zsh-system-clipboard needs wl-clipboard/xsel/xclip. Skip on headless.
    ++ lib.optionals (!isHeadless) [
      {
        name = "zsh-system-clipboard";
        file = "zsh-system-clipboard.zsh";
        src = pkgs.fetchFromGitHub {
          owner = "kutsan";
          repo = "zsh-system-clipboard";
          rev = "5f1d497ee3c215a967c0e6b9a772e73c40332d52";
          sha256 = "1zphw3cg26khgixz1m5ii7h9f6jsm7hbbxh8lql1q2xzcq8r0xbn";
        };
      }
    ];
  };
}
