local function in_bare_rex()
  return vim.env.REX_BLOCK ~= nil
    and vim.env.HERDR_SOCKET_PATH == nil
    and vim.env.TMUX == nil
end

local function resolve_rex()
  local dir = vim.env.REX_BIN_DIR
  if dir ~= nil and dir ~= "" and vim.fn.executable(dir .. "/rex") == 1 then
    return dir .. "/rex"
  end
  local found = vim.fn.exepath("rex")
  return found ~= "" and found or "rex"
end

local function nav(wincmd, dir)
  local prev = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. wincmd)
  if vim.api.nvim_get_current_win() ~= prev then
    return
  end
  local rex = resolve_rex()
  local out = vim.fn.system({ rex, "focus", dir })
  if vim.v.shell_error ~= 0 then
    vim.notify(
      ("rex nav %s failed (exit %d): %s  [bin=%s]"):format(
        dir,
        vim.v.shell_error,
        (out or ""):gsub("%s+$", ""),
        rex
      ),
      vim.log.levels.WARN
    )
  end
end

return {
  {
    name = "rex-navigator",
    dir = vim.fn.stdpath("config"),
    virtual = true,
    cond = in_bare_rex,
    keys = {
      {
        "<c-h>",
        function()
          nav("h", "left")
        end,
        desc = "Navigate left (vim/rex)",
      },
      {
        "<c-j>",
        function()
          nav("j", "down")
        end,
        desc = "Navigate down (vim/rex)",
      },
      {
        "<c-k>",
        function()
          nav("k", "up")
        end,
        desc = "Navigate up (vim/rex)",
      },
      {
        "<c-l>",
        function()
          nav("l", "right")
        end,
        desc = "Navigate right (vim/rex)",
      },
    },
  },
}
