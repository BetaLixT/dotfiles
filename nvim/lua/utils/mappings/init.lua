vim.g.mapleader = " "
vim.keymap.set('n', '<leader>e', '<Cmd>Neotree toggle<CR>', { silent = true })
vim.keymap.set('n', '<leader>o',
    function()
        if vim.bo.filetype == "neo-tree" then
            vim.cmd.wincmd "p"
        else
            vim.cmd.Neotree "focus"
        end
    end,
    { silent = true }
)

vim.keymap.set('n', '<S-l>', '<cmd>BufferLineCycleNext<cr>', { silent = true })
vim.keymap.set('n', '<S-h>', '<cmd>BufferLineCyclePrev<cr>', { silent = true })


vim.keymap.set('v', "<", "<gv", { silent = true })
vim.keymap.set('v', ">", ">gv", { silent = true })

-- git

-- terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Fix leader key delay in terminal mode
vim.api.nvim_create_autocmd('TermEnter', {
    callback = function()
        vim.opt_local.timeoutlen = 0
    end,
})
vim.api.nvim_create_autocmd('TermLeave', {
    callback = function()
        vim.opt_local.timeoutlen = 1000
    end,
})

-- Ensure Esc-Esc works in all terminals (including claude-code)
vim.api.nvim_create_autocmd('TermOpen', {
    callback = function()
        vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { buffer = true, desc = 'Exit terminal mode' })
    end,
})
