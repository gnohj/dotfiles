-- config/mux.lua — multiplexer-agnostic window/split spawning.
--
-- nvim bindings that open a sidecar window (file history, diffs, gh-dash) or a
-- side split (AI agent CLIs) used to shell out to `tmux` directly, so they
-- silently no-op when the outer multiplexer is herdr instead of tmux. This
-- module detects the live multiplexer at call time and dispatches, so the same
-- keymap works whether nvim is running under tmux (the Mac, off-herdr) or under
-- herdr (which owns the tmux sessions itself).
--
-- Detection mirrors herdr-navigator.lua / tmux-navigator.lua: a herdr pane
-- exports HERDR_SOCKET_PATH; a tmux pane exports TMUX. herdr wins when both are
-- set (a herdr pane may sit atop a tmux session).
--
-- tmux vs herdr command model:
--   tmux new-window CMD  runs CMD *as* the window's process, so the window
--                        closes when CMD exits.
--   herdr has no equivalent: `tab create` / `pane split` spawn a persistent
--                        shell, and `pane run` types a command into it. To
--                        mirror tmux's close-on-exit we wrap herdr commands as
--                        "<cmd>; exit" so the shell (and thus the pane/tab)
--                        exits when the command does. (Verified: a bare
--                        `pane run` leaves the tab open; appending `; exit`
--                        closes it.)

local M = {}

function M.kind()
  if vim.env.HERDR_SOCKET_PATH and vim.env.HERDR_SOCKET_PATH ~= "" then
    return "herdr"
  end
  if vim.env.TMUX and vim.env.TMUX ~= "" then
    return "tmux"
  end
  return nil
end

-- Resolve the herdr binary robustly: pane shells don't always export
-- HERDR_BIN_PATH, and nvim's $PATH at system() time may miss the nix dir where
-- herdr lives (same rationale as herdr-navigator.lua).
local function herdr_bin()
  local h = vim.env.HERDR_BIN_PATH
  if h and h ~= "" then
    return h
  end
  local p = vim.fn.exepath("herdr")
  if p ~= "" then
    return p
  end
  return "herdr"
end

-- Run a herdr CLI subcommand (arg list) and return its decoded JSON, or nil on
-- failure (with a notification).
local function herdr_json(args)
  local cmd = { herdr_bin() }
  vim.list_extend(cmd, args)
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify(
      "herdr " .. table.concat(args, " ") .. " failed:\n" .. (out or ""),
      vim.log.levels.ERROR
    )
    return nil
  end
  local ok, data = pcall(vim.json.decode, out)
  if not ok then
    return nil
  end
  return data
end

-- Open `cmd` (a shell command string) in a new focused window/tab.
-- opts: { name = <label/window-name>, cwd = <dir, defaults to cwd> }
function M.new_window(cmd, opts)
  opts = opts or {}
  local cwd = opts.cwd or vim.fn.getcwd()
  local name = opts.name or ""
  local kind = M.kind()

  if kind == "herdr" then
    local data = herdr_json({ "tab", "create", "--cwd", cwd, "--label", name, "--focus" })
    local pane = data and vim.tbl_get(data, "result", "root_pane", "pane_id")
    if not pane then
      vim.notify("herdr: could not resolve new tab's pane", vim.log.levels.ERROR)
      return
    end
    -- Prefix the tab label with its number ("2.📜") so every programmatically
    -- created tab carries its number, matching the sesh-layout tabs. A custom
    -- label otherwise replaces herdr's default number badge.
    local tab_id = vim.tbl_get(data, "result", "tab", "tab_id")
    local num = vim.tbl_get(data, "result", "tab", "number")
    if tab_id and num and name ~= "" then
      vim.fn.system({ herdr_bin(), "tab", "rename", tab_id, num .. "." .. name })
    end
    vim.fn.system({ herdr_bin(), "pane", "run", pane, cmd .. "; exit" })
  elseif kind == "tmux" then
    vim.fn.jobstart(
      { "tmux", "new-window", "-n", name, "-c", cwd, cmd },
      { detach = true }
    )
  else
    vim.notify(
      "No tmux or herdr session detected - can't open " .. (name ~= "" and name or "window"),
      vim.log.levels.WARN
    )
  end
end

-- Count panes in the current herdr tab (for even-ish split sizing). Returns 1 on
-- any failure so the caller falls back to the single-pane ratio.
local function herdr_tab_pane_count()
  local cur = herdr_json({ "pane", "current", "--current" })
  local tab = cur and vim.tbl_get(cur, "result", "tab_id")
  if not tab then
    return 1
  end
  local list = herdr_json({ "pane", "list" })
  local panes = list and vim.tbl_get(list, "result", "panes")
  if type(panes) ~= "table" then
    return 1
  end
  local n = 0
  for _, p in ipairs(panes) do
    if p.tab_id == tab then
      n = n + 1
    end
  end
  return math.max(n, 1)
end

-- Open `cmd` in a side split (to the right of nvim), focused. Used for AI agent
-- CLIs launched from the dashboard.
--
-- tmux: first split (nvim alone) gives the new pane 25%; with 2+ panes it splits
-- then rebalances every pane to equal width via `select-layout even-horizontal`.
-- herdr has no even-horizontal, so it approximates: the new agent pane takes 25%
-- of nvim on the first split, and a third of the current pane on later splits
-- (`--ratio` is the fraction the *current* pane keeps). nvim stays dominant,
-- which is what side-by-side agent work wants.
function M.agent_split(cmd, opts)
  opts = opts or {}
  local cwd = opts.cwd or vim.fn.getcwd()
  local kind = M.kind()

  if kind == "herdr" then
    local ratio = herdr_tab_pane_count() == 1 and 0.75 or 0.66
    local data = herdr_json({
      "pane", "split", "--current",
      "--direction", "right",
      "--ratio", tostring(ratio),
      "--cwd", cwd,
      "--focus",
    })
    local pane = data and vim.tbl_get(data, "result", "pane", "pane_id")
    if not pane then
      vim.notify("herdr: could not resolve split pane", vim.log.levels.ERROR)
      return
    end
    vim.fn.system({ herdr_bin(), "pane", "run", pane, cmd .. "; exit" })
  elseif kind == "tmux" then
    local pane_count = tonumber(vim.fn.system("tmux list-panes | wc -l | tr -d ' '")) or 1
    if pane_count == 1 then
      -- Split atomically at final size (-l 25%) so the agent's TUI reads correct
      -- dimensions on first paint. A post-split resize races the startup render.
      vim.fn.system('tmux split-window -h -l 25% -c "' .. cwd .. '" "' .. cmd .. '"')
    else
      vim.fn.system('tmux split-window -h -c "' .. cwd .. '" "' .. cmd .. '"')
      vim.fn.system("tmux select-layout even-horizontal")
    end
  else
    vim.notify("No tmux or herdr session detected - can't launch " .. cmd, vim.log.levels.WARN)
  end
end

return M
