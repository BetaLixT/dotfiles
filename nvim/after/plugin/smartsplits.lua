-- Better window navigation

vim.cmd("set splitbelow")
vim.cmd("set splitright")
vim.keymap.set('n', "-", vim.cmd.split)
vim.keymap.set('n', "_", vim.cmd.vsplit)
vim.keymap.set('n', "<C-h>", function() require("smart-splits").move_cursor_left() end, {silent = true })
vim.keymap.set('n', "<C-j>", function() require("smart-splits").move_cursor_down() end, {silent = true })
vim.keymap.set('n', "<C-k>", function() require("smart-splits").move_cursor_up() end, {silent = true })
vim.keymap.set('n', "<C-l>", function() require("smart-splits").move_cursor_right() end, {silent = true })

vim.keymap.set('n', "<A-h>", function() require("smart-splits").resize_left() end, {silent = true })
vim.keymap.set('n', "<A-j>", function() require("smart-splits").resize_down() end, {silent = true })
vim.keymap.set('n', "<A-k>", function() require("smart-splits").resize_up() end, {silent = true })
vim.keymap.set('n', "<A-l>", function() require("smart-splits").resize_right() end, {silent = true })
