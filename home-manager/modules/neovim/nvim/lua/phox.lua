-- Phox: load plugin + tree-sitter parser from dev shell
local phox_nvim = vim.env.PHOX_NVIM
local phox_parser = vim.env.PHOX_PARSER
if phox_nvim then
	vim.opt.rtp:prepend(phox_nvim)
end
if phox_parser then
	vim.opt.rtp:prepend(phox_parser)
end
