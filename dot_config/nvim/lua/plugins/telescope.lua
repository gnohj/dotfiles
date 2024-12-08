if vim.g.vscode then
  return {}
end

return {
  {
    "nvim-telescope/telescope.nvim",
    opts = function()
      return {
        defaults = {
          require("telescope").setup({
            pickers = {
              live_grep = {
                -- file_ignore_patterns = { "node_modules", ".git" },
                additional_args = function(_)
                  return { "--hidden" }
                end,
              },
              find_files = {
                -- file_ignore_patterns = { "node_modules", ".git" },
                hidden = true,
                find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*", "--sortr=modified" },
              },
            },
          }),
          path_display = {
            filename_first = {
              reverse_directories = true,
            },
          },
          mappings = {
            n = {
              ["d"] = require("telescope.actions").delete_buffer,
              ["q"] = require("telescope.actions").close,
            },
            i = {
              ["<esc>"] = require("telescope.actions").close,
            },
          },

          layout_config = {
            vertical = { width = 0.5 },
            height = 50,
            width = vim.o.columns,
          },
        },
      }
    end,

    keys = {
      {
        "<leader>fF",
        function()
          require("telescope").extensions.frecency.frecency(require("telescope.themes").get_ivy({
            layout_config = {
              preview_width = 0.7,
              height = 0.7,
            },
            hidden = true,
          }))
        end,
        desc = "Find Files (Entire System)",
      },
      {
        "<leader>ff",
        function()
          local cwd = vim.fn.getcwd()
          require("telescope").extensions.frecency.frecency(require("telescope.themes").get_ivy({
            workspace = "CWD",
            cwd = cwd,
            prompt_title = "FRECENCY " .. cwd,
            layout_config = {
              preview_width = 0.7,
              height = 0.7,
            },
          }))
        end,
        desc = "Find Files (Root Dir)",
      },
      {
        "<leader>se",
        function()
          local cwd = vim.fn.getcwd()
          local egrep_actions = require("telescope._extensions.egrepify.actions")
          local telescope = require("telescope")
          local ivy_theme = require("telescope.themes").get_ivy({
            layout_config = {
              preview_width = 0.7,
              height = 0.7,
            },
          })

          -- Merge ivy theme options with egrepify settings
          local egrepify_opts = vim.tbl_extend("force", ivy_theme, {
            vimgrep_arguments = {
              "rg",
              "--no-heading",
              "--with-filename",
              "--line-number",
              "--column",
              "--smart-case",
              "--hidden",
              "--glob",
              "!**/node_modules/*",
              "--hidden",
              "--glob",
              "!**/.git/*",
              "--hidden",
              "--glob",
              "!pnpm-lock.yaml",
            },
            lnum_hl = "LineNr",
            prefixes = {
              ["!"] = {
                flag = "invert-match",
              },
              ["^"] = false,
              ["#"] = {
                flag = "glob",
                cb = function(input)
                  return string.format([[*.{%s}]], input)
                end,
              },
              [">"] = {
                flag = "glob",
                cb = function(input)
                  return string.format([[**/{%s}*/**]], input)
                end,
              },
              ["&"] = {
                flag = "glob",
                cb = function(input)
                  return string.format([[*{%s}*]], input)
                end,
              },
            },
            cwd = cwd,
            mappings = {
              i = {
                ["<C-z>"] = egrep_actions.toggle_prefixes,
                ["<C-a>"] = egrep_actions.toggle_and,
                ["<C-r>"] = egrep_actions.toggle_permutations,
              },
            },
            prompt_title = "  Live Grep (egrepify) " .. cwd,
          })

          telescope.extensions.egrepify.egrepify(egrepify_opts)
        end,
        desc = ":Telescope egrepify (grep interactively with Ivy layout)",
      },
      {
        "<leader>sG",
        function()
          require("telescope.builtin").live_grep(require("telescope.themes").get_ivy({
            layout_config = {
              preview_width = 0.7,
              height = 0.7,
            },
          }))
        end,
        desc = "Grep (cwd)",
      },
      {
        "<leader>sg",
        function()
          require("telescope.builtin").live_grep(
            require("telescope.themes").get_ivy({ root = false, layout_config = { height = 0.7, preview_width = 0.7 } })
          )
        end,
        desc = "Grep (Root Dir)",
      },

      {
        "<leader>gs",
        function()
          require("telescope.builtin").git_status(require("telescope.themes").get_ivy({
            root = false,
            layout_config = {
              height = 0.7,
              preview_width = 0.7,
            },
            initial_mode = "normal", -- Start in normal mode
          }))
        end,
        desc = "Git Status (ivy theme with custom preview size)",
      },

      {
        "<leader><space>",
        "<cmd>e #<cr>",
        desc = "Alternate buffer",
      },

      {
        "<leader>tl",
        "<cmd>TodoTelescope keywords=TODO<cr>",
        desc = "[P]TODO list (Telescope)",
      },

      {
        "<leader>ta",
        "<cmd>TodoTelescope keywords=PERF,HACK,TODO,NOTE,FIX<cr>",
        desc = "[P]TODO list ALL (Telescope)",
      },
    },
  },
}
