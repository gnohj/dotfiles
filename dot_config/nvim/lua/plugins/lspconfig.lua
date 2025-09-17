if vim.g.vscode then
  return {}
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      -- Remove the code action keymap
      keys[#keys + 1] = { "<leader>ca", false }
      keys[#keys + 1] = { "<leader>cA", false }

      -- Existing configurations
      opts.servers = {
        lua_ls = {
          -- Only start for .lua files to avoid scanning issues
          filetypes = { "lua" },
          single_file_support = true,
          settings = {
            Lua = {
              runtime = {
                version = "LuaJIT",
              },
              workspace = {
                -- Limit workspace loading but don't disable it completely
                library = {},
                checkThirdParty = false,
                maxPreload = 500,  -- Reasonable limit for Neovim config files
                preloadFileSize = 50,  -- KB - only preload small files
                ignoreDir = { ".git", "node_modules", "lazy" },  -- Ignore these directories
                ignoreSubmodules = true,
              },
              diagnostics = {
                -- Get the language server to recognize the `vim` global
                globals = { "vim", "require" },
                disable = { "lowercase-global" },
              },
              completion = {
                workspaceWord = false,  -- Don't scan workspace for completions
                showWord = "Disable",
              },
              -- Disable telemetry
              telemetry = { enable = false },
            },
          },
          -- Smart root detection - use nvim config for nvim files, otherwise current file dir
          root_dir = function(fname)
            local util = require("lspconfig.util")
            -- Ensure fname is a string (handle both old and new API)
            if type(fname) == "number" then
              fname = vim.api.nvim_buf_get_name(fname)
            end
            -- For Neovim config files, use the nvim config dir as root
            if fname:match("%.config/nvim/") then
              return vim.fn.expand("~/.config/nvim")
            end
            -- For other lua files, look for .luarc.json or .git
            return util.root_pattern(".luarc.json", ".luarc.jsonc", ".git")(fname)
              or util.find_git_ancestor(fname)
              or vim.fn.fnamemodify(fname, ":h")  -- Use file's directory as root
          end,
        },
        harper_ls = {
          enabled = true,
          filetypes = { "markdown", "md", "mdx" },
          settings = {
            ["harper-ls"] = {
              userDictPath = "~/.config/nvim/spell/dict.txt", -- only adds global words here
              fileDictPath = "", -- only store these in memory
              linters = {
                ToDoHyphen = false,
                SentenceCapitalization = false,
                CommaFixes = false,
              },
              isolateEnglish = true,
              markdown = {
                IgnoreLinkTitle = true,
              },
            },
          },
        },
        tsserver = { enabled = false },
        ts_ls = { enabled = false },
        vtsls = {
          autoUseWorkspaceTsdk = true, -- Add this for better TS version consistency
          filetypes = {
            "javascript",
            "javascriptreact",
            "javascript.jsx",
            "typescript",
            "typescriptreact",
            "typescript.tsx",
          },
          settings = {
            typescript = {
              format = {
                enable = false, -- let prettier/eslint handle formatting
              },
              suggest = {
                completeFunctionCalls = true,
              },
              diagnostics = {
                -- Disable TypeScript's unused variable checks since ESLint handles them
                ignoredCodes = { 6133, 6196 }, -- 6133: declared but never read, 6196: declared but never used
              },
              tsserver = {
                maxTsServerMemory = 8192,
                useSeparateSyntaxServer = true,
                enablePromptUseWorkspaceTsdk = false,
                init_options = {
                  hostInfo = "neovim",
                  preferences = {
                    includeCompletionsForModuleExports = true,
                    includeCompletionsForImportStatements = true,
                    importModuleSpecifierPreference = "relative",
                  },
                },
              },
              disableAutomaticTypingAcquisition = true,
              inlayHints = {
                enumMemberValues = true,
                functionLikeReturnTypes = true,
                parameterNames = "literals",
                parameterTypes = true,
                propertyDeclarationTypes = true,
                variableTypes = false,
              },
              preferences = {
                includeCompletionsForModuleExports = true,
                includeCompletionsForImportStatements = true,
                importModuleSpecifier = "non-relative",
                -- importModuleSpecifier = "auto", -- let ts decide the best import style based on tsconfig
                updateImportsOnFileMove = {
                  enabled = "always",
                },
                includePackageJsonAutoImports = "off",
              },
            },
          },
        },
        -- Add the ansiblels configuration
        ansiblels = {
          settings = {
            ansible = {
              validation = {
                lint = {
                  -- this is also handled by prettier, and they don't quite agree
                  arguments = "--skip-list=yaml",
                },
              },
            },
          },
        },
      }

      opts.inlay_hints = {
        enabled = false,
        exclude = {},
      }

      -- Commented out to let tiny-inline-diagnostic handle all diagnostics
      opts.diagnostics = {
        virtual_text = false,
        -- virtual_text = {
        --   -- Enable virtual text but filter by source
        --   source = "if_many",
        --   format = function(diagnostic)
        --     -- Only show virtual text for harper-ls in markdown files
        --     if diagnostic.source == "Harper" then
        --       return diagnostic.message
        --     end
        --     return nil
        --   end,
        -- },
      }

      -- Add the eslint setup configuration - this is from https://github.com/iainlane/dotfiles/commit/1abe290bfe071b92a806eea62abadbab18ee63c3
      -- to fix eslint formatting which was broken in Neovim 0.11.0
      opts.setup = opts.setup or {}
      opts.setup.eslint = function()
        local function get_client(buf)
          return LazyVim.lsp.get_clients({ name = "eslint", bufnr = buf })[1]
        end

        local formatter = LazyVim.lsp.formatter({
          name = "eslint: lsp",
          primary = false,
          priority = 200,
          filter = "eslint",
        })

        -- Modified condition: For both Neovim < 0.10.0 and Neovim 0.11.0+
        -- The original check was breaking in 0.11.0, so we handle both old versions
        -- and the specific case of 0.11.0
        if vim.fn.has("nvim-0.10") == 0 or vim.version().minor >= 11 then
          formatter.name = "eslint: EslintFixAll"
          formatter.sources = function(buf)
            local client = get_client(buf)
            return client and { "eslint" } or {}
          end
          formatter.format = function(buf)
            local client = get_client(buf)
            if client then
              local pull_diagnostics = vim.diagnostic.get(buf, {
                namespace = vim.lsp.diagnostic.get_namespace(client.id, false),
              })
              -- Older versions of the ESLint language server send push
              -- diagnostics rather than using pull. We support both for
              -- backwards compatibility.
              local push_diagnostics = vim.diagnostic.get(buf, {
                namespace = vim.lsp.diagnostic.get_namespace(client.id, true),
              })
              if (#pull_diagnostics + #push_diagnostics) > 0 then
                vim.cmd("EslintFixAll")
              end
            end
          end
        end

        -- register the formatter with LazyVim
        LazyVim.format.register(formatter)
      end

      -- 🔒 disable <leader>ca keymap here (cleaner than on_attach override)
      -- local keys = require("lazyvim.plugins.lsp.keymaps").get()
      -- keys[#keys + 1] = { "<leader>ca", false }
    end,
  },
}
