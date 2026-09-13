return {
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            "rcarriga/nvim-dap-ui",
            "nvim-neotest/nvim-nio",
            "theHamsta/nvim-dap-virtual-text",
            -- Language specific
            "leoluz/nvim-dap-go",
            "mfussenegger/nvim-dap-python",
            "jbyuki/one-small-step-for-vimkind", -- Lua
        },
        config = function()
            local dap = require("dap")
            local dapui = require("dapui")

            -- DAP UI setup
            dapui.setup({
                icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
                mappings = {
                    expand = { "<CR>", "<2-LeftMouse>" },
                    open = "o",
                    remove = "d",
                    edit = "e",
                    repl = "r",
                    toggle = "t",
                },
                layouts = {
                    {
                        elements = {
                            { id = "scopes",      size = 0.25 },
                            { id = "breakpoints", size = 0.25 },
                            { id = "stacks",      size = 0.25 },
                            { id = "watches",     size = 0.25 },
                        },
                        size = 40,
                        position = "left",
                    },
                    {
                        elements = {
                            { id = "repl",    size = 0.5 },
                            { id = "console", size = 0.5 },
                        },
                        size = 10,
                        position = "bottom",
                    },
                },
            })

            -- Virtual text setup
            require("nvim-dap-virtual-text").setup({})

            -- Auto open/close DAP UI
            dap.listeners.after.event_initialized["dapui_config"] = function()
                dapui.open()
            end
            dap.listeners.before.event_terminated["dapui_config"] = function()
                dapui.close()
            end
            dap.listeners.before.event_exited["dapui_config"] = function()
                dapui.close()
            end

            -- Signs
            vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "DiagnosticError", linehl = "", numhl = "" })
            vim.fn.sign_define("DapBreakpointCondition",
                { text = "", texthl = "DiagnosticWarn", linehl = "", numhl = "" })
            vim.fn.sign_define("DapLogPoint", { text = "", texthl = "DiagnosticInfo", linehl = "", numhl = "" })
            vim.fn.sign_define("DapStopped",
                { text = "▶", texthl = "DiagnosticOk", linehl = "DapStoppedLine", numhl = "" })
            vim.fn.sign_define("DapBreakpointRejected",
                { text = "", texthl = "DiagnosticError", linehl = "", numhl = "" })

            -- Go
            require("dap-go").setup()

            -- Python
            require("dap-python").setup("python")

            -- Lua (one-small-step-for-vimkind)
            dap.configurations.lua = {
                {
                    type = "nlua",
                    request = "attach",
                    name = "Attach to running Neovim instance",
                },
            }
            dap.adapters.nlua = function(callback, config)
                callback({ type = "server", host = config.host or "127.0.0.1", port = config.port or 8086 })
            end

            -- Rust / C / C++ (codelldb)
            dap.adapters.codelldb = {
                type = "server",
                port = "${port}",
                executable = {
                    command = "codelldb",
                    args = { "--port", "${port}" },
                },
            }
            dap.configurations.rust = {
                {
                    name = "Launch",
                    type = "codelldb",
                    request = "launch",
                    program = function()
                        return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
                    end,
                    cwd = "${workspaceFolder}",
                    stopOnEntry = false,
                },
            }

            -- Zig (codelldb)
            dap.configurations.zig = {
                {
                    name = "Launch",
                    type = "codelldb",
                    request = "launch",
                    program = function()
                        return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/zig-out/bin/", "file")
                    end,
                    cwd = "${workspaceFolder}",
                    stopOnEntry = false,
                },
            }

            -- TypeScript / JavaScript (node)
            dap.adapters["pwa-node"] = {
                type = "server",
                host = "localhost",
                port = "${port}",
                executable = {
                    command = "node",
                    args = {
                        vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js",
                        "${port}",
                    },
                },
            }
            local js_config = {
                {
                    type = "pwa-node",
                    request = "launch",
                    name = "Launch file",
                    program = "${file}",
                    cwd = "${workspaceFolder}",
                },
                {
                    type = "pwa-node",
                    request = "attach",
                    name = "Attach",
                    processId = require("dap.utils").pick_process,
                    cwd = "${workspaceFolder}",
                },
            }
            dap.configurations.javascript = js_config
            dap.configurations.typescript = js_config

            -- C# / .NET (netcoredbg, installed via mason)
            --
            -- Mason puts its bin dir on Neovim's PATH, so "netcoredbg" resolves.
            -- The absolute path is used as a fallback so this still works if a
            -- future config stops prepending mason's bin.
            local netcoredbg = vim.fn.exepath("netcoredbg")
            if netcoredbg == "" then
                netcoredbg = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg"
            end

            dap.adapters.coreclr = {
                type = "executable",
                command = netcoredbg,
                args = { "--interpreter=vscode" },
            }

            -- Find launchable assemblies in the current solution.
            --
            -- A plain glob over bin/Debug is useless here: the output directory
            -- of one project also contains every referenced project and NuGet
            -- assembly. Instead, walk the .csproj files and, for each, look for
            -- the assembly named after that project. Then require a matching
            -- runtimeconfig.json, which only executable projects produce - that
            -- is what filters out class libraries such as Core and Services.
            local function launchable_dlls()
                local root = vim.fn.getcwd()
                local projects = vim.fs.find(function(name)
                    return name:match("%.csproj$")
                end, { path = root, type = "file", limit = 50 })

                local found = {}
                for _, proj in ipairs(projects) do
                    local dir = vim.fs.dirname(proj)
                    local name = vim.fn.fnamemodify(proj, ":t:r")
                    for _, dll in ipairs(vim.fn.glob(
                        dir .. "/bin/Debug/net*/" .. name .. ".dll", false, true)) do
                        local runtimecfg = dll:gsub("%.dll$", ".runtimeconfig.json")
                        if vim.fn.filereadable(runtimecfg) == 1 then
                            table.insert(found, dll)
                        end
                    end
                end
                return found
            end

            -- Build before launching, otherwise it is very easy to step through
            -- stale IL and misread the result.
            local function build_then_pick(cb)
                vim.notify("dotnet build…", vim.log.levels.INFO)
                vim.system({ "dotnet", "build" }, { text = true }, function(res)
                    vim.schedule(function()
                        if res.code ~= 0 then
                            vim.notify("dotnet build failed; not launching\n"
                                .. (res.stderr ~= "" and res.stderr or res.stdout),
                                vim.log.levels.ERROR)
                            return
                        end
                        local dlls = launchable_dlls()
                        if #dlls == 0 then
                            cb(vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/", "file"))
                        elseif #dlls == 1 then
                            cb(dlls[1])
                        else
                            vim.ui.select(dlls, { prompt = "Which assembly?" }, function(choice)
                                if choice then cb(choice) end
                            end)
                        end
                    end)
                end)
            end

            dap.configurations.cs = {
                {
                    type = "coreclr",
                    name = "launch (build first)",
                    request = "launch",
                    program = function()
                        return coroutine.create(function(co)
                            build_then_pick(function(path)
                                coroutine.resume(co, path)
                            end)
                        end)
                    end,
                    cwd = "${workspaceFolder}",
                    env = { ASPNETCORE_ENVIRONMENT = "Development" },
                },
                {
                    type = "coreclr",
                    name = "launch (pick dll, no build)",
                    request = "launch",
                    program = function()
                        return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/", "file")
                    end,
                    cwd = "${workspaceFolder}",
                },
                {
                    -- For attaching to something already running, including a
                    -- process inside a container with the debugger port exposed.
                    type = "coreclr",
                    name = "attach to process",
                    request = "attach",
                    processId = require("dap.utils").pick_process,
                    cwd = "${workspaceFolder}",
                },
            }
            dap.configurations.razor = dap.configurations.cs

            -- Keymaps
            vim.keymap.set("n", "<leader>dd", dapui.toggle, { desc = "Debug: Open/Toggle UI" })
            vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
            vim.keymap.set("n", "<leader>dB", function()
                dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
            end, { desc = "Debug: Conditional Breakpoint" })
            vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Debug: Continue" })
            vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Debug: Step Into" })
            vim.keymap.set("n", "<leader>do", dap.step_over, { desc = "Debug: Step Over" })
            vim.keymap.set("n", "<leader>dO", dap.step_out, { desc = "Debug: Step Out" })
            vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Debug: Open REPL" })
            vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "Debug: Run Last" })
            vim.keymap.set("n", "<leader>dt", dap.terminate, { desc = "Debug: Terminate" })
            vim.keymap.set({ "n", "v" }, "<leader>de", dapui.eval, { desc = "Debug: Eval" })

            -- Function keys (common debugger shortcuts)
            vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug: Continue" })
            vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: Step Over" })
            vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: Step Into" })
            vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug: Step Out" })
        end,
    },
}
