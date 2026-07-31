require("gitsigns").setup({
	on_attach = function(bufnr)
		local gitsigns = require("gitsigns")

		local function map(mode, l, r, opts)
			opts = opts or {}
			opts.buffer = bufnr
			vim.keymap.set(mode, l, r, opts)
		end

		-- Navigation
		map("n", "]c", function()
			if vim.wo.diff then
				vim.cmd.normal({ "]c", bang = true })
			else
				gitsigns.nav_hunk("next")
			end
		end)

		map("n", "[c", function()
			if vim.wo.diff then
				vim.cmd.normal({ "[c", bang = true })
			else
				gitsigns.nav_hunk("prev")
			end
		end)

		-- Actions
		map("n", "<leader>hs", gitsigns.stage_hunk, { desc = "stage hunk" })
		map("n", "<leader>hr", gitsigns.reset_hunk, { desc = "reset hunk" })
		map("v", "<leader>hs", function()
			gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, { desc = "stage hunk" })
		map("v", "<leader>hr", function()
			gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, { desc = "reset hunk" })
		map("n", "<leader>hS", gitsigns.stage_buffer, { desc = "stage buffer" })
		map("n", "<leader>hu", gitsigns.undo_stage_hunk, { desc = "undo stage" })
		map("n", "<leader>hR", gitsigns.reset_buffer, { desc = "reset buffer" })
		map("n", "<leader>hp", gitsigns.preview_hunk, { desc = "preview hunk" })
		map("n", "<leader>hb", function()
			gitsigns.blame_line({ full = true })
		end, { desc = "blame line" })
		map("n", "<leader>tb", gitsigns.toggle_current_line_blame, { desc = "toggle blame line" })
		map("n", "<leader>hd", gitsigns.diffthis, { desc = "diff this" })
		map("n", "<leader>hD", function()
			gitsigns.diffthis("~")
		end, { desc = "diff all" })
		map("n", "<leader>td", gitsigns.toggle_deleted, { desc = "toggle deleted" })

		-- Text object
		map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>")
	end,
})

vim.keymap.set("n", "<leader>lg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })

-- GIT LINKER

local gitlinker = require("gitlinker")

-- Copy link for current line
vim.keymap.set("n", "<leader>gy", function()
	gitlinker.get_buf_range_url("n", { action_callback = gitlinker.actions.copy_to_clipboard })
end, { desc = "Copy Git link (line)" })

-- Copy link for visual selection (line range)
vim.keymap.set("v", "<leader>gy", function()
	gitlinker.get_buf_range_url("v", { action_callback = gitlinker.actions.copy_to_clipboard })
end, { desc = "Copy Git link (range)" })

-- GITLAB
local init = vim.api.nvim_get_runtime_file("lua/gitlab/init.lua", false)[1]
if not init then
	error("gitlab.nvim: couldn't locate lua/gitlab/init.lua on runtimepath")
end

local state = require("gitlab.state")

local root = vim.fn.fnamemodify(init, ":h:h:h")
state.settings.root_path = root

-- OVERWRITE binary settings for gitlab nvim
local ok, server = pcall(require, "gitlab.server")
if ok then
	server.build = function(_)
		return true
	end

	state.settings.bin = vim.fn.exepath("gitlab-nvim-server")
end

require("diffview")

-- setup() calls health.check(), whose check_go_version() does
-- io.popen("go version") to validate the toolchain it would need to BUILD the
-- server. We ship a prebuilt one (gitlabNvimBin in neovim.nix) and stub
-- server.build above, so Go is genuinely not needed here — but the check still
-- ran on every startup and printed "sh: line 1: go: command not found".
--
-- check_go_version is a local, so it can't be replaced directly; health.check
-- is on the module table. Swap it out for the setup() call only and restore it
-- afterwards, so `:checkhealth gitlab` still reports the real state.
local health_ok, health = pcall(require, "gitlab.health")
local original_check
if health_ok then
	original_check = health.check
	health.check = function()
		return true
	end
end

require("gitlab").setup()

if health_ok and original_check then
	health.check = original_check
end
