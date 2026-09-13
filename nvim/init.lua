require("utils/mappings")

-- Disable netrw (use neo-tree instead)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.exrc = true

vim.wo.relativenumber = true
vim.cmd("set nu rnu")
vim.cmd("set nowrap")
vim.cmd("set clipboard=unnamedplus")
vim.cmd("set shiftwidth=2")
vim.cmd("set tabstop=2")


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
    {
        "greggh/claude-code.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
        config = function()
            require("claude-code").setup({
                window = {
                    position = "vertical",
                    split_ratio = 0.3,
                },
                keymaps = {
                    toggle = {
                        normal = "<leader>ac",
                        terminal = "<leader>ac",
                    },
                },
            })
        end,
    },
    {
        "rebelot/kanagawa.nvim",
        lazy = false,
        priority = 1000,
    },
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",   -- `master` is frozen upstream at Neovim 0.11
        lazy = false,      -- upstream: "This plugin does not support lazy-loading"
        build = ":TSUpdate",
    },
    { "mbbill/undotree" },
    { "nvim-lua/lsp-status.nvim" },
    { "nvim-tree/nvim-web-devicons" },
    { 'akinsho/bufferline.nvim',         version = "*",      dependencies = 'nvim-tree/nvim-web-devicons' },
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
            "MunifTanjim/nui.nvim",
            "3rd/image.nvim",              -- Optional image support in preview window: See `# Preview Mode` for more information
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
    { 'akinsho/toggleterm.nvim',      version = "*", config = true },
    {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.6',
        dependencies = { 'nvim-lua/plenary.nvim' }
    },
    { 'mrjones2014/smart-splits.nvim' },
    { 'dhruvasagar/vim-table-mode' },
    {
        'akinsho/git-conflict.nvim',
        version = "*",
        config = function()
            require('git-conflict').setup({
                default_mappings = true,     -- use default keymaps
                default_commands = true,     -- enable commands
                disable_diagnostics = false, -- show diagnostics during conflict
                list_opener = 'copen',       -- quickfix for conflict list
                highlights = {
                    incoming = 'DiffAdd',
                    current = 'DiffText',
                }
            })
        end
    },
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            icons = {
                mappings = false,
            },
        },
        keys = {
            {
                "<leader>?",
                function()
                    require("which-key").show({ global = false })
                end,
                desc = "Buffer Local Keymaps (which-key)",
            },
        },
    },
    -- { dir = "/Users/dcruza/Projects/personal/selmod" },
    -- require("lazy/copilot"),
    require("lazy/cocmp"),
    require("lazy/lsp"),
    require("lazy/dap"),
    require("lazy/roslyn"),
})

-- Treesitter, nvim-treesitter `main` branch.
--
-- Why `main` and not `master`: upstream froze `master` and supports it only up
-- to Neovim 0.11. On 0.12 its query directives break, because a query match
-- value became a LIST of nodes rather than a single node. So master's
-- query_predicates.lua calls :range() on a table and throws during redraw:
--   treesitter.lua:197: attempt to call method 'range' (a nil value)
-- ...usually surfacing via the conceal_line decoration provider while
-- processing injections. `main` is a full rewrite; it needs Neovim 0.12+ and
-- tree-sitter-cli (from pacman, not npm).
--
-- Differences from the old config, all deliberate:
--   * `ensure_installed` -> `install{}`
--   * `highlight.enable` -> core's vim.treesitter.start() in a FileType autocmd
--   * `additional_vim_regex_highlighting = false` -> now the default
--   * `auto_install` has no equivalent; parsers are installed explicitly here,
--     which also stops surprise compiles when opening an unfamiliar filetype.
--   * parsers now live in stdpath("data").."/site", not in the plugin directory

require("nvim-treesitter").install({
    "c", "lua", "vim", "vimdoc", "query",
    "javascript", "typescript", "go", "dockerfile",
    "python", "rust", "zig", "c_sharp", "razor",
})

-- No pattern filter: pcall means any buffer with an available parser gets
-- highlighting, and buffers without one are left alone silently.
vim.api.nvim_create_autocmd("FileType", {
    callback = function(args)
        pcall(vim.treesitter.start, args.buf)
    end,
})

-- require("selmod").setup({debug = true})


vim.opt.termguicolors = true
require("bufferline").setup({
    options = {
        mode = "buffers",
        diagnostics = "nvim_lsp",
    }
})
require("plugins/smartsplits")
require("plugins/toggleterm")

local builtin = require('telescope.builtin')

require("utils/lazygit")
require("plugins/telescope")
--[[


require("plugins/heirline")

]] --
