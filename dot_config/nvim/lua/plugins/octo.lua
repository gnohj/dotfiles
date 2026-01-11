return {
  "pwntester/octo.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  cmd = { "Octo" },
  opts = {
    enable_builtin = true,
    picker = "snacks",
    mappings = {
      review_diff = {
        select_next_entry = {
          lhs = "<Tab>",
          desc = "move to next changed file",
        },
        select_prev_entry = {
          lhs = "<S-Tab>",
          desc = "move to previous changed file",
        },
        close_review_tab = {
          lhs = "<esc>",
          desc = "close review tab",
        },
        add_review_comment = {
          lhs = "<leader>ca",
          desc = "add review comment",
          mode = { "n", "x" },
        },
        add_review_suggestion = {
          lhs = "<leader>sa",
          desc = "add review suggestion",
          mode = { "n", "x" },
        },
        next_thread = {
          lhs = "]t",
          desc = "next comment thread",
        },
        prev_thread = {
          lhs = "[t",
          desc = "previous comment thread",
        },
        submit_review = {
          lhs = "<leader>vs",
          desc = "submit review",
        },
        discard_review = {
          lhs = "<leader>vd",
          desc = "discard review",
        },
      },
    },
  },
  config = function(_, opts)
    require("octo").setup(opts)

    -- Add <esc> to close octo buffers (issue/PR views)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "octo",
      callback = function(event)
        vim.keymap.set("n", "<esc>", function()
          -- Close window and delete buffer
          local buf = vim.api.nvim_get_current_buf()
          local wins = vim.fn.win_findbuf(buf)
          for _, win in ipairs(wins) do
            if vim.api.nvim_win_is_valid(win) then
              vim.api.nvim_win_close(win, true)
            end
          end
          if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end, {
          buffer = event.buf,
          desc = "Close Octo buffer",
        })
      end,
    })
  end,
  keys = {
    { "<leader>oO", "<cmd>Octo<cr>", desc = "Octo" },
  },
}
