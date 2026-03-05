vim.g.mapleader = " "

vim.wo.relativenumber = true
vim.cmd("set nu rnu")
vim.cmd("set nowrap")
vim.cmd("set clipboard=unnamedplus")
vim.cmd("set shiftwidth=2")
vim.cmd("set tabstop=2")
vim.opt.termguicolors = true

-- Keymaps
local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

map('v', '<', '<gv', opts)
map('v', '>', '>gv', opts)
map('t', '<Esc><Esc>', '<C-\\><C-n>', opts)

-- File explorer (netrw)
map('n', '<leader>e', ':Lexplore<CR>', opts)

-- OSC 52 clipboard for tmux/ssh (yank only)
local function osc52_copy(text)
    local b64 = vim.fn.system('printf ' .. vim.fn.shellescape(text) .. ' | base64 | tr -d "\\n"')
    local osc = '\x1b]52;c;' .. b64 .. '\x07'
    if vim.env.TMUX then
        osc = '\x1bPtmux;\x1b' .. osc .. '\x1b\\'
    end
    io.stderr:write(osc)
end

vim.g.clipboard = {
    name = 'osc52',
    copy = {
        ['+'] = function(lines) osc52_copy(table.concat(lines, '\n')) end,
        ['*'] = function(lines) osc52_copy(table.concat(lines, '\n')) end,
    },
    paste = {
        ['+'] = function() return { vim.fn.getreg('0', 1, true), vim.fn.getregtype('0') } end,
        ['*'] = function() return { vim.fn.getreg('0', 1, true), vim.fn.getregtype('0') } end,
    },
}

-- Netrw config (built-in file explorer)
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3
vim.g.netrw_winsize = 25
vim.g.netrw_browse_split = 0
