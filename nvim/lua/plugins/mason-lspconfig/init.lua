-- local mason_lspconfig = require "mason-lspconfig"
-- mason_lspconfig.setup(astronvim.user_plugin_opts "plugins.mason-lspconfig")iiijk
--
require('mason-lspconfig').setup({
    ensure_installed = {
        'cssls',
        'html',
        'jsonls',
        'ltex',
        'lua_ls',
        'pyright',
        'rust_analyzer',
        'tsserver',
        'volar',
        'yamlls',
				'gopls',
    },
})


