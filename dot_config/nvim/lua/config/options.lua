-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- No format-on-save. Format by hand with <leader>cf.
vim.g.autoformat = false

-- Clipboard over SSH, tmux and herdr (from Omarchy): copies go to the local
-- Wayland clipboard and, through OSC 52, to the terminal you are attached
-- from. Linux only: on macOS the system clipboard already works inside tmux.
if vim.uv.os_uname().sysname == "Linux" then
	require("config.remote_clipboard").setup()
end
