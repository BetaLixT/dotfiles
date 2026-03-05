vim.g.mapleader = " "

vim.wo.relativenumber = true
vim.cmd("set nu rnu")
vim.cmd("set nowrap")
vim.cmd("set clipboard=unnamedplus")
vim.cmd("set shiftwidth=2")
vim.cmd("set tabstop=2")

-- Keymaps
vim.keymap.set('v', "<", "<gv", { silent = true })
vim.keymap.set('v', ">", ">gv", { silent = true })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    {
        "rebelot/kanagawa.nvim",
        lazy = false,
        priority = 1000,
    },
})

-- Colorscheme
require('kanagawa').setup({
    transparent = true,
    commentStyle = { italic = true },
    keywordStyle = { italic = true },
    statementStyle = { bold = true },
    terminalColors = true,
    theme = "wave",
    background = {
        dark = "wave",
        light = "lotus",
    },
})

vim.opt.termguicolors = true
vim.cmd.colorscheme("kanagawa")
