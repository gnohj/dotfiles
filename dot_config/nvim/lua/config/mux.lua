-- A shim over the `mux` dispatcher; only kind() stays in-process, for dashboard render.

local M = {}

-- $MUX override mirrors the shell callers' `${MUX:-...}`, for tests.
local function mux_bin()
  local m = vim.env.MUX
  if m and m ~= "" then
    return m
  end
  return vim.fn.expand("~/.local/bin/mux/mux")
end

-- `false` = probed and found nothing; memoized so a bare env doesn't re-probe.
local probed = nil

-- Own pane env first, then the `mux kind` probe.
function M.kind()
  if vim.env.MUX_FORCE_KIND == "rex" or vim.env.MUX_FORCE_KIND == "tmux" then
    return vim.env.MUX_FORCE_KIND
  end
  if
    vim.env.TERM_PROGRAM == "rex"
    and vim.env.REX_BLOCK
    and vim.env.REX_BLOCK ~= ""
  then
    return "rex"
  end
  if vim.env.TMUX and vim.env.TMUX ~= "" then
    return "tmux"
  end
  if probed == nil then
    local out = vim.trim(vim.fn.system({ mux_bin(), "kind" }))
    probed = (vim.v.shell_error == 0 and out ~= "" and out ~= "none") and out
      or false
  end
  return probed or nil
end

-- Fire-and-forget: the dispatcher makes several CLI calls, none worth blocking on.
local function dispatch(args, what)
  if not M.kind() then
    vim.notify(
      "No Rex or tmux session detected - can't " .. what,
      vim.log.levels.WARN
    )
    return
  end
  local cmd = { mux_bin() }
  vim.list_extend(cmd, args)
  vim.fn.jobstart(cmd, { detach = true })
end

-- Open shell-command `cmd` in a new focused window/tab. opts: { name, cwd }
function M.new_window(cmd, opts)
  opts = opts or {}
  local name = opts.name or ""
  dispatch(
    { "window", "--", name, opts.cwd or vim.fn.getcwd(), cmd },
    "open " .. (name ~= "" and name or "window")
  )
end

-- Open `cmd` in a side split, focused; nvim stays the dominant pane.
function M.agent_split(cmd, opts)
  opts = opts or {}
  dispatch(
    { "split", "--", opts.cwd or vim.fn.getcwd(), cmd },
    "launch " .. cmd
  )
end

-- Emoji-stripped session name. Memoized: the dashboard asks more than once per render.
local label = nil

local function label_cache_file()
  local kind = M.kind()
  local id = kind == "rex" and vim.env.REX_SESSION
  if not id or id == "" then
    return nil
  end
  local key = (kind .. "_" .. id):gsub("[^%w%-]", "_")
  return vim.fn.stdpath("cache") .. "/mux_session_label/" .. key
end

local function read_cached_label(file)
  if not file or vim.fn.filereadable(file) == 0 then
    return nil
  end
  return vim.fn.readfile(file, "", 1)[1]
end

local function store_label(file, value)
  vim.fn.mkdir(vim.fs.dirname(file), "p")
  vim.fn.writefile({ value }, file)
end

local function refresh_label(file)
  pcall(
    vim.system,
    { mux_bin(), "session-label" },
    { text = true, timeout = 10000 },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        return
      end
      local fresh = vim.trim(result.stdout or "")
      if fresh ~= label then
        label = fresh
        store_label(file, fresh)
      end
    end)
  )
end

-- A cached label answers at once and is re-checked after the first paint.
function M.session_label()
  if label ~= nil then
    return label
  end
  if not M.kind() then
    label = ""
    return label
  end
  local file = label_cache_file()
  local cached = read_cached_label(file)
  if cached then
    label = cached
    vim.defer_fn(function()
      refresh_label(file)
    end, 100)
    return label
  end
  local out = vim.fn.system({ mux_bin(), "session-label" })
  local ok = vim.v.shell_error == 0
  label = ok and vim.trim(out) or ""
  if ok and file then
    store_label(file, label)
  end
  return label
end

return M
