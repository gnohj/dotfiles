-- Rex keymap: modules beside this file register actions via setup(), every key binds here; apply with `rex config reload`.

local P = "ctrl+a>"

require("tabs").setup()
require("sessions").setup()
require("tools").setup()
local panes = require("panes")
panes.setup()
local entry_aliases = require("entries").setup()
local has_paste = require("paste").setup()
require("worktrees").setup()

-- Program resume: what Rex may restart after a server restart (nvim reports itself; the rest report through rex-resume-shim).
if rex.set then
  rex.set("resume.trust.nvim", { command = { "nvim" }, flags = { ["--cmd"] = { "drop", values = 1 }, ["-c"] = { "keep", values = 1 } } })
  rex.set("resume.trust.tuxedo", { command = { "tuxedo" } })
  rex.set("resume.trust.kb", { command = { "kb" } })
  rex.set("resume.trust.gh-dash", { command = { "gh-dash" } })
  rex.set("resume.trust.pi", { command = { "pi", "--session", rex.match.under("~/.pi/agent/sessions") } })
end

-- Prefix and the pass-through for a literal ctrl+a (readline beginning-of-line).
rex.bind(P .. "ctrl+a", "pane.send_key", { key = "ctrl+a" })

-- Tabs: new, next/previous, last, close others, rename on prefix+%.
rex.bind(P .. "c", "client.tab.new")
rex.bind(P .. "n", "next_tab")
rex.bind(P .. "p", "previous_tab")
rex.bind("ctrl+tab", "next_tab")
rex.bind("ctrl+shift+tab", "previous_tab")
rex.bind("ctrl+[Backquote]", "previous_tab")
rex.bind(P .. "shift+5", "client.tab.rename")

for i = 1, 9 do
  rex.bind(P .. i, "goto_tab", { index = i })
  rex.bind("ctrl+" .. i, "goto_tab", { index = i })
end

rex.bind("ctrl+space", "last_tab")
rex.bind("ctrl+0", "close_other_tabs")
rex.bind(P .. "0", "close_other_tabs")

-- Panes: split right, split down + prefix+= alias, close, zoom, float.
rex.bind(P .. "v", "pane.split", { direction = "auto" })
rex.bind(P .. "-", "pane.split", { direction = "down" })
rex.bind(P .. "=", "pane.split", { direction = "down" })
rex.bind(P .. "x", "close_pane")
rex.bind(P .. "z", "pane.zoom")
rex.bind(P .. "f", "pane.float")
rex.bind(P .. "shift+m", "float_minimize")
rex.bind(P .. "o", "pane.focus_next")
rex.bind(P .. "tab", "pane.focus_next")
rex.bind(P .. "shift+tab", "pane.focus_previous")
rex.bind(P .. "shift+1", "pane.move_to_new_tab")

for key, dir in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind(P .. key, "pane.focus", { direction = dir })
  rex.bind(P .. "shift+" .. key, "pane.move", { direction = dir })
  -- ctrl+h/j/k/l: the key goes to vim/ssh, otherwise Rex focus moves.
  rex.bind("ctrl+" .. key, panes.navigate(dir))
end

rex.bind("ctrl+b", "last_pane")

-- prefix+r: resize mode, h/j/k/l and arrows.
rex.mode("resize", { exclusive = true })
rex.bind(P .. "r", "client.mode.enter", { name = "resize" })
for _, pair in ipairs({ { "h", "left" }, { "j", "down" }, { "k", "up" }, { "l", "right" },
                        { "left", "left" }, { "down", "down" }, { "up", "up" }, { "right", "right" } }) do
  rex.bind("resize/" .. pair[1], "resize_" .. pair[2])
end
rex.bind("resize/=", "pane.balance")
rex.bind("resize/enter", "client.mode.exit")
rex.bind("resize/q", "client.mode.exit")

-- prefix+m: move mode, h/j/k/l put the pane on that side of its sibling (stacked <-> side by side).
rex.mode("move", { exclusive = true })
rex.bind(P .. "m", "client.mode.enter", { name = "move" })
for key, dir in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind("move/" .. key, "move_" .. dir)
end
rex.bind("move/enter", "client.mode.exit")
rex.bind("move/q", "client.mode.exit")

-- Sessions: next/previous, rename on prefix+$, switch, last, close.
rex.bind(P .. "w", "switch_session", { action = "session.next" })
rex.bind(P .. "shift+w", "switch_session", { action = "session.previous" })
rex.bind(P .. "shift+4", "session.rename")
rex.bind(P .. "g", "switch_session", { action = "session.switch" })
rex.bind("ctrl+enter", "last_session")
rex.bind("ctrl+[Semicolon]", "next_attention")
rex.bind(P .. "shift+d", "close_session")
rex.bind(P .. "shift+x", "close_tab")
rex.bind(P .. "shift+n", "new_session_here")

-- Sessions: ctrl+t picker, cmd+shift+n project palette, and each entries.toml alias as prefix, space, alias.
rex.bind("ctrl+t", "session_picker")
rex.bind("cmd+shift+n", "project_picker")
for _, a in ipairs(entry_aliases) do
  rex.bind(P .. "space>" .. a.keys, a.action)
end

-- Tools: lazygit popup, yazi tab, scrollback in nvim, pluck.
rex.bind("ctrl+g", "lazygit")
rex.bind(P .. "y", "yazi_tab")
rex.bind(P .. "e", "scrollback_view")
rex.bind(P .. "shift+f", "pluck")
rex.bind(P .. "b", "kb_fill")

-- UI: sidebar on prefix+E, tab style, activity, settings, palette, reload, copy mode on prefix+[, find on prefix+/.
rex.bind(P .. "shift+e", "client.sidebar.toggle")
rex.bind(P .. "shift+v", "client.tab_style.toggle")
rex.bind(P .. "a", "client.sidebar.activity.toggle")
rex.bind(P .. "s", "client.settings")
rex.bind(P .. "shift+/", "client.palette.toggle")
rex.bind(P .. "shift+r", "client.config.reload")
rex.bind(P .. "[", "pane.copy_mode.enter")
rex.bind(P .. "/", "client.find.open")
rex.bind(P .. "u", "client.prompt.previous")

-- cmd+shift+v: copied files or a copied image sent to the pane's host and pasted as paths.
if has_paste then rex.bind("cmd+shift+v", "file_paste") end

-- >>> pulse >>>
-- Pulse watchlist pane, installed by mise (`npm:rex-pulse-ticker`); latest/lts are mise-maintained symlinks.
local mise = os.getenv("HOME") .. "/.local/share/mise/installs"
local pulse = mise .. "/npm-rex-pulse-ticker/latest/lib/node_modules/rex-pulse-ticker"
local pulse_lua = io.open(pulse .. "/lua/pulse.lua")
if pulse_lua then
  pulse_lua:close()
  dofile(pulse .. "/lua/pulse.lua").setup({ bin = { mise .. "/node/lts/bin/node", pulse .. "/bin/pulse-rex.js" } })
end
-- <<< pulse <<<
