-- Sesh sessions on Rex: the ctrl+t picker, and one palette action per sesh.toml entry.
local c = require("common")
local sessions = require("sessions")

local M = {}

local function dev_windows(dir, startup)
  local options = { cwd = dir }
  if startup ~= nil then options.initial_input = startup .. "\n" end
  return { { layout = rex.layout.block{ flavor = c.SHELL, options = options } } }
end

-- Session glyphs from herdr-sesh-layout.sh: pinned names first, then 💻 home, 🌳 linked worktree, 🌿 repo, 📁 anything else.
local NAME_GLYPHS = { jira = "🔷", github = "🐙", browser = "🌐", fm = "🚢", hermes = "🤖", tasks = "📝", home = c.HOME:match("^/Users/") and "🍎" or "🐧" }

local function session_glyph(name, dir)
  if NAME_GLYPHS[name] ~= nil then return NAME_GLYPHS[name] end
  if name:match("^sm%-") then return "🚢" end
  if dir == c.HOME then return "💻" end
  local d = dir
  while d ~= "" do
    local f = io.open(d .. "/.git")
    if f ~= nil then
      local line = f:read("*l")
      f:close()
      if line ~= nil and line:match("/worktrees/") then return "🌳" end
      return "🌿"
    end
    d = d:match("^(.*)/[^/]*$") or ""
  end
  return "📁"
end

local function open_session(name, dir, startup, background)
  local label = session_glyph(name, dir) .. " " .. name
  local list, err = rex.call("session.list")
  c.fail(err)
  for _, s in ipairs(list.sessions or {}) do
    if s.label == label or s.label == name or s.label:match("^[\128-\255]+ (.+)$") == name then
      if s.label ~= label then rex.call("session.set_label", { session_id = s.session_id, label = label }) end
      if not background then rex.client.queue("session.select", { session_id = s.session_id }) end
      return
    end
  end
  local s, cerr = rex.call("session.create", { label = label, initial_windows = dev_windows(dir, startup) })
  c.fail(cerr)
  rex.call("session.attach", { session_id = s.session_id })
  local view = rex.call("session.view", { session_id = s.session_id })
  if view ~= nil and view.windows[1] ~= nil then
    rex.call("session.focus_window", { session_id = s.session_id, window_id = view.windows[1].window_id })
  end
  if not background then rex.client.queue("session.select", { session_id = s.session_id }) end
end

-- sesh.toml entries, read from the same file sesh and herdr-sesh.sh use.
local function read_sesh(path)
  local f = io.open(path)
  if f == nil then return {} end
  local entries, cur = {}, nil
  for line in f:lines() do
    if line:match("^%s*%[%[session%]%]") then
      cur = {}
      table.insert(entries, cur)
    elseif line:match("^%s*%[") then
      cur = nil
    elseif cur ~= nil then
      local k, v = line:match('^%s*([%w_]+)%s*=%s*"(.*)"%s*$')
      if k ~= nil then cur[k] = v end
    end
  end
  f:close()
  return entries
end

local function entry_action(e, dir, action)
  rex.action{
    name = action,
    title = "Sesh: " .. e.name .. (e.alias and ("  (" .. e.alias .. ")") or ""),
    category = "Sesh",
    keywords = (e.alias or "") .. " " .. dir,
    run = function(ctx, args)
      sessions.leave_session(ctx)
      if e.rex_host == nil and ctx.server == nil then
        open_session(e.name, dir, e.startup_command, false)
        return
      end
      -- Lua here only reaches the focused session's server, so a pinned entry or a press from another host goes through rex-herdr.
      c.fail(select(2, rex.exec.start({ "/bin/zsh", "-lc", 'exec "$HOME/.local/bin/mux/rex/rex-herdr" layout --entry "$0"', e.name },
                                      { detach = true, env = c.REX_ENV })))
    end,
  }
end

-- Returns each entry's alias as a key sequence ("a>b") beside its action, for the caller to bind.
function M.setup()
  -- herdr-new-workspace.sh: session at the focused pane's cwd, labelled by its basename.
  rex.action{
    name = "new_session_here",
    title = "New Session at Pane Directory",
    category = "Sessions",
    run = function(ctx, args)
      local cwd = c.block_cwd(ctx.block_id)
      sessions.leave_session(ctx)
      open_session(cwd:match("([^/]+)/?$") or "home", cwd)
    end,
  }

  -- Called by rex-herdr and `mux session`; an empty startup means a plain shell, background="1" builds it unselected.
  rex.action{
    name = "sesh_open",
    title = "Open Sesh Session",
    category = "Sesh",
    args = { label = "string", dir = "string", startup = "string?", background = "string?" },
    run = function(ctx, args)
      local startup = args.startup
      if startup == "" then startup = nil end
      open_session(args.label, (args.dir:gsub("^~", c.HOME)), startup, args.background == "1")
    end,
  }

  -- herdr-sesh.sh itself as a floating popup, 48% x 70% centred like herdr's, its herdr calls answered by rex-herdr.
  rex.action{
    name = "sesh_picker",
    title = "Sesh Picker",
    category = "Sesh",
    run = function(ctx, args)
      sessions.leave_session(ctx)
      -- rex-herdr marks REX_POPUP_MOVED when it switches focus; otherwise focus returns to the pane the picker opened from.
      local run = 'm=$(mktemp); REX_POPUP_MOVED="$m" "$HOME/.local/bin/mux/herdr/herdr-sesh.sh"; [ -s "$m" ] || "${REX_BIN_DIR:+$REX_BIN_DIR/}rex" do -s "$REX_SESSION" -b "$REX_BLOCK" popup_return source="$0" >/dev/null 2>&1; rm -f "$m"'
      c.popup(ctx, 0.26, 0.15, { "/bin/sh", "-c", run, ctx.block_id }, { self_sized = true, label = "sesh" })
    end,
  }

  -- rex.toml adds the Mac's Rex-only entries that open on another host; sesh itself never reads it.
  local entries = read_sesh(c.HOME .. "/.config/sesh/sesh.toml")
  for _, e in ipairs(read_sesh(c.HOME .. "/.config/sesh/rex.toml")) do table.insert(entries, e) end

  local aliases = {}
  for _, e in ipairs(entries) do
    if e.name ~= nil and e.path ~= nil then
      local dir = e.path:gsub("^~", c.HOME):gsub("(.)/$", "%1")
      local action = "sesh_" .. e.name:lower():gsub("[^%w]", "_")
      entry_action(e, dir, action)
      if e.alias ~= nil then
        table.insert(aliases, { keys = table.concat({ e.alias:lower():match(("(.)"):rep(#e.alias)) }, ">"), action = action })
      end
    end
  end
  return aliases
end

return M
