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

-- Better window navigation
vim.keymap.set('n', "<C-h>", function() require("smart-splits").move_cursor_left() end, {silent = true })
vim.keymap.set('n', "<C-j>", function() require("smart-splits").move_cursor_down() end, {silent = true })
vim.keymap.set('n', "<C-k>", function() require("smart-splits").move_cursor_up() end, {silent = true })
vim.keymap.set('n', "<C-l>", function() require("smart-splits").move_cursor_right() end, {silent = true })

-- Resize with arrows
vim.keymap.set('n', "<C-Up>", function() require("smart-splits").resize_up() end, {silent = true })
vim.keymap.set('n', "<C-Down>", function() require("smart-splits").resize_down() end, {silent = true })
vim.keymap.set('n', "<C-Left>", function() require("smart-splits").resize_left() end, {silent = true })
vim.keymap.set('n', "<C-Right>", function() require("smart-splits").resize_right() end, {silent = true })


vim.keymap.set('v', "<", "<gv", {silent = true })
vim.keymap.set('v', ">", ">gv", {silent = true })

-- git

