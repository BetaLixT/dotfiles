

-- vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
-- vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

-- LSPCONFIG
local lspconfig = require('lspconfig')

-- CMP LSP CAPABILITIES
local lsp_defaults = lspconfig.util.default_config
lsp_defaults.capabilities = vim.tbl_deep_extend('force', lsp_defaults.capabilities, require('cmp_nvim_lsp').default_capabilities())

require('lspconfig.ui.windows').default_options.border = 'rounded'

-- KEYMAPS
local opts = function(desc)
    return { noremap = true, silent = true, desc = desc }
end

-- local opts = { noremap = true, silent = true }

-- LSPATTACH AUTOCOMMAND
local on_attach = function(_, bufnr)
	-- group = vim.api.nvim_create_augroup('UserLspConfig', {}),
	-- callback = function(ev)
	-- Enable completion triggered by <c-x><c-o>
	--vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

	-- Buffer local mappings.
	-- See `:help vim.lsp.*` for documentation on any of the below functions
	--local bufopts = function(desc)
	--		return { buffer = ev.buf, desc = desc }
	--end

	local function buf_set_option(...)
		vim.api.nvim_buf_set_option(bufnr, ...)
	end

	buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')


	local opts = { buffer = bufnr, noremap = true, silent = true }
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
  vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts)
  vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts)
  vim.keymap.set('n', '<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, opts)
  vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
	vim.keymap.set('n', 'gl', vim.diagnostic.open_float, opts)
  vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
  vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
  vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, opts)
	vim.keymap.set('n', '<leader>f', vim.lsp.buf.format, opts)

	vim.api.nvim_buf_create_user_command(
	bufnr,
	"format",
	function() vim.lsp.buf.format() end,
	{ desc = "Format file with LSP" }
)

	-- Inlay Hints
	local client = vim.lsp.get_client_by_id(ev.data.client_id)
	if client.server_capabilities.inlayHintProvider then
			vim.lsp.inlay_hint.enable(ev.buf, true)
	else
			vim.lsp.inlay_hint.enable(ev.buf, false)
	end
end


-- BORDERS FOR DIAGNOSTICS
-- vim.cmd([[autocmd! ColorScheme * highlight FloatBorder guifg=white guibg=#181926]])
-- vim.cmd([[autocmd! ColorScheme * highlight NormalFloat guibg=#181926]])

local border = {
    { '┌', 'FloatBorder' },
    { '─', 'FloatBorder' },
    { '┐', 'FloatBorder' },
    { '│', 'FloatBorder' },
    { '┘', 'FloatBorder' },
    { '─', 'FloatBorder' },
    { '└', 'FloatBorder' },
    { '│', 'FloatBorder' },
}

-- LSP SETTINGS (FOR OVERRIDING PER CLIENT)
local handlers = {
    ['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, { border = border }),
    ['textDocument/signatureHelp'] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = border }),
}

-- DISABLE LSP (NOT CMP) INLINE DIAGNOSTICS ERROR MESSAGES
-- vim.lsp.handlers['textDocument/publishDiagnostics'] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
--     virtual_text = false,
-- })

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

--  ╭──────────────────────────────────────────────────────────╮
--  │                         SERVERS                          │
--  ╰──────────────────────────────────────────────────────────╯


require'lspconfig'.pyright.setup{
	on_attach = on_attach,
}

require'lspconfig'.gopls.setup{
	on_attach = on_attach,
	cmd = { "gopls" },
	filetypes = {"go", "gomod", "gowork", "gotmpl" },
	settings = {
		gopls = {
			completeUnimported = true,
			usePlaceholders = true,
			analyses = {
				unusedparams = true,
			},
		},
	},
}

require'lspconfig'.omnisharp.setup{
	on_attach = on_attach,
	cmd = { "omnisharp" },
	settings = {
	},
}


local ok, mason_registry = pcall(require, 'mason-registry')
if not ok then
    vim.notify 'mason-registry could not be loaded'
    return
end

local angularls_path = mason_registry.get_package('angular-language-server'):get_install_path()

require'lspconfig'.angularls.setup{
	on_attach = on_attach,
	cmd = {
    'ngserver',
    '--stdio',
    '--tsProbeLocations',
    table.concat({
        angularls_path,
        vim.uv.cwd(),
    }, ','),
    '--ngProbeLocations',
    table.concat({
        angularls_path .. '/node_modules/@angular/language-server',
        vim.uv.cwd(),
    }, ','),
	},
	settings = {
	},
}

require'lspconfig'.tsserver.setup{
	on_attach = on_attach,
}
