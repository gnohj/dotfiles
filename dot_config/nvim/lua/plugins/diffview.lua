-- Helper to open command in a new tmux window with zen disabled
local function open_in_tmux(cmd, window_name)
  local cwd = vim.fn.getcwd()
  local shell_cmd = string.format([[nvim --cmd "let g:zen_disabled=1" -c "%s"]], cmd)
  vim.fn.jobstart({ "tmux", "new-window", "-n", window_name, "-c", cwd, shell_cmd }, { detach = true })
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
        open_in_tmux("DiffviewFileHistory " .. vim.fn.fnameescape(file), "📜")
      end,
      desc = "File history (tmux)",
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
