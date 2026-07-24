-- Isolated nvim for the herdr scrollback viewers; port of tmux/lib/scrollback-nvim-init.lua. Isolation is the point: loading the full user config is what made this opaque, since the colorscheme paints Normal.

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

-- Set explicitly: this instance never loads config/options.lua, and nvim would otherwise auto-pick wl-copy and yank into the VPS clipboard instead of the Mac's.
vim.o.clipboard = "unnamedplus"
if vim.fn.has("mac") == 0 then
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if ok then
    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
    }
  end
end

-- Load baleia straight from its lazy install path (no lazy.nvim involved here).
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/baleia.nvim")

-- Leading SGR tolerated because --format ansi colors the line before the glyph; anchored at column 0 because Claude emits bare "❯ " mid-response.
local PROMPT_PAT = [[\v^%(\e\[[0-9;]*m)*❯ ]]

-- Called via -c after the buffer loads (VimEnter is unreliable under `nvim -u ... file`).
function HerdrScrollbackView(opts)
  opts = opts or {}
  local buf = vim.api.nvim_get_current_buf()

  local ok_baleia, baleia = pcall(require, "baleia")
  if ok_baleia then
    baleia.setup({}).once(buf)
  end

  -- Transparent background (show the herdr popup / theme behind it).
  for _, group in ipairs({ "Normal", "NormalNC", "EndOfBuffer", "SignColumn" }) do
    vim.api.nvim_set_hl(0, group, { bg = "none" })
  end

  -- Throwaway view: don't write back to the temp file, no modified nag.
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modified = false

  vim.cmd("normal! G")

  -- Seeded in BOTH modes: a fresh popup starts with an empty @/, so `n` raised E35 instead of walking prompts.
  vim.fn.setreg("/", PROMPT_PAT)
  if opts.jump then
    if vim.fn.search(PROMPT_PAT, "bW") == 0 then
      vim.cmd("normal! G")
    end
    vim.cmd("normal! zz")
  end
  -- Deferred because something after load resets v:searchforward, leaving `n` walking forward.
  vim.schedule(function()
    vim.v.searchforward = 0
  end)

  -- <C-q> included: the user's :wqa mapping lives in the full config this instance skips.
  for _, key in ipairs({ "<Esc>", "q", "<C-q>" }) do
    vim.keymap.set("n", key, "<cmd>qa!<cr>", { buffer = buf, nowait = true })
  end
end
