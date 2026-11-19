-- Project palette: pick a folder under ~/Developer, then a worktree or a new one via wt-add; sessions open through `mux session`.
local c = require("common")

local M = {}

local DEV = c.HOME .. "/Developer"
local BUCKETS = { "feat", "fix", "ui", "infra", "refactor", "perf", "test", "chore", "spike" }
local NONE = "(none)"
local NEW = "__new_worktree__"

local function short(path)
  return (path:gsub("^" .. c.HOME:gsub("%p", "%%%0"), "~"))
end

local function exists(path)
  local f = io.open(path)
  if f == nil then return false end
  f:close()
  return true
end

local function git(dir, ...)
  local r = rex.exec{ "git", "-C", dir, ... }
  if r == nil or not r.ok then return nil end
  return (r.stdout:gsub("%s+$", ""))
end

local function stop(why)
  if why ~= nil and why ~= "cancelled" then rex.log("warn", "project_picker: " .. tostring(why)) end
end

local function recent()
  local list = {}
  for name in (c.read_state("project-recent") or ""):gmatch("[^,]+") do table.insert(list, name) end
  return list
end

local function remember(name, dir)
  local list = { name }
  for _, n in ipairs(recent()) do
    if n ~= name and #list < 20 then table.insert(list, n) end
  end
  c.write_state("project-recent", table.concat(list, ","))
  if dir ~= nil then c.write_state("project-last-" .. name, dir) end
end

local function projects()
  local r = rex.exec{ "find", "-L", DEV, "-mindepth", "1", "-maxdepth", "1", "-type", "d", "-not", "-name", ".*" }
  local rank = {}
  for i, n in ipairs(recent()) do rank[n] = i end
  local list = {}
  for dir in ((r and r.stdout) or ""):gmatch("[^\n]+") do
    local name = dir:match("([^/]+)$")
    local kind = exists(dir .. "/.bare/HEAD") and "bare" or exists(dir .. "/.git") and "repo" or "folder"
    table.insert(list, { name = name, dir = dir, kind = kind })
  end
  table.sort(list, function(a, b)
    if (a.kind == "bare") ~= (b.kind == "bare") then return a.kind == "bare" end
    local ra, rb = rank[a.name] or math.huge, rank[b.name] or math.huge
    if ra ~= rb then return ra < rb end
    return a.name:lower() < b.name:lower()
  end)
  return list
end

local function worktrees(p)
  local root = p.kind == "bare" and (p.dir .. "/.bare") or p.dir
  local main = p.kind == "bare" and (git(root, "symbolic-ref", "--short", "refs/remotes/origin/HEAD") or ""):gsub("^origin/", "") or nil
  local list, cur = {}, nil
  for line in ((git(root, "worktree", "list", "--porcelain") or "") .. "\n\n"):gmatch("([^\n]*)\n") do
    if line:match("^worktree ") then
      cur = { path = line:sub(10) }
    elseif cur ~= nil and line:match("^branch ") then
      cur.branch = line:gsub("^branch refs/heads/", "")
    elseif cur ~= nil and line == "bare" then
      cur.bare = true
    elseif line == "" and cur ~= nil then
      if not cur.bare and not cur.path:match("/%.bare$") and not cur.path:find("/.treehouse/", 1, true) and exists(cur.path) then table.insert(list, cur) end
      cur = nil
    end
  end
  if p.kind ~= "bare" and list[1] ~= nil then list[1].main = true end
  local last = c.read_state("project-last-" .. p.name)
  for _, w in ipairs(list) do
    if main ~= nil and w.branch == main then w.main = true end
    w.last = w.path == last
  end
  table.sort(list, function(a, b)
    if a.main ~= b.main then return a.main == true end
    if a.last ~= b.last then return a.last end
    return a.path < b.path
  end)
  return list
end

local function open(dir)
  c.fail(select(2, rex.exec.start({ "/bin/zsh", "-lc", 'MUX_FORCE_KIND=rex exec "$HOME/.local/bin/mux/mux" session "$0"', dir },
                                  { detach = true, env = c.REX_ENV })))
end

local function new_worktree(ctx, p)
  local bucket_items = {}
  for _, b in ipairs(BUCKETS) do table.insert(bucket_items, { id = b, title = b .. "/", icon = "folder" }) end
  table.insert(bucket_items, { id = NONE, title = NONE, subtitle = "directly under " .. p.name .. "/", icon = "folder" })
  local bucket, why = rex.ui.pick{ title = "New worktree in " .. p.name, placeholder = "Choose a folder", items = bucket_items }
  if bucket == nil then return stop(why) end

  local prefix = p.name .. "/" .. (bucket == NONE and "" or bucket .. "/")
  local branch
  branch, why = rex.ui.input{ title = prefix, placeholder = "Branch name", confirm = "Create worktree" }
  if branch == nil then return stop(why) end
  branch = branch:match("^%s*(.-)%s*$")
  if branch == "" then return end
  if git(p.dir, "check-ref-format", "--branch", branch) == nil then
    error("Not a valid branch name: " .. branch, 0)
  end

  local rel = bucket == NONE and branch or (bucket .. "/" .. branch)
  local dir = p.dir .. "/" .. rel
  remember(p.name, dir)
  local run = [[export WORKTREE_OPEN_IN=rex; if "$HOME/.local/bin/worktree/wt-add" "$0" "$1" "$2"; then "$HOME/.local/bin/mux/mux" session "$3"; else printf '\nwt-add failed. Press enter to close.'; read -r _; fi]]
  c.popup(ctx, 0.2, 0.2, { "/bin/zsh", "-lc", run, p.name, branch, rel, dir }, { label = "popup" })
end

function M.setup()
  rex.action{
    name = "project_picker",
    title = "Open Project",
    category = "Sessions",
    keywords = "worktree developer repo",
    run = function(ctx, args)
      if c.forward(ctx, "project_picker") then return end
      local items, by_id = {}, {}
      for _, p in ipairs(projects()) do
        by_id[p.dir] = p
        table.insert(items, {
          id = p.dir,
          title = p.name,
          subtitle = short(p.dir),
          icon = p.kind == "folder" and "folder" or "branch",
          detail = p.kind == "bare" and "worktrees" or nil,
        })
      end
      local picked, why = rex.ui.pick{ title = "Open project", placeholder = "Choose a project in ~/Developer", items = items }
      if picked == nil then return stop(why) end
      local p = by_id[picked]
      require("sessions").leave_session(ctx)

      local trees = p.kind ~= "folder" and worktrees(p) or {}
      if p.kind ~= "bare" and #trees <= 1 then
        remember(p.name, p.dir)
        return open(p.dir)
      end

      local rows = {}
      for _, w in ipairs(trees) do
        local rel = w.path:sub(#p.dir + 2)
        table.insert(rows, {
          id = w.path,
          title = rel ~= "" and rel or p.name,
          subtitle = w.branch or "detached",
          icon = "branch",
          detail = w.main and "main" or (w.last and "last" or nil),
        })
      end
      if p.kind == "bare" then table.insert(rows, { id = NEW, title = "New worktree…", subtitle = "wt-add from origin/HEAD", icon = "plus" }) end
      local choice
      choice, why = rex.ui.pick{ title = p.name, placeholder = "Choose a worktree", items = rows }
      if choice == nil then return stop(why) end
      if choice == NEW then return new_worktree(ctx, p) end
      remember(p.name, choice)
      open(choice)
    end,
  }
end

return M
