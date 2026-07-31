vim.g.mapleader = " "

local opt = vim.opt

opt.number = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.autoindent = true
opt.ignorecase = true
opt.smartcase = true

opt.backspace = "indent,eol,start"

-- Undo history survives closing a buffer, and persists across restarts.
opt.undofile = true
opt.undolevels = 10000

opt.clipboard:append("unnamedplus")

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.termguicolors = true

require("lualine").setup()
local startify = require("alpha.themes.startify")
require("alpha").setup(startify.config)
require("which-key").setup()
require("dressing").setup()
