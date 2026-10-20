-- herdr keymap ported to Rex; terminal chords bind directly, UI toggles persist as app prefs; apply with `rex config reload`.

local TERM = "com.superlogical.terminal"
local SHELL = TERM .. ".shell"
local HOME = os.getenv("HOME")
local STATE_DIR = HOME .. "/.local/state/rex-herdr-keys"
local P = "ctrl+a>"

local function fail(err)
  if err ~= nil then error(err, 0) end
end

local function read_state(name)
  local f = io.open(STATE_DIR .. "/" .. name)
  if f == nil then return nil end
  local v = f:read("*l")
  f:close()
  return v
end

local function write_state(name, value)
  rex.exec({ "mkdir", "-p", STATE_DIR })
  local f = io.open(STATE_DIR .. "/" .. name, "w")
  if f == nil then return end
  f:write(value)
  f:close()
end

local function foreground(block_id)
  local p = rex.block.call(TERM, "process", { block_id = block_id })
  if p == nil then return nil end
  return p.foreground or p.child
end

local function block_cwd(block_id)
  local fg = foreground(block_id)
  if fg ~= nil and fg.cwd ~= nil then return fg.cwd end
  local r = rex.block.call(TERM, "pwd", { block_id = block_id })
  if r ~= nil and r.pwd ~= nil then
    return (r.pwd:gsub("^file://[^/]*", ""))
  end
  return os.getenv("HOME")
end

local function windows()
  local view, err = rex.session.view{}
  fail(err)
  return view
end

-- Prefix and the pass-through for a literal ctrl+a (readline beginning-of-line).
rex.bind(P .. "ctrl+a", "pane.send_key", { key = "ctrl+a" })

-- Tabs (herdr: new_tab, next/previous_tab, close_tab, rename_tab on prefix+%).
rex.bind(P .. "c", "client.tab.new")
rex.bind(P .. "n", "client.tab.next")
rex.bind(P .. "p", "client.tab.previous")
rex.bind("ctrl+tab", "client.tab.next")
rex.bind("ctrl+shift+tab", "client.tab.previous")
rex.bind("ctrl+[Backquote]", "client.tab.previous")
rex.bind(P .. "shift+x", "client.tab.close")
rex.bind(P .. "shift+5", "client.tab.rename")

rex.action{
  name = "goto_tab",
  title = "Go to Tab N (1-based)",
  category = "herdr",
  args = { index = "integer" },
  run = function(ctx, args)
    local w = windows().windows[args.index]
    if w == nil then return end
    fail(select(2, rex.session.focus_window{ window_id = w.window_id }))
  end,
}

for i = 1, 9 do
  rex.bind(P .. i, "goto_tab", { index = i })
  rex.bind("ctrl+" .. i, "goto_tab", { index = i })
end

-- ctrl+space: bounce to the tab last left with ctrl+space (herdr hack-herdr-last-tab.sh).
rex.action{
  name = "last_tab",
  title = "Last Tab Toggle",
  category = "herdr",
  run = function(ctx, args)
    local view = windows()
    local key = "last-tab-" .. ctx.session_id:gsub("[^%w]", "_")
    local target = read_state(key)
    write_state(key, view.active_window_id)
    for _, w in ipairs(view.windows) do
      if w.window_id == target and target ~= view.active_window_id then
        fail(select(2, rex.session.focus_window{ window_id = target }))
        return
      end
    end
    fail(select(2, rex.session.focus_previous_window{}))
  end,
}
rex.bind("ctrl+space", "last_tab")

-- ctrl+0: close every tab but the first (herdr hack-herdr-close-other-tabs.sh).
rex.action{
  name = "close_other_tabs",
  title = "Close All Tabs but the First",
  category = "herdr",
  run = function(ctx, args)
    for i, w in ipairs(windows().windows) do
      if i > 1 then
        fail(select(2, rex.session.close_window{ window_id = w.window_id }))
      end
    end
  end,
}
rex.bind("ctrl+0", "close_other_tabs")
rex.bind(P .. "0", "close_other_tabs")

-- Panes (herdr: split_vertical, split_horizontal + prefix+= alias, close_pane, zoom).
rex.bind(P .. "v", "pane.split", { direction = "right" })
rex.bind(P .. "-", "pane.split", { direction = "down" })
rex.bind(P .. "=", "pane.split", { direction = "down" })
rex.bind(P .. "x", "pane.close")
rex.bind(P .. "z", "pane.zoom")
rex.bind(P .. "o", "pane.focus_next")
rex.bind(P .. "tab", "pane.focus_next")
rex.bind(P .. "shift+tab", "pane.focus_previous")
rex.bind(P .. "shift+1", "pane.move_to_new_tab")

