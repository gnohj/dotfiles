-- Mirrors nvim's visual selection into herdr-annotate's handoff file so capture needs no yank.

if not vim.env.HERDR_SOCKET_PATH or vim.env.HERDR_SOCKET_PATH == "" then
  return nil
end

local tmp = vim.env.XDG_RUNTIME_DIR
if not tmp or tmp == "" then
  tmp = vim.uv.os_tmpdir()
end
local dir = tmp .. "/herdr-annotate-" .. vim.uv.getuid()
local file = dir .. "/selection"
local timer = vim.uv.new_timer()

local function in_visual()
  local mode = vim.fn.mode()
  return mode == "v" or mode == "V" or mode == "\22"
end

local function selected_lines()
  local ok, lines = pcall(vim.fn.getregion, vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
  return ok and lines or nil
end

local function write_selection()
  if not in_visual() then
    return
  end
  local lines = selected_lines()
  if not lines then
    return
  end
  vim.fn.mkdir(dir, "p", "0700")
  vim.fn.writefile(lines, file)
end

local function clear_selection()
  timer:stop()
  vim.uv.fs_unlink(file)
end

local group = vim.api.nvim_create_augroup("herdr_annotate_handoff", { clear = true })
vim.api.nvim_create_autocmd("ModeChanged", {
  group = group,
  pattern = "*:[vV\22]",
  callback = function()
    write_selection()
    timer:start(5000, 5000, vim.schedule_wrap(write_selection))
  end,
})
vim.api.nvim_create_autocmd("ModeChanged", {
  group = group,
  pattern = "[vV\22]:[^vV\22]*",
  callback = clear_selection,
})
vim.api.nvim_create_autocmd("CursorMoved", { group = group, callback = write_selection })
vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = clear_selection })

-- From the scrollback viewer, capture against the source pane so the tab label is real.
local function capture()
  local source = vim.env.HERDR_SCROLLBACK_SOURCE_PANE
  local lines = source and source ~= "" and selected_lines()
  if lines then
    local job = vim.fn.jobstart({ vim.fn.expand("~/.local/bin/mux/herdr/herdr-annotate-capture.sh"), source }, { detach = true })
    vim.fn.chansend(job, table.concat(lines, "\n"))
    vim.fn.chanclose(job, "stdin")
    return
  end
  write_selection()
  vim.fn.jobstart({ vim.env.HERDR_BIN_PATH or "herdr", "plugin", "action", "invoke", "annotate.capture" }, { detach = true })
end

return { capture = capture }
