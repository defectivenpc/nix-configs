require("oil").setup({
	default_file_explorer = true,
	delete_to_trash = true,
	skip_confirm_for_simple_edits = true,
	view_options = {
		show_hidden = true,
		natural_order = true,
		is_always_hidden = function(name, _)
			return name == ".." or name == ".git"
		end,
	},
	float = {
		padding = 2,
		max_width = 90,
		max_height = 0,
	},
	win_options = {
		wrap = true,
		winblend = 0,
	},
	keymaps = {
		["<C-c>"] = false,
		["q"] = "actions.close",
		["<C-o>s"] = { "actions.select", opts = { vertical = true }, desc = "Open the entry in a vertical split" },
		["<C-o>h"] = { "actions.select", opts = { horizontal = true }, desc = "Open the entry in a horizontal split" },
		["<C-o>r"] = "actions.refresh",
		["g?"] = { "actions.show_help", mode = "n" },
		["<CR>"] = "actions.select",
		["<C-t>"] = { "actions.select", opts = { tab = true } },
		["<C-p>"] = "actions.preview",
		["-"] = { "actions.parent", mode = "n" },
		["_"] = { "actions.open_cwd", mode = "n" },
		["`"] = { "actions.cd", mode = "n" },
		["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
		["gs"] = { "actions.change_sort", mode = "n" },
		["gx"] = "actions.open_external",
		["g."] = { "actions.toggle_hidden", mode = "n" },
		["g\\"] = { "actions.toggle_trash", mode = "n" },
	},
	use_default_keymaps = false,
})

local tree_api = require("nvim-tree")
local tree_view = require("nvim-tree.view")

local HEIGHT_RATIO = 0.8
local WIDTH_RATIO = 0.5

local function natural_cmp(left, right)
	left = left.name:lower()
	right = right.name:lower()

	if left == right then
		return false
	end

	for i = 1, math.max(string.len(left), string.len(right)), 1 do
		local l = string.sub(left, i, -1)
		local r = string.sub(right, i, -1)

		if type(tonumber(string.sub(l, 1, 1))) == "number" and type(tonumber(string.sub(r, 1, 1))) == "number" then
			local l_number = tonumber(string.match(l, "^[0-9]+"))
			local r_number = tonumber(string.match(r, "^[0-9]+"))

			if l_number ~= r_number then
				return l_number < r_number
			end
		elseif string.sub(l, 1, 1) ~= string.sub(r, 1, 1) then
			return l < r
		end
	end
end

tree_api.setup({
	sort_by = function(nodes)
		table.sort(nodes, natural_cmp)
	end,

	view = {
		float = {
			enable = true,
			open_win_config = function()
				local screen_w = vim.opt.columns:get()
				local screen_h = vim.opt.lines:get() - vim.opt.cmdheight:get()
				local window_w = screen_w * WIDTH_RATIO
				local window_h = screen_h * HEIGHT_RATIO
				local window_w_int = math.floor(window_w)
				local window_h_int = math.floor(window_h)
				local center_x = (screen_w - window_w) / 2
				local center_y = ((vim.opt.lines:get() - window_h) / 2) - vim.opt.cmdheight:get()
				return {
					border = "rounded",
					relative = "editor",
					row = center_y,
					col = center_x,
					width = window_w_int,
					height = window_h_int,
				}
			end,
		},
		width = function()
			return math.floor(vim.opt.columns:get() * WIDTH_RATIO)
		end,
	},
	update_focused_file = {
		enable = true,
		update_root = false, -- keep project root stable
	},
	respect_buf_cwd = true,
})

vim.api.nvim_create_augroup("NvimTreeResize", {
	clear = true,
})

vim.api.nvim_create_autocmd({ "VimResized" }, {
	group = "NvimTreeResize",
	callback = function()
		if tree_view.is_visible() then
			tree_view.close()
			tree_api.open()
		end
	end,
})