for key, dir in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind(P .. key, "pane.focus", { direction = dir })
  rex.bind(P .. "shift+" .. key, "pane.move", { direction = dir })
end

-- ctrl+h/j/k/l: vim-herdr-navigation. Hand the key to vim/tmux/herdr/ssh, otherwise move Rex focus.
local PASS_THROUGH = { "vim", "tmux", "herdr", "ssh" }

local function owns_ctrl_hjkl(block_id)
  local fg = foreground(block_id)
  if fg == nil then return false end
  local name = fg.name or ""
  for _, prog in ipairs(PASS_THROUGH) do
    if name:find(prog, 1, true) then return true end
  end
  return false
end

for key, dir in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind("ctrl+" .. key, function(ctx, ev)
    if owns_ctrl_hjkl(ctx.block_id) then return false end
    rex.session.focus_direction{ session_id = ctx.session_id, direction = dir }
    return true
  end)
end

-- ctrl+b: previous pane in the current tab (herdr hack-herdr-last-pane.sh), tracked per tab on press.
rex.action{
  name = "last_pane",
  title = "Last Pane Toggle",
  category = "herdr",
  run = function(ctx, args)
    local view = windows()
    local key = "last-pane-" .. view.active_window_id:gsub("[^%w]", "_")
    local target = read_state(key)
    write_state(key, ctx.block_id)
    if target ~= nil and target ~= ctx.block_id then
      local _, err = rex.session.focus_block{ block_id = target }
      if err == nil then return end
    end
    fail(select(2, rex.session.focus_previous_pane{}))
  end,
}
rex.bind("ctrl+b", "last_pane")

-- prefix+r: resize mode (herdr resize_mode), h/j/k/l and arrows, shift for bigger steps.
rex.mode("resize", { exclusive = true })
rex.bind(P .. "r", "client.mode.enter", { name = "resize" })
for _, pair in ipairs({ { "h", "left" }, { "j", "down" }, { "k", "up" }, { "l", "right" },
                        { "left", "left" }, { "down", "down" }, { "up", "up" }, { "right", "right" } }) do
  rex.bind("resize/" .. pair[1], "pane.resize", { direction = pair[2] })
  rex.bind("resize/shift+" .. pair[1], "pane.resize", { direction = pair[2], amount = 15 })
end
rex.bind("resize/=", "pane.balance")
rex.bind("resize/enter", "client.mode.exit")
rex.bind("resize/q", "client.mode.exit")

-- Sessions = herdr workspaces (next/previous_workspace, rename on prefix+$, close_workspace).
rex.bind(P .. "w", "session.next")
rex.bind(P .. "shift+w", "session.previous")
rex.bind(P .. "shift+4", "session.rename")
rex.bind(P .. "shift+d", "session.close")
rex.bind(P .. "g", "session.switch")

-- ctrl+enter: bounce to the session last left with ctrl+enter (herdr hack-herdr-last-workspace.sh).
rex.action{
  name = "last_session",
  title = "Last Session Toggle",
  category = "herdr",
  run = function(ctx, args)
    local target = read_state("last-session")
    write_state("last-session", ctx.session_id)
    if target ~= nil and target ~= ctx.session_id then
      rex.client.queue("session.select", { session_id = target })
    else
      rex.client.queue("session.previous")
    end
  end,
}
rex.bind("ctrl+enter", "last_session")

-- Session layout from herdr-sesh-layout.sh: a startup_command gets one 🐟 tab, otherwise 🖋️ nvim + 🤖 and 🔨 tabs of three even shells.
local function shell(dir, input)
  local options = { cwd = dir }
  if input ~= nil then options.initial_input = input .. "\n" end
  return rex.layout.block{ flavor = SHELL, options = options }
end

local function three_shells(dir)
  return rex.layout.horizontal(1 / 3, shell(dir), rex.layout.horizontal(0.5, shell(dir), shell(dir)))
end

local function dev_windows(dir, startup)
  if startup ~= nil then
    return { { window_label = "🐟", layout = shell(dir, startup) } }
  end
  return {
    { window_label = "🖋️", layout = shell(dir, "nvim") },
    { window_label = "🤖", layout = three_shells(dir) },
    { window_label = "🔨", layout = three_shells(dir) },
  }
end

