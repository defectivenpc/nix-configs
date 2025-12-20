-- ============================================================
-- glab (GitLab CLI) integration for Neovim
-- - MR management from inside editor
-- - Works great with self-managed GitLab (glab auth handles that)
--
-- Requirements:
--   - glab installed and authenticated:
--       glab auth login --hostname gitlab.yourcompany.net
-- Optional:
--   - a terminal plugin (toggleterm) for nicer UX; this config works without it.
-- ============================================================

local M = {}

-- ---------- helpers ----------

local function has_exe(cmd)
	return vim.fn.executable(cmd) == 1
end

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "glab" })
end

-- Run a shell command and return { code, stdout_lines, stderr_lines }
local function system_capture(cmd)
	-- NOTE: cmd is a string, executed by /bin/sh -c
	local out = vim.fn.systemlist(cmd)
	local code = vim.v.shell_error
	return code, out
end

-- Small helper: get current branch name
local function current_branch()
	local code, out = system_capture("git rev-parse --abbrev-ref HEAD 2>/dev/null")
	if code ~= 0 or not out[1] then
		return nil
	end
	return out[1]
end

-- Try to infer MR number for the current branch (fast, no UI).
-- If it fails, returns nil and user can fall back to `glab mr view` etc.
local function current_mr_iid()
	local branch = current_branch()
	if not branch then
		return nil
	end

	-- List MRs where source branch matches; prefer opened.
	-- `--json iid` output is machine-friendly (glab supports --json on many commands).
	local cmd = ("glab mr list --state opened --source-branch %q --json iid 2>/dev/null"):format(branch)
	local code, out = system_capture(cmd)
	if code ~= 0 or not out[1] then
		return nil
	end

	-- out is JSON string(s). Parse the first line as JSON.
	local ok, decoded = pcall(vim.json.decode, table.concat(out, "\n"))
	if not ok or type(decoded) ~= "table" then
		return nil
	end
	if decoded[1] and decoded[1].iid then
		return tostring(decoded[1].iid)
	end
	return nil
end

-- Open a scratch buffer and render command output
local function open_output(title, lines)
	vim.cmd("botright new")
	local bufnr = vim.api.nvim_get_current_buf()
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].filetype = "markdown"
	vim.api.nvim_buf_set_name(bufnr, title)
end

-- Run glab and show output. If cmd is interactive, prefer terminal mode below.
local function glab_capture(args)
	local cmd = "glab " .. args
	local code, out = system_capture(cmd .. " 2>&1")
	if code ~= 0 then
		notify(("Command failed: %s"):format(cmd), vim.log.levels.ERROR)
	end
	open_output(("glab: %s"):format(args), out)
end

-- Open an interactive terminal running `glab ...`
-- Uses built-in terminal, no plugin required.
local function glab_term(args)
	vim.cmd("botright split | resize 15")
	vim.fn.termopen("glab " .. args)
	vim.cmd("startinsert")
end

-- If you have toggleterm.nvim, you can swap glab_term implementation
-- to use it; keeping built-in terminal keeps this portable.

-- ---------- commands ----------

-- View MR details in a scratch buffer (non-interactive)
function M.mr_view()
	-- `glab mr view` often auto-detects the MR for current branch if one exists.
	-- We still try to infer IID to be more deterministic.
	local iid = current_mr_iid()
	if iid then
		glab_capture(("mr view %s"):format(iid))
	else
		glab_capture("mr view")
	end
end

-- Open MR in browser (interactive-ish but output minimal)
function M.mr_web()
	local iid = current_mr_iid()
	if iid then
		glab_capture(("mr view %s --web"):format(iid))
	else
		glab_capture("mr view --web")
	end
end

-- Approve MR
function M.mr_approve()
	local iid = current_mr_iid()
	if iid then
		glab_capture(("mr approve %s"):format(iid))
	else
		-- Works if glab can infer from branch; otherwise it will ask/err.
		glab_capture("mr approve")
	end
end

-- Unapprove (revoke approval) if supported by your glab version.
function M.mr_unapprove()
	local iid = current_mr_iid()
	if iid then
		glab_capture(("mr unapprove %s"):format(iid))
	else
		glab_capture("mr unapprove")
	end
end

-- Add a note/comment (general MR note, not inline)
function M.mr_note()
	local iid = current_mr_iid()
	local prompt = "MR comment: "
	vim.ui.input({ prompt = prompt }, function(input)
		if not input or input == "" then
			return
		end
		local msg = vim.fn.shellescape(input)
		if iid then
			glab_capture(("mr note %s --message %s"):format(iid, msg))
		else
			glab_capture(("mr note --message %s"):format(msg))
		end
	end)
end

-- Create MR (interactive, uses terminal)
function M.mr_create()
	glab_term("mr create")
end

-- Merge MR (interactive-ish; terminal because it may prompt)
function M.mr_merge()
	local iid = current_mr_iid()
	if iid then
		glab_term(("mr merge %s"):format(iid))
	else
		glab_term("mr merge")
	end
end

-- List MRs (handy quick picker target)
function M.mr_list()
	glab_capture("mr list")
end

-- Pipeline status (useful pre-merge)
function M.ci_status()
	glab_capture("ci status")
end

-- ---------- keymaps ----------

function M.setup_keymaps(opts)
	opts = opts or {}
	local prefix = opts.prefix or "<leader>m"

	local map = function(lhs, rhs, desc)
		vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true })
	end

	map(prefix .. "v", M.mr_view, "GitLab: MR view (current branch)")
	map(prefix .. "o", M.mr_web, "GitLab: MR open in browser")
	map(prefix .. "a", M.mr_approve, "GitLab: MR approve")
	map(prefix .. "u", M.mr_unapprove, "GitLab: MR unapprove")
	map(prefix .. "n", M.mr_note, "GitLab: MR comment (note)")
	map(prefix .. "c", M.mr_create, "GitLab: MR create (interactive)")
	map(prefix .. "m", M.mr_merge, "GitLab: MR merge (interactive)")
	map(prefix .. "l", M.mr_list, "GitLab: MR list")
	map(prefix .. "s", M.ci_status, "GitLab: CI status")
end

-- ---------- public setup ----------

function M.setup(opts)
	if not has_exe("glab") then
		notify("glab not found in PATH. Install glab to use GitLab MR commands.", vim.log.levels.WARN)
		return
	end

	M.setup_keymaps(opts)
end

return M
