-- vim-herdr-navigation — Neovim side (self-contained, robust + diagnosable).
--
-- Seamless <C-h/j/k/l> across Neovim splits and herdr panes: move within nvim,
-- and at a split edge cross into the neighbouring herdr pane via
-- `herdr pane focus --direction <dir> --current`.
--
-- Why not the plugin's own editor/nvim.lua? Two reasons its edge handoff can fail
-- silently under herdr:
--   1. it calls bare `herdr` — but pane shells DON'T export HERDR_BIN_PATH, and
--      nvim's $PATH at system() time may miss the nix dir where herdr lives, so
--      the call fails and it discards the error → nothing happens.
--   2. it discards stderr/exit, so you never see why.
-- Here we resolve the binary robustly (HERDR_BIN_PATH → exepath → "herdr") and
-- vim.notify on any non-zero exit, so a failure is visible, not silent.
-- `--current` resolves server-side from HERDR_SOCKET_PATH (verified), so no
-- dependency on HERDR_PANE_ID. Uses the `keys=` pattern (like tmux-navigator.lua)
-- for correct keymap priority. Gated to herdr only; tmux-navigator owns off-herdr.

local function resolve_herdr()
  local h = vim.env.HERDR_BIN_PATH
  if h == nil or h == "" then
    h = vim.fn.exepath("herdr")
  end
  if h == "" then
    h = "herdr"
  end
  return h
end

local function nav(wincmd, dir)
  local prev = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. wincmd)
  if vim.api.nvim_get_current_win() ~= prev then
    return -- moved within Neovim
  end
  -- At a split edge: cross into the neighbouring herdr pane.
  local herdr = resolve_herdr()
  local out = vim.fn.system({ herdr, "pane", "focus", "--direction", dir, "--current" })
  if vim.v.shell_error ~= 0 then
    vim.notify(
      ("herdr nav %s failed (exit %d): %s  [bin=%s]"):format(dir, vim.v.shell_error, (out or ""):gsub("%s+$", ""), herdr),
      vim.log.levels.WARN
    )
  end
end

return {
  {
    "paulbkim-dev/vim-herdr-navigation",
    cond = function()
      return vim.env.HERDR_SOCKET_PATH ~= nil
    end,
    keys = {
      { "<c-h>", function() nav("h", "left") end, desc = "Navigate left (vim/herdr)" },
      { "<c-j>", function() nav("j", "down") end, desc = "Navigate down (vim/herdr)" },
      { "<c-k>", function() nav("k", "up") end, desc = "Navigate up (vim/herdr)" },
      { "<c-l>", function() nav("l", "right") end, desc = "Navigate right (vim/herdr)" },
    },
  },
}
