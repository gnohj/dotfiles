-- Rex state as the snapshot JSON rex-sesh-picker.sh reads (workspaces, tabs, panes), ids nested as <session>:<window|block>; other `rex hosts` lead theirs with <host>~.
local TERM = "com.superlogical.terminal"

local function bare(id) return (id or ""):gsub("^%a+:", "") end

local function each_block(layout, out)
  if layout == nil then return out end
  if layout.block_id ~= nil then table.insert(out, layout.block_id) end
  if layout.split ~= nil then
    each_block(layout.split.before, out)
    each_block(layout.split.after, out)
  end
  return out
end

local here = os.getenv("REX_SESSION")
local snap = { workspaces = {}, tabs = {}, panes = {} }

local function collect(api, host)
  local list = api.call("session.list")
  local prefix = host and (host:gsub("[^%w]", "-") .. "~") or ""
  for _, s in ipairs((list and list.sessions) or {}) do
    api.call("session.attach", { session_id = s.session_id })
    local view = api.call("session.view", { session_id = s.session_id })
    local sid = prefix .. bare(s.session_id)
    table.insert(snap.workspaces, { workspace_id = sid, label = s.label, host = host })
    for n, w in ipairs((view and view.windows) or {}) do
      local tid = sid .. ":" .. bare(w.window_id)
      table.insert(snap.tabs, { tab_id = tid, workspace_id = sid, label = w.label, number = n })
      for _, layer in ipairs(w.layers or {}) do
        if layer.kind == "tiled" then
          for i, bid in ipairs(each_block(layer.layout, {})) do
            local ids = { session_id = s.session_id, block_id = bid }
            local proc = api.block.call(TERM, "process", ids) or {}
            local fg = proc.foreground or proc.child or {}
            local pid = sid .. ":" .. bare(bid)
            table.insert(snap.panes, {
              pane_id = pid, workspace_id = sid, tab_id = tid, cwd = fg.cwd, foreground_cwd = fg.cwd,
              focused = s.session_id == here and w.window_id == view.active_window_id and i == 1,
            })
          end
        end
      end
    end
  end
end

collect(rex)
for _, label in ipairs(rex.servers()) do
  local ok, api = pcall(rex.server, label)
  if ok then collect(api, label) end
end

return { result = { snapshot = snap } }
