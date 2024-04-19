require("utils/mappings")

vim.wo.relativenumber = true
vim.cmd("set nu rnu")
vim.cmd("set nowrap")
vim.cmd("set clipboard=unnamedplus")
vim.cmd("set shiftwidth=2")
vim.cmd("set tabstop=2")

vim.fn.sign_define(
	"DiagnosticSignError",
	{text = " ", texthl = "DiagnosticSignError"}
)
vim.fn.sign_define(
	"DiagnosticSignWarn",
	{text = " ", texthl = "DiagnosticSignWarn"}
)
vim.fn.sign_define(
	"DiagnosticSignInfo",
	{text = " ", texthl = "DiagnosticSignInfo"}
)
vim.fn.sign_define(
	"DiagnosticSignHint",
	{text = "󰌵", texthl = "DiagnosticSignHint"}
)


local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)


require("lazy").setup({
	{"rebelot/kanagawa.nvim"},
	{"nvim-treesitter/nvim-treesitter"},
	{"nvim-lua/lsp-status.nvim"},
  {"nvim-tree/nvim-web-devicons"},
	{'akinsho/bufferline.nvim', version = "*", dependencies = 'nvim-tree/nvim-web-devicons'},
	{
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
      "MunifTanjim/nui.nvim",
      "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
      {
        's1n7ax/nvim-window-picker',
        version = '2.*',
        config = function()
            require 'window-picker'.setup({
                filter_rules = {
                    include_current_win = false,
                    autoselect_one = true,
                    -- filter using buffer options
                    bo = {
                        -- if the file type is one of following, the window will be ignored
                        filetype = { 'neo-tree', "neo-tree-popup", "notify" },
                        -- if the buffer type is one of following, the window will be ignored
                        buftype = { 'terminal', "quickfix" },
                    },
            },
        })
			end,
      },
    },

		config = require "plugins.neo-tree"
  },
	{'akinsho/toggleterm.nvim', version = "*", config = true},
	{
		'nvim-telescope/telescope.nvim', tag = '0.1.6',
		dependencies = { 'nvim-lua/plenary.nvim' }
	},
	{ 'mrjones2014/smart-splits.nvim' },
	{
        'neovim/nvim-lspconfig',
        event = { 'BufReadPre', 'BufReadPost', 'BufNewFile' },
        dependencies = {
            { 'folke/neodev.nvim', opts = {} },
        }
  },
	{
        'williamboman/mason.nvim',
        build = ':MasonUpdate',
        cmd = 'Mason'
  },
	{ "williamboman/mason-lspconfig.nvim" },
	{
		'hrsh7th/nvim-cmp',
		event = 'InsertEnter',
		dependencies = {
				'hrsh7th/cmp-cmdline',
				'hrsh7th/cmp-nvim-lsp',
				'hrsh7th/cmp-buffer',
				'saadparwaiz1/cmp_luasnip',
				'ray-x/cmp-treesitter',
				'hrsh7th/cmp-nvim-lsp-signature-help',
				'hrsh7th/cmp-nvim-lua',
				'f3fora/cmp-spell',
				'hrsh7th/cmp-path',
				'fazibear/cmp-nerdfonts',
				'octaltree/cmp-look',
		}
  },	
	{
    "jose-elias-alvarez/null-ls.nvim",
    dependencies = {
      {
        "jay-babu/mason-null-ls.nvim",
        cmd = { "NullLsInstall", "NullLsUninstall" },
        opts = { handlers = {} },
      },
    },
  },
 --[[ 
	{ 'Sirver/ultisnips', event = { 'InsertEnter' } },	
	{
		"rebelot/heirline.nvim",
		config = function()
		require("heirline").setup({})
		end
	},
	
	]]--
})

vim.cmd("colorscheme kanagawa")
vim.opt.termguicolors = true
require("bufferline").setup{}
require("plugins/smartsplits")
require("plugins/toggleterm")
require("utils/lazygit")
require("plugins/telescope")
require("plugins/mason")
require("plugins/mason-lspconfig")
require("plugins/lspconfig")
--[[


require("plugins/heirline")

]]--
