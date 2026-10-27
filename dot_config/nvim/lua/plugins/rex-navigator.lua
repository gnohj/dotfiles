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

-- Matches Rex's best-fit split: divide the pane along its longer side in pixels.
local function best_fit()
  local res = vim
    .system({
      "rex",
      "--autostart=false",
      "block",
      "call",
      "-b",
      vim.env.REX_BLOCK,
      "size",
    }, { text = true })
    :wait()
  local ok, size = pcall(vim.json.decode, res.stdout or "")
  if res.code ~= 0 or not ok or type(size) ~= "table" then
    return "right"
  end
  local width = size.columns * size.cell_width_px
  local height = size.rows * size.cell_height_px
  return width >= height and "right" or "below"
end

local function rex_split(placement)
  return function()
    local direction = placement == "auto" and best_fit() or placement
    -- rex split skips .zshrc, which exports THEME_TRANSPARENT and the API tokens.
    local cmd = {
      "rex",
      "--autostart=false",
      "split",
      "--split=" .. direction,
      "-c",
      vim.fn.getcwd(),
      "--",
      "env",
      "SKIP_FETCH=1",
      "zsh",
      "-ic",
      'exec nvim "$@"',
      "nvim",
    }
    local file = vim.api.nvim_buf_get_name(0)
    if vim.fn.filereadable(file) == 1 then
      vim.list_extend(cmd, { "+" .. vim.fn.line("."), file })
    end
    vim.system(cmd, { text = true }, function(res)
      if res.code ~= 0 then
        vim.schedule(function()
          vim.notify(
            "rex split failed: " .. vim.trim(res.stderr or ""),
            vim.log.levels.WARN
          )
        end)
      end
    end)
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
      { "<c-w>v", rex_split("auto"), desc = "Split best fit (rex pane)" },
      { "<c-w>s", rex_split("below"), desc = "Split below (rex pane)" },
      { "<c-w><c-v>", rex_split("auto"), desc = "Split best fit (rex pane)" },
      { "<c-w><c-s>", rex_split("below"), desc = "Split below (rex pane)" },
    },
  },
}
