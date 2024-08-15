return {
  {
	  'nvim-telescope/telescope.nvim', tag = '0.1.8',
	  -- or                            , branch = '0.1.x',
	  requires = { {'nvim-lua/plenary.nvim'} }
  },
  {
	  'rose-pine/neovim',
	  as = 'rose-pine',
	  config = function()
		  vim.cmd('colorscheme rose-pine')
	  end
  },
  { 'nvim-treesitter/nvim-treesitter', build = ':TSUpdate' },
  'nvim-treesitter/playground',
  --use("nvim-lua/plenary.nvim") -- don't forget to add this one if you don't have it yet!
  --use({
  --    "ThePrimeagen/harpoon",
  --    branch = "harpoon2",
  --    requires = { {"nvim-lua/plenary.nvim"} }
  --})
  'ThePrimeagen/harpoon',
  'mbbill/undotree',
  'tpope/vim-fugitive',
  {'VonHeikemen/lsp-zero.nvim', branch = 'v4.x'},
  {'neovim/nvim-lspconfig'},
  {'hrsh7th/cmp-nvim-lsp'},
  {'hrsh7th/nvim-cmp'},
--  {
--	  'VonHeikemen/lsp-zero.nvim',
--	  branch = 'v3.x',
--	  requires = {
--		  --- Uncomment the two plugins below if you want to manage the language servers from neovim
--		  {'williamboman/mason.nvim'},
--		  {'williamboman/mason-lspconfig.nvim'},
--		  {'neovim/nvim-lspconfig'},
--		  {'hrsh7th/nvim-cmp'},
--		  {'hrsh7th/cmp-nvim-lsp'},
--		  {'L3MON4D3/LuaSnip'},
--	  }
--  },
  "Olical/nfnl"
}
