-- Open a diffview command in a new multiplexer window (tmux or herdr) with zen
-- disabled. The window's nvim self-quits on close via the view_closed hook.
local function open_in_window(cmd, window_name)
  local shell_cmd = string.format([[nvim --cmd "let g:zen_disabled=1" -c "%s"]], cmd)
  require("config.mux").new_window(shell_cmd, { name = window_name })
end

return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewFileHistory", "DiffviewOpen" },
  keys = {
    {
      "<leader>gf",
      function()
        local file = vim.fn.expand("%:p")
        if file == "" then
          vim.notify("No file to show history for", vim.log.levels.WARN)
          return
        end
        open_in_window("DiffviewFileHistory " .. vim.fn.fnameescape(file), "📜")
      end,
      desc = "File history (window)",
    },
  },
  opts = {
    keymaps = {
      file_history_panel = {
        { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
        { "n", "<esc>", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
      },
      view = {
        { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
        { "n", "<esc>", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
        { "n", "<tab>", "<cmd>DiffviewFocusFiles<cr>", { desc = "Focus file panel" } },
      },
    },
    hooks = {
      -- Quit nvim when diffview closes (since it's in a dedicated tmux window)
      view_closed = function()
        -- Only auto-quit if this is a zen-disabled instance (tmux window)
        if vim.g.zen_disabled then
          vim.cmd("qa")
        end
      end,
    },
  },
}
