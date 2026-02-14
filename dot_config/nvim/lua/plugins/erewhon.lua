return {
	{
		"nvim-orgmode/orgmode",
		event = "VeryLazy",
		ft = { "org" },
		config = function()
			require("orgmode").setup({
				org_agenda_files = "~/orgfiles/**/*",
				org_default_notes_file = "~/orgfiles/refile.org",
			})
		end,
	},

	-- Rainbow-colored matching brackets/parens
	{
		"HiPhish/rainbow-delimiters.nvim",
		event = "BufReadPost",
	},

	-- LSP progress spinners
	{
		"j-hui/fidget.nvim",
		event = "LspAttach",
		opts = {},
	},

	-- Make your code dissolve (Game of Life) or rain down
	{
		"Eandrju/cellular-automaton.nvim",
		keys = {
			{ "<leader>fml", "<cmd>CellularAutomaton make_it_rain<CR>", desc = "Make it rain" },
			{ "<leader>gol", "<cmd>CellularAutomaton game_of_life<CR>", desc = "Game of Life" },
		},
	},

	-- Inline color previews for hex codes, CSS, etc.
	{
		"NvChad/nvim-colorizer.lua",
		event = "BufReadPost",
		opts = {
			user_default_options = {
				names = false,
				css = true,
				tailwind = true,
			},
		},
	},

	-- Cursorline/signcolumn changes color based on mode
	{
		"rasulomaroff/reactive.nvim",
		event = "VeryLazy",
		opts = {
			load = { "catppuccin-mocha-cursor", "catppuccin-mocha-cursorline" },
		},
	},

	-- Dim inactive code blocks
	{
		"folke/twilight.nvim",
		cmd = { "Twilight", "TwilightEnable" },
		opts = {},
	},

	-- Distraction-free coding mode
	{
		"folke/zen-mode.nvim",
		cmd = "ZenMode",
		keys = {
			{ "<leader>z", "<cmd>ZenMode<CR>", desc = "Zen Mode" },
		},
		opts = {
			plugins = {
				twilight = { enabled = true },
			},
		},
	},

	-- Scrollbar with diagnostic/git/search markers
	{
		"lewis6991/satellite.nvim",
		event = "BufReadPost",
		opts = {},
	},
}
