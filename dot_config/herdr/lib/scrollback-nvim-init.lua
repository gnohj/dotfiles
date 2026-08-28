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

local CLAUDE_PROMPT_PAT = [[\v^%(\e\[[0-9;]*m)*❯ ]]

local function strip_ansi(line)
  return (line:gsub("\27%[[0-9;]*m", ""))
end

local function pi_background(line)
  return line:match("^\27%[0m\27%[(48;[%d;]+)m ")
end

local function is_plain_pi_line(line, background)
  local prefix = "\27[0m\27[" .. background .. "m "
  if line:sub(1, #prefix) ~= prefix then
    return false
  end
  return line:sub(#prefix + 1):match("^[^\27]*\27%[0m$") ~= nil
end

local function find_prompt_rows(lines)
  local rows = {}
  local row = 1
  while row <= #lines do
    if strip_ansi(lines[row]):match("^❯ ") then
      table.insert(rows, row)
      row = row + 1
    else
      local background = pi_background(lines[row])
      if background and is_plain_pi_line(lines[row], background) and strip_ansi(lines[row]):match("^%s*$") then
        local next_row = row + 1
        local first_content
        while next_row <= #lines and is_plain_pi_line(lines[next_row], background) do
          if not first_content and strip_ansi(lines[next_row]):match("%S") then
            first_content = next_row
          end
          next_row = next_row + 1
        end
        if first_content and strip_ansi(lines[next_row - 1]):match("^%s*$") then
          table.insert(rows, first_content)
          row = next_row
        else
          row = row + 1
        end
      else
        row = row + 1
      end
    end
  end
  return rows
end

local function move_to_prompt(rows, direction)
  local current = vim.api.nvim_win_get_cursor(0)[1]
  if direction < 0 then
    for index = #rows, 1, -1 do
      if rows[index] < current then
        vim.api.nvim_win_set_cursor(0, { rows[index], 0 })
        vim.cmd("normal! zz")
        return
      end
    end
  else
    for _, row in ipairs(rows) do
      if row > current then
        vim.api.nvim_win_set_cursor(0, { row, 0 })
        vim.cmd("normal! zz")
        return
      end
    end
  end
end

-- Called via -c after the buffer loads (VimEnter is unreliable under `nvim -u ... file`).
function HerdrScrollbackView(opts)
  opts = opts or {}
  local buf = vim.api.nvim_get_current_buf()

  local prompt_rows = find_prompt_rows(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
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

  vim.fn.setreg("/", CLAUDE_PROMPT_PAT)
  if #prompt_rows > 0 then
    vim.keymap.set("n", "n", function()
      move_to_prompt(prompt_rows, -1)
    end, { buffer = buf, nowait = true })
    vim.keymap.set("n", "N", function()
      move_to_prompt(prompt_rows, 1)
    end, { buffer = buf, nowait = true })
    if opts.jump then
      vim.api.nvim_win_set_cursor(0, { prompt_rows[#prompt_rows], 0 })
      vim.cmd("normal! zz")
    end
  elseif opts.jump then
    vim.cmd("normal! G")
  end

  -- <C-q> included: the user's :wqa mapping lives in the full config this instance skips.
  for _, key in ipairs({ "<Esc>", "q", "<C-q>" }) do
    vim.keymap.set("n", key, "<cmd>qa!<cr>", { buffer = buf, nowait = true })
  end
end
