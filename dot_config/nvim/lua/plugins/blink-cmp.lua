return {
  {
    "saghen/blink.cmp",
    enabled = true,
    dependencies = {
      "moyiz/blink-emoji.nvim",
      "Kaiser-Yang/blink-cmp-dictionary",
      "fang2hou/blink-copilot",
      "marcoSven/blink-cmp-yanky",
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
          "lsp",
          "path",
          "snippets",
          "buffer",
          "emoji",
          "dictionary",
          "yank",
          -- "dadbod",
          -- "copilot",
        },
        per_filetype = {
          lua = { inherit_defaults = true, "lazydev" },
        },
        providers = {
          yank = {
            name = "yank",
            module = "blink-yanky",
            opts = {
              minLength = 5,
              onlyCurrentFiletype = true,
              trigger_characters = { '"' },
              kind_icon = "󰅍",
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
            score_offset = 100, -- Trust your LSP, it knows your codebase
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
            score_offset = 95, -- Very high, but not forcing - let fuzzy matching work
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
          copilot = {
            name = "copilot",
            enabled = true,
            module = "blink-copilot",
            min_keyword_length = 6,
            score_offset = -100, -- the higher the number, the higher the priority
            async = true,
          },
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
        preset = "luasnip", -- Use LuaSnip as the snippet engine
      }

      -- https://cmp.saghen.dev/configuration/keymap.html#default
      opts.keymap = {
        preset = "default",
        ["<CR>"] = { "fallback" }, -- Only fallback, don't accept completion
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