local function open_session(label, dir, startup)
  local list, err = rex.call("session.list")
  fail(err)
  for _, s in ipairs(list.sessions or {}) do
    if s.label == label then
      rex.client.queue("session.select", { session_id = s.session_id })
      return
    end
  end
  local s, cerr = rex.call("session.create", { label = label, initial_windows = dev_windows(dir, startup) })
  fail(cerr)
  rex.call("session.attach", { session_id = s.session_id })
  local view = rex.call("session.view", { session_id = s.session_id })
  if view ~= nil and view.windows[1] ~= nil then
    rex.call("session.focus_window", { session_id = s.session_id, window_id = view.windows[1].window_id })
  end
  rex.client.queue("session.select", { session_id = s.session_id })
end

-- prefix+N: session at the focused pane's cwd, labelled by its basename (herdr-new-workspace.sh).
rex.action{
  name = "new_session_here",
  title = "New Session at Pane Directory",
  category = "herdr",
  run = function(ctx, args)
    local cwd = block_cwd(ctx.block_id)
    open_session(cwd:match("([^/]+)/?$") or "home", cwd)
  end,
}
rex.bind(P .. "shift+n", "new_session_here")

-- Called by rex-sesh.sh once a row is picked; an empty startup means the dev layout.
rex.action{
  name = "sesh_open",
  title = "Open Sesh Session",
  category = "Sesh",
  args = { label = "string", dir = "string", startup = "string?" },
  run = function(ctx, args)
    local startup = args.startup
    if startup == "" then startup = nil end
    open_session(args.label, args.dir, startup)
  end,
}

-- ctrl+t: rex-sesh.sh fzf picker in a floating layer (herdr-sesh.sh popup, 48% x 70%).
rex.action{
  name = "sesh_picker",
  title = "Sesh Picker",
  category = "Sesh",
  run = function(ctx, args)
    fail(select(2, rex.session.new_layer{
      bounds = { 0.26, 0.15, 0.48, 0.7 },
      focus = true,
      layout = rex.layout.block{
        flavor = SHELL,
        options = { command = { HOME .. "/.local/bin/mux/rex/rex-sesh.sh" }, cwd = HOME },
      },
    }))
  end,
}
rex.bind("ctrl+t", "sesh_picker")

-- sesh.toml entries, read from the same file sesh and herdr-sesh.sh use: each is a palette action ("Sesh: name") and its alias is prefix, space, alias.
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

for _, e in ipairs(read_sesh(HOME .. "/.config/sesh/sesh.toml")) do
  if e.name ~= nil and e.path ~= nil then
    local dir = e.path:gsub("^~", HOME):gsub("(.)/$", "%1")
    local action = "sesh_" .. e.name:lower():gsub("[^%w]", "_")
    rex.action{
      name = action,
      title = "Sesh: " .. e.name .. (e.alias and ("  (" .. e.alias .. ")") or ""),
      category = "Sesh",
      keywords = (e.alias or "") .. " " .. dir,
      run = function(ctx, args)
        open_session(e.name, dir, e.startup_command)
      end,
    }
    if e.alias ~= nil then
      rex.bind(P .. "space>" .. table.concat({ e.alias:lower():match(("(.)"):rep(#e.alias)) }, ">"), action)
    end
  end
end

-- ctrl+g: lazygit in a floating layer on the pane's repo (herdr lazygit popup, 90%).
rex.action{
  name = "lazygit",
  title = "Lazygit (floating)",
  category = "herdr",
  run = function(ctx, args)
    fail(select(2, rex.session.new_layer{
      bounds = { 0.05, 0.05, 0.9, 0.9 },
      focus = true,
      layout = rex.layout.block{
        flavor = SHELL,
        options = { command = { "lazygit" }, cwd = block_cwd(ctx.block_id) },
      },
    }))
  end,
}
rex.bind("ctrl+g", "lazygit")

-- prefix+y: yazi in a new tab at the pane's cwd (herdr yazi-herdr.sh).
rex.action{
  name = "yazi_tab",
  title = "Yazi in New Tab",
  category = "herdr",
  run = function(ctx, args)
    fail(select(2, rex.session.new_window{
      layout = rex.layout.block{
        flavor = SHELL,
        options = { command = { "yazi" }, cwd = block_cwd(ctx.block_id) },
      },
    }))
  end,
}
rex.bind(P .. "y", "yazi_tab")

-- UI: herdr toggle_sidebar on prefix+E, settings, help, reload_config. prefix+V and prefix+a are Rex-only.
rex.bind(P .. "shift+e", "client.sidebar.toggle")
rex.bind(P .. "shift+v", "client.tab_style.toggle")
rex.bind(P .. "a", "client.sidebar.activity.toggle")
rex.bind(P .. "s", "client.settings")
rex.bind(P .. "shift+/", "client.palette.toggle")
rex.bind(P .. "shift+r", "client.config.reload")
rex.bind(P .. "[", "client.find.open")
rex.bind(P .. "u", "client.prompt.previous")
