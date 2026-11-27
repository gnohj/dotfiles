-- Reports this nvim to Rex's program resume (OSC 7577): with files open, as `nvim -S <session file>` so buffers and splits come back; otherwise bare or with its -c arguments. init.lua's resume.trust rules decide.
local token = vim.env.OSC7577_TOKEN
vim.env.OSC7577_TOKEN = nil
if not token or token == "" then
  return
end

local dir = vim.fn.stdpath("state") .. "/rex-resume"
local pid = vim.uv.os_getppid()
local session = ("%s/%d.vim"):format(dir, pid)
local reported, last_time = nil, 0

local function bare_argv()
  local argv, i = { "nvim" }, 2
  while i <= #vim.v.argv do
    local arg = vim.v.argv[i]
    if arg == "--cmd" then
      i = i + 1
    elseif arg == "-c" then
      local value = vim.v.argv[i + 1]
      if not value then
        return nil
      end
      vim.list_extend(argv, { "-c", value })
      i = i + 1
    elseif arg ~= "--embed" then
      return nil
    end
    i = i + 1
  end
  return argv
end

local function report(argv)
  local key = table.concat(argv, "\0")
  if key == reported then
    return
  end
  reported = key
  last_time = math.max(os.time(), last_time + 1)
  local encoded = vim.tbl_map(vim.base64.encode, argv)
  local body = ("pid=%d:time=%d:argv=%s"):format(
    pid,
    last_time,
    table.concat(encoded, ",")
  )
  io.stderr:write(
    "\27]7577;"
      .. body
      .. ":mac="
      .. vim.fn.sha256(body .. ":" .. token)
      .. "\27\\"
  )
end

local function has_files()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.bo[buf].buflisted
      and vim.bo[buf].buftype == ""
      and vim.api.nvim_buf_get_name(buf) ~= ""
    then
      return true
    end
  end
  return false
end

local function save()
  if has_files() then
    vim.fn.mkdir(dir, "p")
    if pcall(vim.cmd, "silent mksession! " .. vim.fn.fnameescape(session)) then
      report({ "nvim", "-S", session })
    end
    return
  end
  local argv = bare_argv()
  if argv then
    report(argv)
  end
end

local timer = assert(vim.uv.new_timer())
local function save_soon()
  timer:stop()
  timer:start(1000, 0, vim.schedule_wrap(save))
end

local group = vim.api.nvim_create_augroup("rex_resume", { clear = true })

vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  once = true,
  callback = function()
    -- A resumed nvim was started from the previous instance's session file; this one writes its own.
    local loaded = vim.v.this_session
    save()
    if
      loaded ~= ""
      and loaded ~= session
      and vim.startswith(loaded, dir .. "/")
    then
      os.remove(loaded)
    end
    local week_ago = os.time() - 7 * 24 * 3600
    for name in vim.fs.dir(dir) do
      local stat = vim.uv.fs_stat(dir .. "/" .. name)
      if stat and stat.mtime.sec < week_ago then
        os.remove(dir .. "/" .. name)
      end
    end
  end,
})

vim.api.nvim_create_autocmd({
  "BufAdd",
  "BufDelete",
  "BufWritePost",
  "WinNew",
  "WinClosed",
  "TabNew",
  "TabClosed",
  "DirChanged",
  "CursorHold",
}, {
  group = group,
  callback = save_soon,
})

vim.api.nvim_create_autocmd(
  { "FocusLost", "VimSuspend" },
  { group = group, callback = save }
)

-- Quitting on purpose leaves nothing to resume; a server restart takes the terminal away without ExitPre, and that file must stay.
local quitting = false
vim.api.nvim_create_autocmd("ExitPre", {
  group = group,
  callback = function()
    quitting = true
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    timer:stop()
    if quitting then
      os.remove(session)
    end
  end,
})
