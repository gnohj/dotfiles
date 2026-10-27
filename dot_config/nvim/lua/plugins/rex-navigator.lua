local function in_bare_rex()
  return vim.env.REX_BLOCK ~= nil
    and vim.env.HERDR_SOCKET_PATH == nil
    and vim.env.TMUX == nil
end

local function ss(fn)
  return function()
    require("smart-splits")[fn]()
  end
end

return {
  {
    "smart-splits-nvim/smart-splits.nvim",
    version = "^3.0.0",
    cond = in_bare_rex,
    dependencies = { { "rawnly/smart-splits-backend-rex", opts = {} } },
    opts = { mux = { backend = "smart-splits-backend-rex" } },
    keys = {
      { "<c-h>", ss("move_cursor_left"), desc = "Navigate left (vim/rex)" },
      { "<c-j>", ss("move_cursor_down"), desc = "Navigate down (vim/rex)" },
      { "<c-k>", ss("move_cursor_up"), desc = "Navigate up (vim/rex)" },
      { "<c-l>", ss("move_cursor_right"), desc = "Navigate right (vim/rex)" },
      { "<c-left>", ss("resize_left"), desc = "Resize left (vim/rex)" },
      { "<c-down>", ss("resize_down"), desc = "Resize down (vim/rex)" },
      { "<c-up>", ss("resize_up"), desc = "Resize up (vim/rex)" },
      { "<c-right>", ss("resize_right"), desc = "Resize right (vim/rex)" },
    },
  },
}
