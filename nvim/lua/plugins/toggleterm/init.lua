require 'toggleterm'.setup {
    open_mapping = [[<C-\>]],
    direction = 'horizontal',
    size = 15,
}

vim.keymap.set('n', '<leader>tt', '<cmd>ToggleTerm<cr>', { desc = 'Toggle terminal' })
vim.keymap.set('n', '<leader>tf', '<cmd>ToggleTerm direction=float<cr>', { desc = 'Toggle floating terminal' })
vim.keymap.set('n', '<leader>tv', '<cmd>ToggleTerm direction=vertical size=80<cr>', { desc = 'Toggle vertical terminal' })
