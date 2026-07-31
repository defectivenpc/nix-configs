local subst = require("substitute")

vim.keymap.set("n", "s", subst.operator, {})
vim.keymap.set("n", "ss", subst.line, {})
vim.keymap.set("n", "S", subst.eol, {})
vim.keymap.set("x", "s", subst.visual, {})
