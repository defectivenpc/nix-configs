local conform = require("conform")

conform.setup({
	formatters = {
		-- Defers to the repo's treefmt.toml so format-on-save and a CLI
		-- `treefmt` run can never disagree. The condition matters: most
		-- projects have no treefmt.toml, and treefmt errors out rather than
		-- passing the buffer through, so without it saving would break
		-- everywhere outside a treefmt tree.
		treefmt = {
			command = "treefmt",
			args = { "--stdin", "$FILENAME" },
			stdin = true,
			condition = function(_, ctx)
				return vim.fs.find("treefmt.toml", { upward = true, path = ctx.dirname })[1] ~= nil
			end,
		},
	},

	-- treefmt first, the standalone tool as fallback. stop_after_first means
	-- the fallback only runs when the treefmt condition above is false.
	formatters_by_ft = {
		lua = { "treefmt", "stylua", stop_after_first = true },
		nix = { "treefmt", "nixfmt", stop_after_first = true },
		toml = { "treefmt", "taplo", stop_after_first = true },
		sh = { "treefmt", "shfmt", stop_after_first = true },
		bash = { "treefmt", "shfmt", stop_after_first = true },
		json = { "treefmt", "prettierd", "prettier", stop_after_first = true },
		yaml = { "treefmt", "prettierd", "prettier", stop_after_first = true },
		markdown = { "treefmt", "prettierd", "prettier", stop_after_first = true },
		css = { "treefmt", "prettierd", "prettier", stop_after_first = true },

		-- Not covered by treefmt.toml; these run the tool directly.
		python = { "isort", "black" },
		rust = { "rustfmt", lsp_format = "fallback" },
		javascript = { "prettierd", "prettier", stop_after_first = true },
		typescript = { "prettierd", "prettier", stop_after_first = true },
		javascriptreact = { "prettierd", "prettier", stop_after_first = true },
		typescriptreact = { "prettierd", "prettier", stop_after_first = true },
		scss = { "prettierd", "prettier", stop_after_first = true },
		html = { "htmlbeautifier" },
	},

	format_on_save = {
		-- Raised from 500ms: treefmt is an extra process spawn on top of the
		-- underlying formatter, and 500 was tight enough to drop saves.
		timeout_ms = 1500,
		lsp_format = "fallback",
	},
})
