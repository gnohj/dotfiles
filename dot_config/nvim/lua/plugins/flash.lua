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
            if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)):match("BqfPreview") then
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
      },
      highlight = {
        backdrop = true,
        matches = true,
        priority = 5000,
      },
    },
    config = function(_, opts)
      require("flash").setup(opts)

      -- Set Tokyo Night themed highlights for flash
      vim.api.nvim_set_hl(0, "FlashLabel", {
        bg = colors["gnohj_color08"], -- Tokyo Night blue (more visible than pink)
        fg = colors["gnohj_color10"], -- Very dark for contrast
        bold = true,
      })

      vim.api.nvim_set_hl(0, "FlashBackdrop", {
        fg = colors["gnohj_color09"], -- Tokyo Night comment color for dimmed text
      })

      vim.api.nvim_set_hl(0, "FlashMatch", {
        bg = colors["gnohj_color16"], -- Tokyo Night selection blue
        fg = colors["gnohj_color14"], -- Tokyo Night foreground
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
