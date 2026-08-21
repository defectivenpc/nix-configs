local conform = require("conform")

-- Parsed `includes` globs per treefmt config, so the condition below costs a
-- table lookup rather than a file read on every save. Keyed by config path and
-- invalidated on mtime, so editing a treefmt.toml takes effect immediately.
local treefmt_cache = {}

local function treefmt_includes(config)
	local stat = vim.uv.fs_stat(config)
	local mtime = stat and stat.mtime.sec or 0

	local cached = treefmt_cache[config]
	if cached and cached.mtime == mtime then
		return cached.globs
	end

	local globs = {}
	local ok, lines = pcall(vim.fn.readfile, config)
	if ok then
		-- Strip comments first, then pull every quoted entry out of each
		-- `includes = [...]`. Those arrays routinely span lines, so scan the
		-- joined text rather than line by line.
		local text = table.concat(lines, "\n"):gsub("#[^\n]*", "")
		for body in text:gmatch("includes%s*=%s*%[(.-)%]") do
			for glob in body:gmatch('"([^"]*)"') do
				table.insert(globs, glob)
			end
		end
	end

	treefmt_cache[config] = { mtime = mtime, globs = globs }
	return globs
end

-- Locates the treefmt config governing `dirname` and the tree root paths are
-- resolved against. Mirrors treefmt's own rule for the latter: the git worktree
-- root when there is one, otherwise the directory holding the config.
local function treefmt_tree(dirname)
	local config = vim.fs.find({ "treefmt.toml", ".treefmt.toml" }, { upward = true, path = dirname })[1]
	if not config then
		return nil
	end

	local git = vim.fs.find(".git", { upward = true, path = dirname })[1]
	return { config = config, root = git and vim.fs.dirname(git) or vim.fs.dirname(config) }
end

-- Path treefmt should be handed for this buffer: relative to the tree root, and
-- never absolute. See the `args` comment below for why that distinction is load
-- bearing.
local function treefmt_relpath(tree, filename)
	return vim.fs.relpath(tree.root, filename) or vim.fs.basename(filename)
end

conform.setup({
	formatters = {
		-- Defers to the repo's treefmt.toml so format-on-save and a CLI
		-- `treefmt` run can never disagree. The condition matters: most
		-- projects have no treefmt.toml, and treefmt errors out rather than
		-- passing the buffer through, so without it saving would break
		-- everywhere outside a treefmt tree.
		treefmt = {
			command = "treefmt",
			-- `--stdin` matches its `excludes` against the path as written, so
			-- it only honours them for a tree-root-relative one. Handed the
			-- absolute path conform's `$FILENAME` expands to, it formats
			-- excluded files anyway -- which for this repo meant saving a
			-- sops-encrypted nixos/secrets/*.yaml ran prettier over it and put
			-- the integrity MAC at risk. Hence the explicit relative path,
			-- paired with the matching `cwd` below.
			args = function(_, ctx)
				local tree = treefmt_tree(ctx.dirname)
				return { "--stdin", tree and treefmt_relpath(tree, ctx.filename) or ctx.filename }
			end,
			cwd = function(_, ctx)
				local tree = treefmt_tree(ctx.dirname)
				return tree and tree.root
			end,
			stdin = true,
			-- Existence of a treefmt.toml is not enough: if it configures no
			-- formatter for this file, treefmt exits 0 having echoed the buffer
			-- back untouched, and `stop_after_first` then swallows the
			-- standalone fallback -- the save looks fine but nothing was
			-- formatted. So only claim the file when an `includes` glob
			-- actually covers it.
			--
			-- `excludes` is deliberately not consulted here. A file the repo
			-- excludes is one it wants left alone, so letting treefmt take it
			-- and pass it through unchanged is the point; falling back to
			-- prettier instead would be exactly wrong.
			condition = function(_, ctx)
				local tree = treefmt_tree(ctx.dirname)
				if not tree then
					return false
				end

				-- treefmt's globs are not path-separator aware -- `*.md` covers
				-- nested files too -- so matching the same relative path it
				-- will see is enough to predict whether it claims the file.
				local rel = treefmt_relpath(tree, ctx.filename)
				for _, glob in ipairs(treefmt_includes(tree.config)) do
					if vim.regex(vim.fn.glob2regpat(glob)):match_str(rel) then
						return true
					end
				end
				return false
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
