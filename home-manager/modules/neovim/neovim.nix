{
  pkgs,
  pkgs-unstable,
  lib,
  ...
}:
let
  fromGitHub =
    {
      repo,
      ref,
      rev,
      deps ? [ ],
      checks ? [ ],
    }:
    pkgs.vimUtils.buildVimPlugin {
      pname = lib.strings.sanitizeDerivationName repo;
      version = ref;

      src = builtins.fetchGit {
        url = "https://github.com/${repo}.git";
        ref = ref;
        rev = rev;
      };

      # Key bit: make require-check “see” dependent plugins
      propagatedBuildInputs = deps;
      dependencies = deps;

      nvimRequireCheck = checks;
    };

  gitlab-nvim =
    (fromGitHub {
      repo = "harrisoncramer/gitlab.nvim";
      ref = "v3.4.0";
      rev = "e29909cd1064a7b53c3150bff49449a548dadf8d";
    }).overrideAttrs
      (_: {
        doCheck = false;
      });

  avante-latest = pkgs.vimPlugins.avante-nvim.overrideAttrs (_old: {
    version = "git-latest";

    src = pkgs.fetchFromGitHub {
      owner = "yetone";
      repo = "avante.nvim";
      rev = "7e50de89049ea3540f0d39acec7b68a74a5d1edb";
      hash = "sha256-0PSZkDHoVSnDhbcxJ1koL31mTmHd5oOnLhLRKtTvzZQ=";
    };
  });

in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    extraLuaPackages = luaPkgs: with luaPkgs; [ luautf8 ];
    extraPackages = with pkgs; [
      lua-language-server
      nixd
      terraform-lsp
      typescript-language-server
      yaml-language-server
      nodePackages.bash-language-server
      dockerfile-language-server-nodejs
      docker-compose-language-service
      dhall-lsp-server
      helm-ls
      marksman
      rustfmt
      rust-analyzer
      nodePackages.prettier
      stylua
      nixfmt-rfc-style
      cuelsp
      go
    ];
    plugins = with pkgs.vimPlugins; [
      nvim-lspconfig
      plenary-nvim
      nvim-treesitter.withAllGrammars
      catppuccin-nvim
      oil-nvim
      lualine-nvim
      telescope-nvim
      which-key-nvim
      alpha-nvim
      dressing-nvim
      nvim-ts-autotag
      indent-blankline-nvim
      luasnip
      nvim-cmp
      cmp_luasnip
      cmp-buffer
      cmp-path
      cmp-nvim-lsp
      friendly-snippets
      lspkind-nvim
      nvim-autopairs
      nvim-ts-context-commentstring
      comment-nvim
      todo-comments-nvim
      substitute-nvim
      nvim-surround
      neodev-nvim
      nvim-lspconfig
      nvim-lsp-file-operations
      trouble-nvim
      mini-icons
      conform-nvim
      gitsigns-nvim
      lazygit-nvim
      #orgmode
      direnv-vim
      nvim-tree-lua
      render-markdown-nvim
      nvim-jdtls
      nvim-web-devicons
      nui-nvim
      avante-latest
      #markdown-preview-nvim
      vim-nickel
      nvim-treesitter-parsers.nickel
      gitlinker-nvim
      diffview-nvim
      #gitlab-nvim

    ];
  };
  xdg.configFile.nvim.source = ./nvim;
}
