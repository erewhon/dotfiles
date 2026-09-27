-- ~/.config/mdview/init.lua
-- A read-only markdown viewer. No LSP, no linters, no completion.
-- Launch with:  NVIM_APPNAME=mdview nvim -R file.md      (alias: md)
--         or:  NVIM_APPNAME=mdview neovide file.md -- -R (function: mdv)

--------------------------------------------------------------------
-- appearance
--------------------------------------------------------------------
vim.o.number, vim.o.relativenumber = false, false
vim.o.signcolumn = "yes:3" -- 6 blank columns of left margin
vim.o.laststatus = 0
vim.o.ruler = false
vim.o.showcmd = false
vim.o.cmdheight = 0
vim.o.fillchars = "eob: ,fold: "
-- margin comes from an empty signcolumn rather than foldcolumn, so fold
-- indicators don't clutter it. Swap to foldcolumn = "6" (and signcolumn
-- = "no") if you'd rather have clickable +/- markers in the gutter.
vim.o.foldcolumn = "0"
vim.o.termguicolors = true

-- Neovide only (the `mdv` function). A terminal ignores guifont.
if vim.g.neovide then
	vim.o.guifont = "JetBrainsMono Nerd Font Mono:h12"
end

-- wrapping
vim.o.wrap = true
vim.o.linebreak = true
vim.o.breakindent = true
vim.o.conceallevel, vim.o.concealcursor = 2, "nvic"
vim.o.mouse = "a"

if vim.fn.has("nvim-0.10") == 1 then
	vim.diagnostic.enable(false)
else
	vim.diagnostic.disable()
end

-- folding by section
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.require'mdview'.foldexpr()"
vim.o.foldtext = "v:lua.require'mdview'.foldtext()"
vim.o.foldenable = true
vim.o.foldlevel = 99 -- everything open on load
vim.o.foldlevelstart = 99

-- keeps the file picker out of dependency and VCS directories
vim.opt.wildignore:append({
	"*/node_modules/*",
	"*/.git/*",
	"*/target/*",
	"*/dist/*",
	"*/.venv/*",
	"*/venv/*",
	"*/vendor/*",
	"*/build/*",
})

--------------------------------------------------------------------
-- colorscheme
--------------------------------------------------------------------
pcall(function()
	require("catppuccin").setup({
		flavour = "mocha",
		-- transparent_background = true,  -- uncomment if your terminal has a nice bg
		integrations = { treesitter = true, markdown = true },
	})
	vim.cmd.colorscheme("catppuccin-mocha")
end)

--------------------------------------------------------------------
-- rendering
--------------------------------------------------------------------
pcall(function()
	require("render-markdown").setup({
		anti_conceal = { enabled = false }, -- never un-render the cursor line
		win_options = { showbreak = { default = "", rendered = "" } },
	})
end)

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "markdown", "md" },
	callback = function(a)
		pcall(vim.treesitter.start)
		vim.bo[a.buf].modifiable = false
	end,
})

--------------------------------------------------------------------
-- keys
--------------------------------------------------------------------
local mdview = require("mdview")

local map = function(lhs, rhs, desc)
	vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
end

map("q", "<cmd>qa!<cr>", "quit")
map("<Space>", "<C-d>", "page down")
map("b", "<C-u>", "page up")

map("T", mdview.toc, "toggle table of contents")
map("F", mdview.files, "browse markdown files")
map("Z", mdview.zen, "toggle zen mode")
map("D", function()
	mdview.dim()
end, "toggle dimming")
map("<Tab>", mdview.fold_toggle, "fold/unfold this section")
map("<S-Tab>", mdview.fold_all, "collapse/expand everything")

--------------------------------------------------------------------
-- commands
--------------------------------------------------------------------
vim.api.nvim_create_user_command("Toc", mdview.toc, {})
vim.api.nvim_create_user_command("Docs", function(o)
	mdview.files(o.args)
end, { nargs = "?", complete = "dir" })
vim.api.nvim_create_user_command("Zen", function(o)
	mdview.zen(tonumber(o.args))
end, { nargs = "?" })
vim.api.nvim_create_user_command("Dim", function()
	mdview.dim()
end, {})

-- dimming and the follow highlight both track the colorscheme; override with e.g.
--   vim.api.nvim_set_hl(0, "MdviewDim", { fg = "#585b70" })          -- surface2
--   vim.api.nvim_set_hl(0, "MdviewTocCurrent", { fg = "#f9e2af" })   -- yellow
