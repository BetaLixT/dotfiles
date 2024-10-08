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
		local on_attach = function(_, bufnr)
			local function buf_set_option(...)
				vim.api.nvim_buf_set_option(bufnr, ...)
			end

			buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

			--[[
			vim.api.nvim_buf_create_user_command(
				bufnr,
				"format",
				function() vim.lsp.buf.format() end,
				{ desc = "Format file with LSP" }
			)
			]]--

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
			vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
			vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
			vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, opts)
			vim.keymap.set('n', '<leader>f', vim.lsp.buf.format, opts)

			-- Inlay Hints
			local client = vim.lsp.get_client_by_id(ev.data.client_id)
			if client.server_capabilities.inlayHintProvider then
				vim.lsp.inlay_hint.enable(ev.buf, true)
			else
				vim.lsp.inlay_hint.enable(ev.buf, false)
			end
		end

		local cmp = require('cmp')
		local cmp_lsp = require("cmp_nvim_lsp")
		local capabilities = vim.tbl_deep_extend(
			"force",
			{},
			vim.lsp.protocol.make_client_capabilities(),
			cmp_lsp.default_capabilities())

		require("fidget").setup({})
		require("mason").setup()
		require("mason-lspconfig").setup({
			ensure_installed = {
				"lua_ls",
				"rust_analyzer",
				"gopls",
			},
			handlers = {
				function(server_name)         -- default handler (optional)
					require("lspconfig")[server_name].setup {
						capabilities = capabilities,
						on_attach = on_attach,
					}
				end,

				["lua_ls"] = function()
					local lspconfig = require("lspconfig")
					lspconfig.lua_ls.setup {
						capabilities = capabilities,
						settings = {
							Lua = {
								runtime = { version = "Lua 5.1" },
								diagnostics = {
									globals = { "vim", "it", "describe", "before_each", "after_each" },
								}
							}
						}
					}
				end,
			}
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
