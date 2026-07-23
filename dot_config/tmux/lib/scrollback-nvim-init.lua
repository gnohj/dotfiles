-- Isolated nvim for the tmux prefix+e scrollback viewer: fast (no user plugins/dashboard/LSP), baleia colors, transparent + chromeless, cursor at bottom, yank to clipboard via tmux.

vim.o.termguicolors = true

-- Chromeless: no statusline, ruler, numbers, signcolumn, or ~ end-of-buffer marks.
vim.o.laststatus = 0
vim.o.ruler = false
vim.o.showcmd = false
vim.o.showmode = false
vim.o.number = false
vim.o.relativenumber = false
vim.o.signcolumn = "no"
vim.o.swapfile = false
vim.opt.fillchars = { eob = " " }

-- Yank via tmux (load-buffer -w emits OSC52 from tmux's context) - reliable from inside a popup where nvim's own OSC52 gets swallowed.
if vim.env.TMUX then
  vim.g.clipboard = {
    name = "tmux",
    copy = {
      ["+"] = { "tmux", "load-buffer", "-w", "-" },
      ["*"] = { "tmux", "load-buffer", "-w", "-" },
    },
    paste = {
      ["+"] = { "tmux", "save-buffer", "-" },
      ["*"] = { "tmux", "save-buffer", "-" },
    },
    cache_enabled = 0,
  }
  vim.o.clipboard = "unnamedplus"
end

-- Load baleia straight from its lazy install path (no lazy.nvim involved here).
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/baleia.nvim")

-- Called via -c after the capture buffer loads (VimEnter is unreliable under `nvim -u ... file`).
function ScrollbackView()
  local buf = vim.api.nvim_get_current_buf()

  local ok_baleia, baleia = pcall(require, "baleia")
  if ok_baleia then
    baleia.setup({}).once(buf)
  end

  -- Transparent background (show the terminal/theme behind the popup).
  for _, group in ipairs({ "Normal", "NormalNC", "EndOfBuffer", "SignColumn" }) do
    vim.api.nvim_set_hl(0, group, { bg = "none" })
  end

  -- Throwaway view: don't write back to the temp file, no modified nag.
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modified = false

  vim.cmd("normal! G")

  vim.keymap.set("n", "<Esc>", "<cmd>qa!<cr>", { buffer = buf, nowait = true })
  vim.keymap.set("n", "q", "<cmd>qa!<cr>", { buffer = buf, nowait = true })
end
