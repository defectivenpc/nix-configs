require("grug-far").setup({
	-- ripgrep is already a dependency of telescope's live_grep, so no new tools.
	engine = "ripgrep",
})

local km = vim.keymap

km.set("n", "<leader>sr", function()
	require("grug-far").open()
end, { desc = "Search and replace across the project" })

km.set("n", "<leader>sw", function()
	require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
end, { desc = "Search and replace word under cursor" })

km.set("x", "<leader>sr", function()
	require("grug-far").open({ visualSelectionUsage = "operate-within-range" })
end, { desc = "Search and replace within selection" })
