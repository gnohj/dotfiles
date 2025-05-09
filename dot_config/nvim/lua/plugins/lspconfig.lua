if vim.g.vscode then
  return {}
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = {
        tsserver = { enabled = false },
        ts_ls = { enabled = false },
        vtsls = {
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
              suggest = {
                completeFunctionCalls = true,
              },
              tsserver = {
                maxTsServerMemory = 8192,
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
                includePackageJsonAutoImports = "off",
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
        virtual_text = false,
      }

      -- 🔒 disable <leader>ca keymap here (cleaner than on_attach override)
      -- local keys = require("lazyvim.plugins.lsp.keymaps").get()
      -- keys[#keys + 1] = { "<leader>ca", false }
    end,
  },
}
