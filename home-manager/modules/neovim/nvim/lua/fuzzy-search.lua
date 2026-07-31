local telescope = require("telescope")

telescope.setup({
	extensions = {
		fzf = {
			fuzzy = true,
			override_generic_sorter = true,
			override_file_sorter = true,
			case_mode = "smart_case",
		},
	},
})

-- Must be loaded after setup(); otherwise fzf's sorter never takes over and
-- the pickers below silently keep using the slow Lua one.
telescope.load_extension("fzf")
telescope.load_extension("advanced_git_search")

local builtin = require("telescope.builtin")
local km = vim.keymap
km.set("n", "<leader>ff", builtin.find_files, { desc = "Telescope find files" })
km.set("n", "<leader>fg", builtin.live_grep, { desc = "Telescope live grep" })
km.set("n", "<leader>fb", builtin.buffers, { desc = "Telescope buffers" })
km.set("n", "<leader>fh", builtin.help_tags, { desc = "Telescope help tags" })

km.set("n", "<leader>fs", builtin.lsp_document_symbols, {})
km.set("n", "<leader>fi", "<cmd>AdvancedGitSearch<CR>")
km.set("n", "<leader>fw", builtin.grep_string, {})

km.set("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { desc = "Find todos" })
