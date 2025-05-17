if vim.g.vscode then
  return {}
end

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
        bg = "#7aa2f7", -- Tokyo Night blue (more visible than pink)
        fg = "#15161e", -- Very dark for contrast
        bold = true,
      })

      vim.api.nvim_set_hl(0, "FlashBackdrop", {
        fg = "#565f89", -- Tokyo Night comment color for dimmed text
      })

      vim.api.nvim_set_hl(0, "FlashMatch", {
        bg = "#3d59a1", -- Tokyo Night selection blue
        fg = "#c0caf5", -- Tokyo Night foreground
      })

      vim.api.nvim_set_hl(0, "FlashCurrent", {
        bg = "#ff9e64", -- Tokyo Night orange (keeping this as it works well)
        fg = "#1f2335", -- Tokyo Night dark background
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
