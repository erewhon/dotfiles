-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Only show diagnostic virtual lines on the current line, dimmed
vim.diagnostic.config({
	virtual_text = false,
	virtual_lines = { current_line = true },
})

local dim = "#3a3530"
vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesWarn", { fg = dim })
vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesHint", { fg = dim })
vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesInfo", { fg = dim })
vim.api.nvim_set_hl(0, "DiagnosticWarn", { fg = dim })
vim.api.nvim_set_hl(0, "DiagnosticHint", { fg = dim })
vim.api.nvim_set_hl(0, "DiagnosticInfo", { fg = dim })
