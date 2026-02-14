-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Dim diagnostic virtual text and only show on the current line
vim.diagnostic.config({
	virtual_text = false,
	virtual_lines = { current_line = true },
})

vim.api.nvim_set_hl(0, "DiagnosticVirtualTextWarn", { fg = "#5a524c" })
vim.api.nvim_set_hl(0, "DiagnosticVirtualTextHint", { fg = "#5a524c" })
vim.api.nvim_set_hl(0, "DiagnosticVirtualTextInfo", { fg = "#5a524c" })
