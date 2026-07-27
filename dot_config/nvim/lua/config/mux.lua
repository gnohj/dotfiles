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

-- Own pane env first (herdr wins: a herdr pane can sit atop a tmux session).
function M.kind()
  if vim.env.HERDR_SOCKET_PATH and vim.env.HERDR_SOCKET_PATH ~= "" then
    return "herdr"
  end
  if vim.env.TMUX and vim.env.TMUX ~= "" then
    return "tmux"
  end
  if probed == nil then
    local out = vim.trim(vim.fn.system({ mux_bin(), "kind" }))
    probed = (vim.v.shell_error == 0 and out ~= "" and out ~= "none") and out or false
  end
  return probed or nil
end

-- Fire-and-forget: the herdr path makes several CLI calls, none worth blocking on.
local function dispatch(args, what)
  if not M.kind() then
    vim.notify("No tmux or herdr session detected - can't " .. what, vim.log.levels.WARN)
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
  dispatch({ "split", "--", opts.cwd or vim.fn.getcwd(), cmd }, "launch " .. cmd)
end

-- Emoji-stripped session name. Memoized: the dashboard asks more than once per render.
local label = nil
function M.session_label()
  if label == nil then
    if not M.kind() then
      label = ""
    else
      local out = vim.fn.system({ mux_bin(), "session-label" })
      label = vim.v.shell_error == 0 and vim.trim(out) or ""
    end
  end
  return label
end

return M
