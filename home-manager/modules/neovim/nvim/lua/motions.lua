require("flash").setup()

local km = vim.keymap

-- Deliberately NOT s/S (flash's upstream default): lua/subst.lua binds those to
-- substitute.nvim's operator/eol in normal and visual mode. flash also enhances
-- f/t/F/T/;/, out of the box via modes.char, which collides with nothing here.
-- <leader>j/J rather than <leader>s/S: lua/search-replace.lua owns the
-- <leader>s prefix, and a bare <leader>s mapping would stall every
-- <leader>sr for the length of timeoutlen.
km.set({ "n", "x", "o" }, "<leader>j", function()
	require("flash").jump()
end, { desc = "Flash jump" })

km.set({ "n", "x", "o" }, "<leader>J", function()
	require("flash").treesitter()
end, { desc = "Flash treesitter select" })
