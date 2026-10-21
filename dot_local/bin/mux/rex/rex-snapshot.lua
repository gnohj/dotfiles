-- Rex state shaped like `herdr api snapshot`, ids unprefixed and nested as <session>:<window|block> for herdr-sesh.sh.
local TERM = "com.superlogical.terminal"
local AGENTS = { claude = true, pi = true, codex = true, hermes = true, droid = true }

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

local function status(block_id)
  local ps = rex.block.call(TERM, "program_status", { block_id = block_id })
  for _, r in ipairs((ps and ps.records) or {}) do
    if r.id == nil or r.id == "" then return r.state end
  end
  return nil
end

local here = os.getenv("REX_SESSION")
local snap = { workspaces = {}, tabs = {}, panes = {}, agents = {} }
local list = rex.call("session.list") or { sessions = {} }

for _, s in ipairs(list.sessions or {}) do
  rex.call("session.attach", { session_id = s.session_id })
  local view = rex.call("session.view", { session_id = s.session_id })
  local sid = bare(s.session_id)
  table.insert(snap.workspaces, { workspace_id = sid, label = s.label })
  for n, w in ipairs((view and view.windows) or {}) do
    local tid = sid .. ":" .. bare(w.window_id)
    table.insert(snap.tabs, { tab_id = tid, workspace_id = sid, label = w.label, number = n })
    for _, layer in ipairs(w.layers or {}) do
      if layer.kind == "tiled" then
        for i, bid in ipairs(each_block(layer.layout, {})) do
          local proc = rex.block.call(TERM, "process", { block_id = bid }) or {}
          local fg = proc.foreground or proc.child or {}
          local pid = sid .. ":" .. bare(bid)
          table.insert(snap.panes, {
            pane_id = pid, workspace_id = sid, tab_id = tid, cwd = fg.cwd, foreground_cwd = fg.cwd,
            focused = s.session_id == here and w.window_id == view.active_window_id and i == 1,
          })
          if AGENTS[fg.name or ""] then
            local title = rex.block.call(TERM, "title", { block_id = bid }) or {}
            table.insert(snap.agents, {
              pane_id = pid, tab_id = tid, agent = fg.name, cwd = fg.cwd,
              agent_status = status(bid) or "idle", title = title.title,
            })
          end
        end
      end
    end
  end
end

return { result = { snapshot = snap } }
