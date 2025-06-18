if vim.g.vscode then
  return {}
end

-- NOTE: Specify the trigger character(s) used for luasnip
local trigger_text = ";"

return {
  -- {
  --   "saghen/blink.compat",
  --   -- use the latest release, via version = '*', if you also use the latest release for blink.cmp
  --   version = "*",
  --   -- lazy.nvim will automatically load the plugin when it's required by blink.cmp
  --   lazy = true,
  --   -- make sure to set opts so that lazy.nvim calls blink.compat's setup
  --   opts = {},
  -- },
  {
    "saghen/blink.cmp",
    enabled = true,
    dependencies = {
      "moyiz/blink-emoji.nvim",
      "Kaiser-Yang/blink-cmp-dictionary",
      "giuxtaposition/blink-cmp-copilot",
      "Kaiser-Yang/blink-cmp-avante",
    },
    opts = function(_, opts)
      opts.enabled = function()
        -- Get the current buffer's filetype
        local filetype = vim.bo[0].filetype
        if filetype == "minifiles" or filetype == "snacks_picker_input" then
          return false
        end
        return true
      end

      -- Merge custom sources with the existing ones from lazyvim
      -- NOTE: by default lazyvim already includes the lazydev source, so not adding it here again
      opts.sources = vim.tbl_deep_extend("force", opts.sources or {}, {
        default = {
          "avante",
          "lsp",
          "path",
          "snippets",
          "buffer",
          "emoji",
          "dictionary",
          -- "dadbod",
          -- "copilot",
          -- "avante_commands",
          -- "avante_mentions",
          -- "avante_files",
        },
        providers = {
          -- avante_commands = {
          --   name = "avante_commands",
          --   module = "blink.compat.source",
          --   score_offset = 95, -- show at a higher priority than lsp
          --   opts = {},
          -- },
          -- avante_files = {
          --   name = "avante_commands",
          --   module = "blink.compat.source",
          --   score_offset = 100, -- show at a higher priority than lsp
          --   opts = {},
          -- },
          -- avante_mentions = {
          --   name = "avante_mentions",
          --   module = "blink.compat.source",
          --   score_offset = 1000, -- show at a higher priority than lsp
          --   opts = {},
          -- },
          avante = {
            module = "blink-cmp-avante",
            name = "Avante",
            opts = {
              -- options for blink-cmp-avante
            },
          },

          dictionary = {
            module = "blink-cmp-dictionary", -- make sure to have wordnet installed to get definitions
            name = "Dict",
            score_offset = 20, -- the higher the number, the higher the priority
            -- https://github.com/Kaiser-Yang/blink-cmp-dictionary/issues/2
            enabled = function()
              local filetype = vim.bo[0].filetype
              local markdown_filetypes = { "markdown", "md", "mdx" }
              return vim.tbl_contains(markdown_filetypes, filetype)
            end,
            max_items = 8,
            min_keyword_length = 3,
            opts = {
              -- -- The dictionary by default now uses fzf, make sure to have it
              -- -- installed
              -- -- https://github.com/Kaiser-Yang/blink-cmp-dictionary/issues/2
              dictionary_directories = {
                vim.fn.expand("~/.config/nvim/dictionaries"),
              },
              dictionary_files = {
                vim.fn.expand("~/.config/nvim/spell/en.utf-8.add"),
              },
            },
          },

          lsp = {
            name = "lsp",
            enabled = true,
            module = "blink.cmp.sources.lsp",
            kind = "LSP",
            min_keyword_length = 2,
            -- When linking markdown notes, I would get snippets and text in the
            -- suggestions, I want those to show only if there are no LSP
            -- suggestions
            -- Disabling fallbacks as my snippets woudlnt show up
            score_offset = 90, -- the higher the number, the higher the priority
          },
          path = {
            name = "Path",
            module = "blink.cmp.sources.path",
            score_offset = 25,
            min_keyword_length = 2,
            -- When typing a path, I would get snippets and text in the
            -- suggestions, I want those to show only if there are no path
            -- suggestions
            fallbacks = { "buffer" },
            opts = {
              trailing_slash = false,
              label_trailing_slash = true,
              get_cwd = function(context)
                return vim.fn.expand(("#%d:p:h"):format(context.bufnr))
              end,
              show_hidden_files_by_default = true,
            },
          },
          buffer = {
            name = "Buffer",
            enabled = true,
            max_items = 3,
            module = "blink.cmp.sources.buffer",
            min_keyword_length = 4,
            score_offset = 15,
          },
          snippets = {
            name = "snippets",
            enabled = true,
            max_items = 15,
            min_keyword_length = 2,
            module = "blink.cmp.sources.snippets",
            score_offset = 85, -- the higher the number, the higher the priority
            -- Only show snippets if I type the trigger_text characters, so
            -- to expand the "bash" snippet, if the trigger_text is ";" I have to
            should_show_items = function()
              local col = vim.api.nvim_win_get_cursor(0)[2]
              local before_cursor = vim.api.nvim_get_current_line():sub(1, col)
              -- NOTE: remember that `trigger_text` is modified at the top of the file
              return before_cursor:match(trigger_text .. "%w*$") ~= nil
            end,
            -- After accepting the completion, delete the trigger_text characters
            -- from the final inserted text
            -- Modified transform_items function based on suggestion by `synic` so
            -- that the luasnip source is not reloaded after each transformation
            -- NOTE: I also tried to add the ";" prefix to all of the snippets loaded from
            -- friendly-snippets in the luasnip.lua file, but I was unable to do
            -- so, so I still have to use the transform_items here
            -- This removes the ";" only for the friendly-snippets snippets
            transform_items = function(_, items)
              local line = vim.api.nvim_get_current_line()
              local col = vim.api.nvim_win_get_cursor(0)[2]
              local before_cursor = line:sub(1, col)
              local start_pos, end_pos = before_cursor:find(
                trigger_text .. "[^" .. trigger_text .. "]*$"
              )
              if start_pos then
                for _, item in ipairs(items) do
                  if not item.trigger_text_modified then
                    ---@diagnostic disable-next-line: inject-field
                    item.trigger_text_modified = true
                    item.textEdit = {
                      newText = item.insertText or item.label,
                      range = {
                        start = {
                          line = vim.fn.line(".") - 1,
                          character = start_pos - 1,
                        },
                        ["end"] = {
                          line = vim.fn.line(".") - 1,
                          character = end_pos,
                        },
                      },
                    }
                  end
                end
              end
              return items
            end,
          },
          -- https://github.com/kristijanhusak/vim-dadbod-completion
          -- dadbod = {
          --   name = "Dadbod",
          --   module = "vim_dadbod_completion.blink",
          --   min_keyword_length = 2,
          --   score_offset = 85, -- the higher the number, the higher the priority
          -- },
          -- https://github.com/moyiz/blink-emoji.nvim
          emoji = {
            module = "blink-emoji",
            name = "Emoji",
            score_offset = 93, -- the higher the number, the higher the priority
            min_keyword_length = 2,
            opts = { insert = true }, -- Insert emoji (default) or complete its name
          },
          -- copilot = {
          --   name = "copilot",
          --   enabled = true,
          --   module = "blink-cmp-copilot",
          --   min_keyword_length = 6,
          --   score_offset = -100, -- the higher the number, the higher the priority
          --   async = true,
          -- },
        },
      })

      opts.cmdline = {
        enabled = true,
      }

      opts.completion = {
        --   keyword = {
        --     -- 'prefix' will fuzzy match on the text before the cursor
        --     -- 'full' will fuzzy match on the text before *and* after the cursor
        --     -- example: 'foo_|_bar' will match 'foo_' for 'prefix' and 'foo__bar' for 'full'
        --     range = "full",
        --   },
        menu = {
          border = "single",
        },
        documentation = {
          auto_show = true,
          window = {
            border = "single",
          },
        },
        -- Displays a preview of the selected item on the current line
        ghost_text = {
          enabled = true,
        },
      }

      opts.snippets = {
        preset = "luasnip", -- Choose LuaSnip as the snippet engine
      }

      -- https://cmp.saghen.dev/configuration/keymap.html#default
      opts.keymap = {
        preset = "default",
        ["<CR>"] = { "accept", "fallback" }, -- Add this line!
        ["<C-y>"] = { "accept" }, -- Keep your working keybind
        ["<Tab>"] = { "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },

        ["<Up>"] = { "select_prev", "fallback" },
        ["<Down>"] = { "select_next", "fallback" },
        ["<C-p>"] = { "select_prev", "fallback" },
        ["<C-n>"] = { "select_next", "fallback" },

        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },

        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide", "fallback" },
      }

      return opts
    end,
  },
}
