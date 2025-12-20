require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "isort", "black" },
		rust = { "rustfmt", lsp_format = "fallback" },
		javascript = { "prettierd", "prettier", stop_after_first = true },
		typescript = { "prettierd", "prettier", stop_after_first = true },
		javascriptreact = { "prettierd", "prettier" },
		typescriptreact = { "prettierd", "prettier" },
		json = { "prettierd", "prettier" },
		markdown = { "prettierd", "prettier" },
		css = { "prettierd", "prettier" },
		scss = { "prettierd", "prettier" },
		html = { "htmlbeautifier" },
		toml = { "taplo" },
		nix = { "nixfmt" },
	},
	format_on_save = {
		timeout_ms = 500,
		lsp_format = "fallback",
	},
})
