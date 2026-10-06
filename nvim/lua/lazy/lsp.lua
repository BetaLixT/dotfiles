return {
	"neovim/nvim-lspconfig",
	dependencies = {
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
		"hrsh7th/cmp-nvim-lsp",
		"hrsh7th/cmp-buffer",
		"hrsh7th/cmp-path",
		"hrsh7th/cmp-cmdline",
		"hrsh7th/nvim-cmp",
		"L3MON4D3/LuaSnip",
		"saadparwaiz1/cmp_luasnip",
		"j-hui/fidget.nvim",
		"onsails/lspkind.nvim",
	},

	config = function()
		-- mason-lspconfig v2 dropped the `handlers` table: it now calls
		-- vim.lsp.enable() on every installed server itself, so anything
		-- passed through a handler (on_attach, capabilities, settings) was
		-- silently ignored. Per-server config goes through vim.lsp.config()
		-- instead, and buffer setup through an LspAttach autocmd. The
		-- autocmd also covers roslyn, which has its own client outside mason.
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
			callback = function(args)
				local client = vim.lsp.get_client_by_id(args.data.client_id)
				local bufnr = args.buf

				local opts = { buffer = bufnr, noremap = true, silent = true }
				vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
				vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
				vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
				vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
				-- vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
				vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts)
				vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts)
				vim.keymap.set('n', '<leader>wl', function()
					print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
				end, opts)
				vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts)
				vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
				vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
				vim.keymap.set('n', 'gl', vim.diagnostic.open_float, opts)
				-- goto_prev/goto_next are deprecated; jump() with float = true
				-- keeps their behaviour of opening the diagnostic float.
				vim.keymap.set('n', '[d', function() vim.diagnostic.jump({ count = -1, float = true }) end, opts)
				vim.keymap.set('n', ']d', function() vim.diagnostic.jump({ count = 1, float = true }) end, opts)
				vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, opts)
				vim.keymap.set('n', '<leader>f', vim.lsp.buf.format, opts)
				-- Code actions were missing entirely. They matter everywhere, but
				-- especially in C#, where 'add using', 'implement interface' and
				-- 'generate constructor' are all delivered as code actions.
				vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)

				-- Inlay Hints
				if client and client.server_capabilities.inlayHintProvider then
					vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
				end
			end,
		})

		local cmp = require('cmp')
		local cmp_lsp = require("cmp_nvim_lsp")

		-- "*" merges into every server's config, including roslyn's.
		vim.lsp.config("*", {
			capabilities = cmp_lsp.default_capabilities(),
		})

		vim.lsp.config("lua_ls", {
			settings = {
				Lua = {
					runtime = { version = "Lua 5.1" },
					diagnostics = {
						globals = { "vim", "it", "describe", "before_each", "after_each" },
					}
				}
			}
		})

		require("fidget").setup({})
		require("mason").setup()
		require("mason-lspconfig").setup({
			ensure_installed = {
				"lua_ls",
				"rust_analyzer",
				"gopls",
				"yamlls",
				"jsonls",
			},
		})

		local cmp_select = { behavior = cmp.SelectBehavior.Select }
		local lspkind = require('lspkind')
		cmp.setup({
			snippet = {
				expand = function(args)
					require('luasnip').lsp_expand(args.body)           -- For `luasnip` users.
				end,
			},
			mapping = cmp.mapping.preset.insert({
				['<S-Tab>'] = cmp.mapping.select_prev_item(cmp_select),
				['<Tab>'] = cmp.mapping.select_next_item(cmp_select),
				['<Return>'] = cmp.mapping.confirm({ select = true }),
				["<C-Space>"] = cmp.mapping.complete(),
			}),
			sources = cmp.config.sources({
				{ name = "copilot", group_index = 2 },
				{ name = 'nvim_lsp' },
				{ name = 'luasnip' },         -- For luasnip users.
			}, {
				{ name = 'buffer' },
			}),
			formatting = {
				format = lspkind.cmp_format({
					mode = "symbol",
					max_width = 50,
					symbol_map = { Copilot = "" }
				})
			}
		})

		vim.diagnostic.config({
			-- update_in_insert = true,
			float = {
				focusable = false,
				style = "minimal",
				border = "rounded",
				source = "always",
				header = "",
				prefix = "",
			},
		})
	end
}
