-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Override LazyVim's diagnostic config: disable persistent virtual text,
-- only show virtual lines on the current line, dimmed
vim.diagnostic.config({
	virtual_text = false,
	virtual_lines = { current_line = true },
})

vim.api.nvim_create_autocmd("ColorScheme", {
	callback = function()
		local dim = "#3a3530"
		vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesWarn", { fg = dim })
		vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesHint", { fg = dim })
		vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesInfo", { fg = dim })
	end,
})
-- Trigger immediately for the current colorscheme
local dim = "#3a3530"
vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesWarn", { fg = dim })
vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesHint", { fg = dim })
vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesInfo", { fg = dim })
