-- C# language server (Roslyn).
--
-- Why Roslyn and not OmniSharp: OmniSharp development is discontinued, gets no
-- feature updates, and does not understand modern C# (12+). Microsoft's
-- Roslyn-based server is what powers the official VS Code C# extension, and
-- seblyng/roslyn.nvim is the maintained Neovim front end for it.
--
-- The server binary is NOT installed by this file. It is a dotnet global tool:
--
--   dotnet tool install -g roslyn-language-server --prerelease \
--     --source https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json
--
-- The Azure DevOps feed is used deliberately - it tracks the version VS Code
-- ships, whereas nuget.org lags. Update with `dotnet tool update` and the same
-- --source. It lands in ~/.dotnet/tools, which .zshrc-lnx puts on PATH.
--
-- Mason also has `roslyn-language-server`, but that pulls the older nuget.org
-- build, so it is deliberately not used here.

return {
    "seblyng/roslyn.nvim",
    ft = { "cs", "razor" },
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {
        -- Let Roslyn own file watching. Neovim's watcher is slow over large
        -- solutions, and running both duplicates work.
        filewatching = "roslyn",
    },
    config = function(_, opts)
        -- Pin the server by absolute path rather than relying on PATH. The tool
        -- lives in ~/.dotnet/tools, which .zshrc-lnx exports - but Neovim
        -- launched from a desktop entry or any non-login shell may not have it,
        -- and the failure mode is a silent no-LSP rather than an error.
        local server = vim.fn.expand("~/.dotnet/tools/roslyn-language-server")
        if vim.fn.executable(server) == 1 then
            vim.lsp.config("roslyn", { cmd = { server, "--stdio" } })
        elseif vim.fn.executable("roslyn-language-server") == 0 then
            vim.notify(
                "roslyn-language-server not found. Install with:\n"
                .. "dotnet tool install -g roslyn-language-server --prerelease --source "
                .. "https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json",
                vim.log.levels.WARN)
        end

        require("roslyn").setup(opts)

        -- Roslyn attaches to a whole solution or project, so it can take a
        -- while on first load and there is no visible signal otherwise.
        vim.api.nvim_create_autocmd("LspAttach", {
            callback = function(args)
                local client = vim.lsp.get_client_by_id(args.data.client_id)
                if client and client.name == "roslyn" then
                    vim.notify("roslyn attached: " .. (client.root_dir or "?"),
                        vim.log.levels.INFO)
                end
            end,
        })

        -- Same keymaps the other servers get from lsp.lua's on_attach, applied
        -- to cs/razor buffers. roslyn.nvim manages its own client, so it does
        -- not go through mason-lspconfig's handler.
        vim.api.nvim_create_autocmd("FileType", {
            pattern = { "cs", "razor" },
            callback = function(ev)
                local o = { buffer = ev.buf, noremap = true, silent = true }
                vim.keymap.set("n", "gd", vim.lsp.buf.definition, o)
                vim.keymap.set("n", "gD", vim.lsp.buf.declaration, o)
                vim.keymap.set("n", "gi", vim.lsp.buf.implementation, o)
                vim.keymap.set("n", "gr", vim.lsp.buf.references, o)
                vim.keymap.set("n", "K", vim.lsp.buf.hover, o)
                vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, o)
                vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, o)
                vim.keymap.set("n", "<leader>f", vim.lsp.buf.format, o)
                vim.keymap.set("n", "gl", vim.diagnostic.open_float, o)
                vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, o)

                -- <leader>f stays on Roslyn's formatter: it is whitespace-only
                -- and respects .editorconfig, so it keeps diffs small on a
                -- shared repo. CSharpier is opinionated and reprints the whole
                -- file, which would produce huge diffs against teammates' work
                -- in a repo that has no agreed formatter. So it is explicit and
                -- opt-in rather than bound to format/save.
                vim.keymap.set("n", "<leader>cf", function()
                    if vim.fn.executable("csharpier") == 0 then
                        vim.notify("csharpier not on PATH", vim.log.levels.ERROR)
                        return
                    end
                    vim.cmd("noautocmd write")
                    local file = vim.api.nvim_buf_get_name(0)
                    vim.system({ "csharpier", "format", file }, { text = true }, function(res)
                        vim.schedule(function()
                            if res.code ~= 0 then
                                vim.notify("csharpier failed:\n" ..
                                    (res.stderr ~= "" and res.stderr or res.stdout),
                                    vim.log.levels.ERROR)
                            else
                                vim.cmd("checktime")
                                vim.notify("csharpier formatted", vim.log.levels.INFO)
                            end
                        end)
                    end)
                end, vim.tbl_extend("force", o, { desc = "CSharpier: format file" }))
            end,
        })
    end,
}
