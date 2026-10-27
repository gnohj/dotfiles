-- Helpers shared by the config modules: pane/tab lookups, per-host state files, and the floating popup.
local M = {}

M.TERM = "com.superlogical.terminal"
M.SHELL = M.TERM .. ".shell"
M.HOME = os.getenv("HOME")
M.STATE_DIR = M.HOME .. "/.local/state/rex-herdr-keys"
M.REX_BIN = os.getenv("REX_BIN_DIR") or "/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS"
M.REX_CLI = M.REX_BIN .. "/rex"

function M.fail(err)
  if err ~= nil then error(err, 0) end
end

function M.read_state(name)
  local f = io.open(M.STATE_DIR .. "/" .. name)
  if f == nil then return nil end
  local v = f:read("*l")
  f:close()
  return v
end

function M.write_state(name, value)
  rex.exec({ "mkdir", "-p", M.STATE_DIR })
  local f = io.open(M.STATE_DIR .. "/" .. name, "w")
  if f == nil then return end
  f:write(value)
  f:close()
end

function M.foreground(block_id)
  local p = rex.block.call(M.TERM, "process", { block_id = block_id })
  if p == nil then return nil end
  return p.foreground or p.child
end

function M.block_cwd(block_id)
  local fg = M.foreground(block_id)
  if fg ~= nil and fg.cwd ~= nil then return fg.cwd end
  local r = rex.block.call(M.TERM, "pwd", { block_id = block_id })
  if r ~= nil and r.pwd ~= nil then
    return (r.pwd:gsub("^file://[^/]*", ""))
  end
  return os.getenv("HOME")
end

function M.windows()
  local view, err = rex.session.view{}
  M.fail(err)
  return view
end

-- The app's shown tab is not the server's active_window_id, so locate the tab holding the pressed-in pane.
function M.tab_of_block(view, block_id)
  for _, w in ipairs(view.windows) do
    for _, layer in ipairs(w.layers or {}) do
      for _, b in ipairs(layer.blocks or {}) do
        if b.block_id == block_id then return w end
      end
    end
  end
end

-- herdr-style toggle popup over an opaque theme backdrop (Rex leaves default bg see-through), {l,t,r,b} bounds, rex-fit sizes the pty to the box.
local WAIT_FOR_SIZE = 'for _ in 1 2 3 4 5 6 7 8 9 10; do [ "$(stty size 2>/dev/null)" != "24 80" ] && break; sleep 0.03; done'
-- Popups run on the session's host ($HOME is that shell's); the resize waits off the critical path; mise python starts rex-fit ~30ms faster.
local RUN_THEN_CLOSE_BACKDROP = [[rex="${REX_BIN_DIR:+$REX_BIN_DIR/}rex"; layer=$1; block=$2; shift 2; (]] .. WAIT_FOR_SIZE .. [[; s=$(stty size); "$rex" api call -s "$REX_SESSION" com.superlogical.terminal.resize "{\"block_id\":\"$block\",\"args\":{\"columns\":${s#* },\"rows\":${s% *}}}") >/dev/null 2>&1 & py="$HOME/.local/share/mise/installs/python/latest/bin/python3"; [ -x "$py" ] || py=python3; "$py" -I -S "$HOME/.local/bin/mux/rex/rex-fit" "$@"; "$rex" api call -s "$REX_SESSION" session.close_layer "{\"layer_id\":\"$layer\"}" >/dev/null 2>&1]]
local PAINT = [[c=$1; paint() { s=$(stty size); w=${s#* }; r=${s% *}; row=$(printf '%*s' "$w" ''); printf '\033[?25l\033[H\033[48;2;%sm' "$c"; i=0; while [ "$i" -lt "$r" ]; do printf '%s' "$row"; i=$((i + 1)); done; }; trap paint WINCH; paint; while :; do sleep 3600 & wait $!; done]]

local function theme_background()
  local f = io.open(M.HOME .. "/.config/ghostty/ghostty-theme")
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

function M.popup(ctx, side, top, command, cwd)
  local view = M.windows()
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
    layout = rex.layout.block{ flavor = M.SHELL, options = { command = { "/bin/sh", "-c", PAINT, "sh", theme_background() } } },
  }
  M.fail(berr)
  local argv = { "/bin/sh", "-c", RUN_THEN_CLOSE_BACKDROP, "sh", backdrop.layer_id, backdrop.block_ids[1],
                 tostring((box[3] - side) / box[3]), tostring((box[4] - top) / box[4]) }
  for _, a in ipairs(command) do table.insert(argv, a) end
  M.fail(select(2, rex.session.new_layer{
    bounds = box,
    focus = true,
    layout = rex.layout.block{ flavor = M.SHELL, options = { command = argv, cwd = cwd } },
  }))
end

return M
