-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Dim diagnostic virtual lines highlights
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = function()
		local dim = "#3a3530"
		vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesWarn", { fg = dim })
		vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesHint", { fg = dim })
		vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesInfo", { fg = dim })
	end,
})
local dim = "#3a3530"
vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesWarn", { fg = dim })
vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesHint", { fg = dim })
vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesInfo", { fg = dim })
