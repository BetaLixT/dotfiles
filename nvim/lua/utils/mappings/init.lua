vim.g.mapleader = " "
vim.keymap.set('n', '<leader>e', '<Cmd>Neotree toggle<CR>', {silent = true })
vim.keymap.set('n', '<leader>o',
    function()
      if vim.bo.filetype == "neo-tree" then
        vim.cmd.wincmd "p"
      else
        vim.cmd.Neotree "focus"
      end
    end,
    {silent = true}
)

vim.keymap.set('n', '<S-l>', '<cmd>BufferLineCycleNext<cr>', {silent = true })
vim.keymap.set('n', '<S-h>', '<cmd>BufferLineCyclePrev<cr>', {silent = true })


vim.keymap.set('v', "<", "<gv", {silent = true })
vim.keymap.set('v', ">", ">gv", {silent = true })

-- git

