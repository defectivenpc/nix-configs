-- Per-directory session restore. Complements zellij's own resurrection, which
-- currently does not track a pane's cwd after you cd (upstream issue #4023):
-- even when zellij drops you in the wrong directory, <leader>qs here brings the
-- right set of buffers back.
require("persistence").setup()

local km = vim.keymap

km.set("n", "<leader>qs", function()
	require("persistence").load()
end, { desc = "Restore session for this directory" })

km.set("n", "<leader>ql", function()
	require("persistence").load({ last = true })
end, { desc = "Restore last session" })

km.set("n", "<leader>qd", function()
	require("persistence").stop()
end, { desc = "Don't save the current session" })
