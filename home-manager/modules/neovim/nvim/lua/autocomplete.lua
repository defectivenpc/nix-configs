local lspkind = require("lspkind")

local cmp = require("cmp")
cmp.setup({
	snippet = {
		expand = function(args)
			require("luasnip").lsp_expand(args.body)
		end,
	},

	completion = {
		autocomplete = { cmp.TriggerEvent.TextChanged },
		completeopt = "menu,menuone,noinsert",
	},

	mapping = cmp.mapping.preset.insert({
		-- Navigate
		["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
		["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),

		-- Accept (fast, no Enter hijack)
		["<C-y>"] = cmp.mapping.confirm({ select = true }),

		["<C-x><C-o>"] = cmp.mapping.complete(),

		-- Cancel
		["<C-e>"] = cmp.mapping.abort(),

		-- Scroll docs
		["<C-d>"] = cmp.mapping.scroll_docs(4),
		["<C-u>"] = cmp.mapping.scroll_docs(-4),

		-- Optional: keep Enter clean
		["<CR>"] = cmp.mapping({
			i = function(fallback)
				if cmp.visible() then
					cmp.confirm({ select = true })
				else
					fallback()
				end
			end,
		}),
	}),

	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "luasnip" },
		{ name = "buffer" },
		{ name = "orgmode" },
	}),

	formatting = {
		format = lspkind.cmp_format({
			maxwidth = 50,
			elispis_char = "...",
		}),
	},
})

cmp.setup.cmdline("/", {
	sources = {
		{ name = "buffer" },
	},
})

cmp.setup.cmdline(":", {
	sources = cmp.config.sources({
		{ name = "path" },
	}, {
		{ name = "cmdline" },
	}),
})

-- Setup lspconfig.
--local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())
-- Replace <YOUR_LSP_SERVER> with each lsp server you've enabled.
--require('lspconfig')['<YOUR_LSP_SERVER>'].setup {
--capabilities = capabilities
--}
