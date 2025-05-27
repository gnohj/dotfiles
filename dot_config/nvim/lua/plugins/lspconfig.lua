if vim.g.vscode then
  return {}
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- Existing configurations
      opts.servers = {
        harper_ls = {
          enabled = true,
          filetypes = { "markdown", "md", "mdx" },
          settings = {
            ["harper-ls"] = {
              userDictPath = "~/.config/nvim/spell/en.utf-8.add",
              linters = {
                ToDoHyphen = false,
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
              updateImportsOnFileMove = "always",
              format = {
                enable = false, -- let prettier/eslint handle formatting
              },
              suggest = {
                completeFunctionCalls = true,
              },
              tsserver = {
                maxTsServerMemory = 8192,
                useSeparateSyntaxServer = true,
                enablePromptUseWorkspaceTsdk = false,
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
                importModuleSpecifier = "auto", -- let ts decide the best import style based on tsconfig
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

      opts.diagnostics = {
        -- virtual_text = false,
        virtual_text = {
          -- Enable virtual text but filter by source
          source = "if_many",
          format = function(diagnostic)
            -- Only show virtual text for harper-ls in markdown files
            if diagnostic.source == "Harper" then
              return diagnostic.message
            end
            return nil
          end,
        },
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
              local pull_diagnostics =
                vim.diagnostic.get(buf, { namespace = vim.lsp.diagnostic.get_namespace(client.id, false) })
              -- Older versions of the ESLint language server send push
              -- diagnostics rather than using pull. We support both for
              -- backwards compatibility.
              local push_diagnostics =
                vim.diagnostic.get(buf, { namespace = vim.lsp.diagnostic.get_namespace(client.id, true) })
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
