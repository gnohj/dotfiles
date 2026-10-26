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

-- herdr-style toggle popup over an opaque theme backdrop (Rex leaves default bg see-through), {l,t,r,b} bounds, rex-fit sizes the pty to the box.
local WAIT_FOR_SIZE = 'for _ in 1 2 3 4 5 6 7 8 9 10; do [ "$(stty size 2>/dev/null)" != "24 80" ] && break; sleep 0.03; done'
-- Popup commands run on the session's own host, so paths resolve from that shell's $HOME, never this machine's.
-- The backdrop resize waits for the box size off the critical path, since rex-fit follows SIGWINCH; mise's python starts rex-fit ~30ms faster than the Xcode one.
local RUN_THEN_CLOSE_BACKDROP = [[rex="${REX_BIN_DIR:+$REX_BIN_DIR/}rex"; layer=$1; block=$2; shift 2; (]] .. WAIT_FOR_SIZE .. [[; s=$(stty size); "$rex" api call -s "$REX_SESSION" com.superlogical.terminal.resize "{\"block_id\":\"$block\",\"args\":{\"columns\":${s#* },\"rows\":${s% *}}}") >/dev/null 2>&1 & py="$HOME/.local/share/mise/installs/python/latest/bin/python3"; [ -x "$py" ] || py=python3; "$py" -I -S "$HOME/.local/bin/mux/rex/rex-fit" "$@"; "$rex" api call -s "$REX_SESSION" session.close_layer "{\"layer_id\":\"$layer\"}" >/dev/null 2>&1]]
local PAINT = [[c=$1; paint() { s=$(stty size); w=${s#* }; r=${s% *}; row=$(printf '%*s' "$w" ''); printf '\033[?25l\033[H\033[48;2;%sm' "$c"; i=0; while [ "$i" -lt "$r" ]; do printf '%s' "$row"; i=$((i + 1)); done; }; trap paint WINCH; paint; while :; do sleep 3600 & wait $!; done]]
local REX_BIN = os.getenv("REX_BIN_DIR") or "/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS"
local REX_CLI = REX_BIN .. "/rex"

local function theme_background()
  local f = io.open(HOME .. "/.config/ghostty/ghostty-theme")
  local hex = "0f1419"
  if f ~= nil then
    for line in f:lines() do
      local h = line:match("^%s*background%s*=%s*#?(%x%x%x%x%x%x)")
      if h ~= nil then hex = h end
    end
    f:close()
  end
  return string.format("%d;%d;%d", tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end

local function popup(ctx, side, top, command, cwd)
  local view = windows()
  for _, w in ipairs(view.windows) do
    if w.window_id == view.active_window_id then
      local open = false
      for _, layer in ipairs(w.layers or {}) do
        if layer.kind ~= "tiled" then
          open = true
          rex.session.close_layer{ layer_id = layer.layer_id }
        end
      end
      if open then return end
    end
  end
  local box = { side, top, 1 - side, 1 - top }
  local backdrop, berr = rex.session.new_layer{
    bounds = box,
    focus = false,
    layout = rex.layout.block{ flavor = SHELL, options = { command = { "/bin/sh", "-c", PAINT, "sh", theme_background() } } },
  }
  fail(berr)
  local argv = { "/bin/sh", "-c", RUN_THEN_CLOSE_BACKDROP, "sh", backdrop.layer_id, backdrop.block_ids[1],
                 tostring((box[3] - side) / box[3]), tostring((box[4] - top) / box[4]) }
  for _, a in ipairs(command) do table.insert(argv, a) end
  fail(select(2, rex.session.new_layer{
    bounds = box,
    focus = true,
    layout = rex.layout.block{ flavor = SHELL, options = { command = argv, cwd = cwd } },
  }))
end

-- Prefix and the pass-through for a literal ctrl+a (readline beginning-of-line).
rex.bind(P .. "ctrl+a", "pane.send_key", { key = "ctrl+a" })

-- Keyboard tab switches record the tab they leave, for ctrl+space (rex.on is script-only).
local function last_tab_key(ctx)
  return "last-tab-" .. ctx.session_id:gsub("[^%w]", "_")
end

-- The app's shown tab is not the server's active_window_id, so locate the tab holding the pressed-in pane.
local function tab_of_block(view, block_id)
  for _, w in ipairs(view.windows) do
    for _, layer in ipairs(w.layers or {}) do
      for _, b in ipairs(layer.blocks or {}) do
        if b.block_id == block_id then return w end
      end
    end
  end
end

local function current_tab(ctx, view)
  local w = tab_of_block(view, ctx.block_id)
  return w and w.window_id or view.active_window_id
end

local function switch_tab(ctx, view, window_id)
  local current = current_tab(ctx, view)
  if window_id == nil or window_id == current then return end
  write_state(last_tab_key(ctx), current)
  if ctx.client_id ~= nil then
    rex.client.queue("session.select", { session_id = ctx.session_id, window_id = window_id })
    return
  end
  fail(select(2, rex.session.focus_window{ window_id = window_id }))
end

local function neighbour_tab(ctx, view, step)
  local current = current_tab(ctx, view)
  for i, w in ipairs(view.windows) do
    if w.window_id == current then
      local n = view.windows[(i - 1 + step) % #view.windows + 1]
      return n and n.window_id
    end
  end
end

-- Tabs (herdr: new_tab, next/previous_tab, close_tab, rename_tab on prefix+%).
rex.action{
  name = "next_tab",
  title = "Next Tab",
  category = "herdr",
  run = function(ctx, args)
    local view = windows()
    switch_tab(ctx, view, neighbour_tab(ctx, view, 1))
  end,
}

rex.action{
  name = "previous_tab",
  title = "Previous Tab",
  category = "herdr",
  run = function(ctx, args)
    local view = windows()
    switch_tab(ctx, view, neighbour_tab(ctx, view, -1))
  end,
}

rex.bind(P .. "c", "client.tab.new")
rex.bind(P .. "n", "next_tab")
rex.bind(P .. "p", "previous_tab")
rex.bind("ctrl+tab", "next_tab")
rex.bind("ctrl+shift+tab", "previous_tab")
rex.bind("ctrl+[Backquote]", "previous_tab")
rex.bind(P .. "shift+x", "client.tab.close")
rex.bind(P .. "shift+5", "client.tab.rename")

rex.action{
  name = "goto_tab",
  title = "Go to Tab N (1-based)",
  category = "herdr",
  args = { index = "integer" },
  run = function(ctx, args)
    local view = windows()
    local w = view.windows[args.index]
    if w == nil then return end
    switch_tab(ctx, view, w.window_id)
  end,
}

for i = 1, 9 do
  rex.bind(P .. i, "goto_tab", { index = i })
  rex.bind("ctrl+" .. i, "goto_tab", { index = i })
end

-- ctrl+space: bounce to the tab last left by a keyboard switch (herdr hack-herdr-last-tab.sh).
rex.action{
  name = "last_tab",
  title = "Last Tab Toggle",
  category = "herdr",
  run = function(ctx, args)
    local view = windows()
    local target = read_state(last_tab_key(ctx))
    for _, w in ipairs(view.windows) do
      if w.window_id == target and target ~= current_tab(ctx, view) then
        switch_tab(ctx, view, target)
        return
      end
    end
    switch_tab(ctx, view, neighbour_tab(ctx, view, -1))
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
-- prefix+x: Rex disables pane.close on a tab's last pane, so close the tab instead (herdr close_pane).
rex.action{
  name = "close_pane",
  title = "Close Pane or Last-Pane Tab",
  category = "herdr",
  run = function(ctx, args)
    local w = tab_of_block(windows(), ctx.block_id)
    if w == nil then return end
    local panes = 0
    for _, layer in ipairs(w.layers or {}) do
      if layer.kind == "tiled" then panes = panes + #(layer.blocks or {}) end
    end
    rex.client.queue(panes > 1 and "pane.close" or "client.tab.close")
  end,
}
rex.bind(P .. "x", "close_pane")
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

-- Keyboard session switches record the two sessions last left, as rex-herdr ids (<host>~<id> for another host), for ctrl+enter.
local function session_ref(ctx)
  if ctx.session_id == nil then return nil end
  local id = (ctx.session_id:gsub("^session:", ""))
  if type(ctx.server) == "string" then return (ctx.server:gsub("[^%w]", "-")) .. "~" .. id end
  return id
end

local function left_sessions()
  local f = io.open(STATE_DIR .. "/left-sessions")
  if f == nil then return {} end
  local refs = {}
  for line in f:lines() do
    if line ~= "" then table.insert(refs, line) end
  end
  f:close()
  return refs
end

local function leave_session(ctx)
  local here, refs = session_ref(ctx), left_sessions()
  if here ~= nil and refs[1] ~= here then write_state("left-sessions", here .. "\n" .. (refs[1] or "")) end
end

-- Sessions = herdr workspaces (next/previous_workspace, rename on prefix+$, close_workspace).
rex.action{
  name = "switch_session",
  title = "Switch Session",
  category = "herdr",
  args = { action = "string" },
  run = function(ctx, args)
    leave_session(ctx)
    rex.client.queue(args.action)
  end,
}
rex.bind(P .. "w", "switch_session", { action = "session.next" })
rex.bind(P .. "shift+w", "switch_session", { action = "session.previous" })
rex.bind(P .. "shift+4", "session.rename")
rex.bind(P .. "shift+d", "session.close")
rex.bind(P .. "g", "switch_session", { action = "session.switch" })

-- ctrl+enter: bounce to the session last left by keyboard (herdr hack-herdr-last-workspace.sh); a cancelled picker falls back to the one before.
rex.action{
  name = "last_session",
  title = "Last Session Toggle",
  category = "herdr",
  run = function(ctx, args)
    local here, live = session_ref(ctx), nil
    if ctx.server == nil then
      live = {}
      for _, s in ipairs((rex.call("session.list") or {}).sessions or {}) do live[(s.session_id:gsub("^session:", ""))] = true end
    end
    local target
    for _, ref in ipairs(left_sessions()) do
      if ref ~= here and (live == nil or ref:find("~", 1, true) or live[ref]) then
        target = ref
        break
      end
    end
    leave_session(ctx)
    if target == nil then
      rex.client.queue("session.previous")
    elseif ctx.server == nil and not target:find("~", 1, true) then
      rex.client.queue("session.select", { session_id = "session:" .. target })
    else
      fail(select(2, rex.exec.start({ "/bin/zsh", "-lc", 'exec "$HOME/.local/bin/mux/rex/rex-herdr" workspace focus "$0"', target },
                                    { detach = true, env = { REX_BIN_DIR = REX_BIN } })))
    end
  end,
}
rex.bind("ctrl+enter", "last_session")

-- Session layout from herdr-sesh-layout.sh: a startup_command gets one tab with Rex's default name, otherwise 🖋️ nvim + 🤖 and 🔨 tabs of three even shells.
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
    return { { layout = shell(dir, startup) } }
  end
  return {
    { window_label = "🖋️", layout = shell(dir, "nvim") },
    { window_label = "🤖", layout = three_shells(dir) },
    { window_label = "🔨", layout = three_shells(dir) },
  }
end

-- Session glyphs from herdr-sesh-layout.sh: pinned names first, then 🖥️ home, 🌳 linked worktree, 🌿 repo, 📁 anything else.
local NAME_GLYPHS = { jira = "🔷", github = "🐙", browser = "🌐", fm = "🚢", hermes = "🤖", tasks = "🖊️" }

local function session_glyph(name, dir)
  if NAME_GLYPHS[name] ~= nil then return NAME_GLYPHS[name] end
  if name:match("^sm%-") then return "🚢" end
  if dir == HOME then return "🖥️" end
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
  fail(err)
  for _, s in ipairs(list.sessions or {}) do
    if s.label == label or s.label == name then
      if s.label ~= label then rex.call("session.set_label", { session_id = s.session_id, label = label }) end
      if not background then rex.client.queue("session.select", { session_id = s.session_id }) end
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
  if not background then rex.client.queue("session.select", { session_id = s.session_id }) end
end

-- prefix+N: session at the focused pane's cwd, labelled by its basename (herdr-new-workspace.sh).
rex.action{
  name = "new_session_here",
  title = "New Session at Pane Directory",
  category = "herdr",
  run = function(ctx, args)
    local cwd = block_cwd(ctx.block_id)
    leave_session(ctx)
    open_session(cwd:match("([^/]+)/?$") or "home", cwd)
  end,
}
rex.bind(P .. "shift+n", "new_session_here")

-- Called by rex-herdr and `mux session`; an empty startup means the dev layout, background="1" builds it unselected.
rex.action{
  name = "sesh_open",
  title = "Open Sesh Session",
  category = "Sesh",
  args = { label = "string", dir = "string", startup = "string?", background = "string?" },
  run = function(ctx, args)
    local startup = args.startup
    if startup == "" then startup = nil end
    open_session(args.label, (args.dir:gsub("^~", HOME)), startup, args.background == "1")
  end,
}

-- ctrl+t: herdr-sesh.sh itself as a floating popup, 48% x 70% centred like herdr's, its herdr calls answered by rex-herdr.
rex.action{
  name = "sesh_picker",
  title = "Sesh Picker",
  category = "Sesh",
  run = function(ctx, args)
    leave_session(ctx)
    popup(ctx, 0.26, 0.15, { "/bin/sh", "-c", 'exec "$HOME/.local/bin/mux/herdr/herdr-sesh.sh"' })
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

-- rex.toml adds the Mac's Rex-only entries that open on another host; sesh itself never reads it.
local sesh_entries = read_sesh(HOME .. "/.config/sesh/sesh.toml")
for _, e in ipairs(read_sesh(HOME .. "/.config/sesh/rex.toml")) do table.insert(sesh_entries, e) end

for _, e in ipairs(sesh_entries) do
  if e.name ~= nil and e.path ~= nil then
    local dir = e.path:gsub("^~", HOME):gsub("(.)/$", "%1")
    local action = "sesh_" .. e.name:lower():gsub("[^%w]", "_")
    rex.action{
      name = action,
      title = "Sesh: " .. e.name .. (e.alias and ("  (" .. e.alias .. ")") or ""),
      category = "Sesh",
      keywords = (e.alias or "") .. " " .. dir,
      run = function(ctx, args)
        leave_session(ctx)
        if e.rex_host == nil and ctx.server == nil then
          open_session(e.name, dir, e.startup_command)
          return
        end
        -- Lua here only reaches the focused session's server, so a pinned entry or a press from another host goes through rex-herdr.
        fail(select(2, rex.exec.start({ "/bin/zsh", "-lc", 'exec "$HOME/.local/bin/mux/rex/rex-herdr" layout --entry "$0"', e.name },
                                      { detach = true, env = { REX_BIN_DIR = REX_BIN } })))
      end,
    }
    if e.alias ~= nil then
      rex.bind(P .. "space>" .. table.concat({ e.alias:lower():match(("(.)"):rep(#e.alias)) }, ">"), action)
    end
  end
end

-- ctrl+g: lazygit as a floating popup on the pane's repo (herdr lazygit popup, 90%).
rex.action{
  name = "lazygit",
  title = "Lazygit (floating)",
  category = "herdr",
  run = function(ctx, args)
    popup(ctx, 0.05, 0.05, { "lazygit" }, block_cwd(ctx.block_id))
  end,
}
rex.bind("ctrl+g", "lazygit")

-- prefix+y: yazi in a new tab at the pane's cwd (herdr yazi-herdr.sh); keyboard focus follows only a client session.select.
rex.action{
  name = "yazi_tab",
  title = "Yazi in New Tab",
  category = "herdr",
  run = function(ctx, args)
    local created, err = rex.session.new_window{
      layout = rex.layout.block{
        flavor = SHELL,
        options = { command = { "yazi" }, cwd = block_cwd(ctx.block_id) },
      },
    }
    fail(err)
    if ctx.client_id ~= nil then
      rex.exec.start({ "/bin/sh", "-c", 'for d in 0.2 0.4; do sleep "$d"; "$0" -C "$1" do session.select session_id="$2" window_id="$3"; done', REX_CLI, ctx.client_id, ctx.session_id, created.window_id }, { detach = true })
    end
  end,
}
rex.bind(P .. "y", "yazi_tab")

-- prefix+e: the pane's scrollback (or its agent transcript) in nvim (herdr scrollback-viewer).
rex.action{
  name = "scrollback_view",
  title = "Scrollback in Nvim",
  category = "herdr",
  run = function(ctx, args)
    popup(ctx, 0.05, 0.05, { "/bin/sh", "-c", 'exec "$HOME/.local/bin/mux/rex/rex-scrollback" "$0"', ctx.block_id })
  end,
}
rex.bind(P .. "e", "scrollback_view")

-- prefix+F: hint labels over the pane's visible tokens (herdr pluck), drawn by a twin block in a same-layout scratch tab that swaps into the pane's slot.
local function scratch_layout(node, source, hint)
  if node.block_id ~= nil then
    return rex.layout.block{ flavor = SHELL, options = { command = node.block_id == source and hint or { "sleep", "600" } } }
  end
  local split = node.split.direction == "horizontal" and rex.layout.horizontal or rex.layout.vertical
  return split(node.split.ratio, scratch_layout(node.split.before, source, hint), scratch_layout(node.split.after, source, hint))
end

local function layout_rect(node, block_id)
  if node.block_id ~= nil then return node.block_id == block_id and node.rect or nil end
  return layout_rect(node.split.before, block_id) or layout_rect(node.split.after, block_id)
end

local function block_at(node, rect)
  if node.block_id ~= nil then
    for i = 1, 4 do
      if math.abs(node.rect[i] - rect[i]) > 1e-6 then return nil end
    end
    return node.block_id
  end
  return block_at(node.split.before, rect) or block_at(node.split.after, rect)
end

local function tiled_layout(window)
  for _, layer in ipairs(window.layers or {}) do
    if layer.kind == "tiled" then return layer.layout end
  end
end

rex.action{
  name = "pluck",
  title = "Pluck Visible Token",
  category = "herdr",
  run = function(ctx, args)
    local window = tab_of_block(windows(), ctx.block_id)
    local layout = window and tiled_layout(window)
    local rect = layout and layout_rect(layout, ctx.block_id)
    if rect == nil then return end
    local hint = { "/bin/sh", "-c", 'exec "$HOME/.local/bin/mux/rex/rex-pluck" "$0" "$1"', ctx.block_id, window.window_id }
    local created, err = rex.session.new_window{ layout = scratch_layout(layout, ctx.block_id, hint) }
    fail(err)
    for _, w in ipairs(windows().windows) do
      if w.window_id == created.window_id then
        local twin = block_at(tiled_layout(w), rect)
        fail(select(2, rex.session.swap_blocks{ block_id = ctx.block_id, other_block_id = twin }))
        fail(select(2, rex.session.focus_block{ block_id = twin }))
      end
    end
  end,
}
rex.bind(P .. "shift+f", "pluck")

-- rex-pluck opens a picked file here: nvim in a new tab at its line.
rex.action{
  name = "open_file_tab",
  title = "Open File in Nvim Tab",
  category = "herdr",
  args = { path = "string", line = "integer?" },
  run = function(ctx, args)
    local created, err = rex.session.new_window{
      layout = rex.layout.block{
        flavor = SHELL,
        options = { command = args.line and { "nvim", "+" .. args.line, "--", args.path } or { "nvim", "--", args.path }, cwd = args.path:match("^(.*)/") or HOME },
      },
    }
    fail(err)
    if ctx.client_id ~= nil then
      rex.client.queue("session.select", { session_id = ctx.session_id, window_id = created.window_id })
    end
  end,
}

-- UI: herdr toggle_sidebar on prefix+E, settings, help, reload_config. prefix+V and prefix+a are Rex-only.
rex.bind(P .. "shift+e", "client.sidebar.toggle")
rex.bind(P .. "shift+v", "client.tab_style.toggle")
rex.bind(P .. "a", "client.sidebar.activity.toggle")
rex.bind(P .. "s", "client.settings")
rex.bind(P .. "shift+/", "client.palette.toggle")
rex.bind(P .. "shift+r", "client.config.reload")
rex.bind(P .. "[", "client.find.open")
rex.bind(P .. "u", "client.prompt.previous")
