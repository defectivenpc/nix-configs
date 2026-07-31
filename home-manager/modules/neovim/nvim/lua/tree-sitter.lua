require("nvim-ts-autotag").setup()
require("nvim-treesitter.configs").setup({

	sync_install = false,

	auto_install = false,

	ignore_install = { "all" },

	highlight = {
		enable = true,

		additional_vim_regex_highlighting = false,
	},

	indent = { enable = true },

	textobjects = {
		select = {
			enable = true,
			lookahead = true,
			keymaps = {
				["af"] = "@function.outer",
				["if"] = "@function.inner",
				["ac"] = "@class.outer",
				["ic"] = "@class.inner",
				["aa"] = "@parameter.outer",
				["ia"] = "@parameter.inner",
			},
		},
		move = {
			enable = true,
			set_jumps = true,
			-- ]]/[[ for classes, not ]c/[c — gitsigns owns those for hunk
			-- navigation in lua/git.lua and loads after this file.
			goto_next_start = { ["]f"] = "@function.outer", ["]]"] = "@class.outer" },
			goto_previous_start = { ["[f"] = "@function.outer", ["[["] = "@class.outer" },
		},
	},
})

require("ibl").setup({
	scope = { enabled = true },
})
