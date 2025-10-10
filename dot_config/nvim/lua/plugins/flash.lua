if vim.g.vscode then
  return {}
end

local colors = require("config.colors")

return {
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      jump = { nohlsearch = true },
      prompt = {
        win_config = {
          border = "none",
          -- Place the prompt above the statusline.
          row = -3,
        },
      },
      search = {
        exclude = {
          "flash_prompt",
          "qf",
          function(win)
            -- Floating windows from bqf.
            if
              vim.api
                .nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
                :match("BqfPreview")
            then
              return true
            end
            -- Non-focusable windows.
            return not vim.api.nvim_win_get_config(win).focusable
          end,
        },
      },
      modes = {
        -- Enable flash when searching with ? or /
        -- search = { enabled = true },
        char = {
          enabled = true,
          jump_labels = true,
          keys = { "f", "F", "t", "T", ";", "," },
          char_actions = function(motion)
            return {
              [";"] = "next",
              [","] = "prev",
            }
          end,
        },
      },
      highlight = {
        backdrop = true,
        matches = true,
        priority = 5000,
      },
    },
    config = function(_, opts)
      require("flash").setup(opts)
      vim.api.nvim_set_hl(0, "FlashLabel", {
        bg = colors["gnohj_color04"],
        fg = colors["gnohj_color10"],
        bold = true,
      })
      vim.api.nvim_set_hl(0, "FlashBackdrop", {
        fg = colors["gnohj_color09"],
      })
      vim.api.nvim_set_hl(0, "FlashMatch", {
        bg = colors["gnohj_color11"],
        fg = colors["gnohj_color24"],
      })
    end,
    keys = {
      {
        "s",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump()
        end,
        desc = "Flash",
      },
      {
        "r",
        mode = "o",
        function()
          require("flash").treesitter_search()
        end,
        desc = "Treesitter Search",
      },
      {
        "R",
        mode = "o",
        function()
          require("flash").remote()
        end,
        desc = "Remote Flash",
      },
    },
  },
}
