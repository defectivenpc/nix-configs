vim.o.termguicolors = true

require("catppuccin").setup({
	flavour = "mocha",
})

vim.cmd.colorscheme("catppuccin-mocha")

require("global")
require("tree-sitter")
require("directory")
require("fuzzy-search")
require("autocomplete")
require("autopairs")
require("comments")
require("remaps")
require("surround")
require("subst")
require("lsp")
require("formatter")
require("git")
require("nix-tools")
require("markdown")
require("avante-cfg")
