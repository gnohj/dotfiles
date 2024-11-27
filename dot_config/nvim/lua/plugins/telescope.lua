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
