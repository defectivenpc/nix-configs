vim.o.termguicolors = true

vim.cmd.colorscheme("gruvbox")

if vim.fn.has("mac") == 1 then
else
	local handle = io.popen(
		"dbus-send --session --print-reply=literal --dest=org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.portal.Settings.Read string:'org.freedesktop.appearance' string:'color-scheme' 2>/dev/null"
	)
	if handle then
		local result = handle:read("*a")
		handle:close()
		-- color-scheme: 0=default, 1=dark, 2=light
		if result:match("uint32 1") then
			vim.o.background = "dark"
		else
			vim.o.background = "light"
		end
	else
		vim.o.background = "dark"
	end
end

require("global")
require("tree-sitter")
require("directory")
require("fuzzy-search")
require("autocomplete")
require("autopairs")
require("comments")
require("remaps")
require("surround")
require("subst")
require("motions")
require("search-replace")
require("sessions")
require("lsp")
require("formatter")
require("git")
require("nix-tools")
require("markdown")
require("avante-cfg")
require("phox")
