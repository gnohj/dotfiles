local M = {}

local KEY_PATTERN = "%u[%u%d]+%-%d+"
local URL_PATTERN = "https?://[^%s%)%]>\"'`]+"

local function linked(relation, issue)
  local fields = type(issue.fields) == "table" and issue.fields or {}
  return {
    relation = relation,
    key = issue.key,
    summary = fields.summary or "",
    status = type(fields.status) == "table" and fields.status.name or "",
  }
end

function M.collect(raw_fields)
  local items = {}
  local parent = raw_fields.parent
  if type(parent) == "table" and parent.key then
    table.insert(items, linked("parent", parent))
  end
  for _, subtask in
    ipairs(type(raw_fields.subtasks) == "table" and raw_fields.subtasks or {})
  do
    table.insert(items, linked("subtask", subtask))
  end
  for _, link in
    ipairs(
      type(raw_fields.issuelinks) == "table" and raw_fields.issuelinks or {}
    )
  do
    local link_type = type(link.type) == "table" and link.type or {}
    if type(link.outwardIssue) == "table" then
      table.insert(
        items,
        linked(link_type.outward or "links to", link.outwardIssue)
      )
    elseif type(link.inwardIssue) == "table" then
      table.insert(
        items,
        linked(link_type.inward or "linked from", link.inwardIssue)
      )
    end
  end
  return items
end

function M.append(lines, highlights, line_map, items)
  if not items or #items == 0 then
    return
  end
  vim.list_extend(lines, { "", " Linked issues", "" })
  table.insert(highlights, {
    line = #lines - 2,
    start_col = 1,
    end_col = #lines[#lines - 1],
    hl_group = "Title",
  })
  local width = 0
  for _, item in ipairs(items) do
    width = math.max(width, vim.fn.strdisplaywidth(item.relation))
  end
  for _, item in ipairs(items) do
    local relation = " "
      .. item.relation
      .. string.rep(" ", width - vim.fn.strdisplaywidth(item.relation))
    local key = "  " .. item.key
    local status = item.status ~= "" and ("  [" .. item.status .. "]") or ""
    table.insert(lines, relation .. key .. status .. "  " .. item.summary)
    local line, col = #lines - 1, 0
    local function span(text, hl)
      table.insert(
        highlights,
        { line = line, start_col = col, end_col = col + #text, hl_group = hl }
      )
      col = col + #text
    end
    span(relation, "Comment")
    span(key, "AtlasJiraKey")
    span(status, "Special")
    line_map[#lines] = { issue_key = item.key }
  end
end

local function matches(line, col, pattern)
  local first, init = nil, 1
  while true do
    local s, e = line:find(pattern, init)
    if not s then
      return nil, first
    end
    local match = line:sub(s, e)
    if col + 1 >= s and col + 1 <= e then
      return match, first or match
    end
    first = first or match
    init = e + 1
  end
end

function M.target(entry, line, col, jira_url)
  if entry and entry.issue_key then
    return jira_url .. "/browse/" .. entry.issue_key
  end
  local url_here, url_first = matches(line, col, URL_PATTERN)
  local key_here, key_first = matches(line, col, KEY_PATTERN)
  local url = url_here or (not key_here and url_first)
  if url then
    return (url:gsub("[.,;:]+$", ""))
  end
  local key = key_here or key_first
  if key then
    return jira_url .. "/browse/" .. key
  end
end

-- Only what sits under the cursor, so lines without a link fall through to Atlas's own Enter.
function M.target_here(line, col, jira_url)
  local url = matches(line, col, URL_PATTERN)
  if url then
    return (url:gsub("[.,;:]+$", ""))
  end
  local key = matches(line, col, KEY_PATTERN)
  return key and (jira_url .. "/browse/" .. key)
end

function M.on_back_chip(line, col)
  local label = M.previous_label()
  local chip = label and ("← " .. label .. " (q)")
  local start = chip and line:find(chip, 1, true)
  return start ~= nil and col + 1 >= start and col + 1 <= start + #chip
end

local trail = {}

local function issue_detail()
  return require("atlas.issues.ui.detail")
end

local function pr_detail()
  return require("atlas.pulls.ui.detail")
end

-- Atlas keeps one detail panel per tab and closes the old one first, which fails on a full-tab panel.
local function spare_window_if_alone()
  local tiled = vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative == ""
  end, vim.api.nvim_tabpage_list_wins(0))
  if #tiled == 1 and vim.bo.filetype == "atlas-ui.detail" then
    vim.cmd("noautocmd botright vnew")
  end
end

local function reopen(entry, back)
  spare_window_if_alone()
  local opts = { provider = entry.provider, back = back }
  if entry.kind == "pr" then
    pr_detail().open(entry.ref, opts)
  else
    issue_detail().open_ref({ key = entry.key }, opts)
  end
end

function M.go_back()
  local previous = table.remove(trail)
  if not previous then
    return false
  end
  reopen(previous, #trail > 0 and M.go_back or nil)
  return true
end

function M.previous_label()
  local previous = trail[#trail]
  if not previous then
    return nil
  end
  return previous.kind == "pr" and ("#" .. previous.ref.id) or previous.key
end

-- Opening an item any other way (dashboard, X, gl) starts a fresh trail.
function M.setup()
  local openers = {
    { issue_detail(), { "open", "open_ref" } },
    { pr_detail(), { "open" } },
  }
  for _, opener in ipairs(openers) do
    local module = opener[1]
    for _, name in ipairs(opener[2]) do
      local open = module[name]
      module[name] = function(target, opts)
        if not (opts and opts.back == M.go_back) then
          trail = {}
        end
        return open(target, opts)
      end
    end
  end
end

local function push_current()
  if vim.bo.filetype ~= "atlas-ui.detail" then
    return
  end
  local issue_state = require("atlas.issues.ui.detail.state")
  local pr_state = require("atlas.pulls.ui.detail.state")
  local in_pr = vim.api.nvim_buf_get_name(0):find("atlas://pulls/", 1, true)
  if in_pr and pr_state.current_pr and pr_state.provider then
    local pr = pr_state.current_pr
    local ref = { id = pr.id, repo_full_name = pr.repo_full_name }
    table.insert(
      trail,
      { kind = "pr", ref = ref, provider = pr_state.provider }
    )
  elseif issue_state.current_issue and issue_state.provider then
    local key = issue_state.current_issue.key
    table.insert(
      trail,
      { kind = "issue", key = key, provider = issue_state.provider }
    )
  end
end

local function resolve(url)
  local providers = require("atlas.providers")
  local ok, target = pcall(providers.resolve, url)
  if
    not ok
    or not target
    or not require("atlas.config").provider_options(target.provider)
  then
    return nil
  end
  local provider = providers.load(target.provider, target.domain)
  return provider and target, provider
end

-- A herdr split beside the dashboard; outside herdr, or inside that split already, the panel itself.
local function use_split()
  return vim.env.HERDR_ENV
    and vim.env.HERDR_PANE_ID
    and not vim.env.ATLAS_COMPANION
end

function M.open_here(target)
  if not target:match("^https?://") then
    target = require("atlas.config").options.providers.jira.base_url
      .. "/browse/"
      .. target
  end
  local resolved, provider = resolve(target)
  if not resolved then
    return false
  end
  push_current()
  spare_window_if_alone()
  local opts = { provider = provider, back = M.go_back }
  if resolved.entity == "issue" then
    local ref = provider.issue_ref(resolved)
    return ref and issue_detail().open_ref(ref, opts) or false
  end
  if resolved.entity == "pr" and resolved.id and resolved.repo_full_name then
    return pr_detail().open(
      { id = resolved.id, repo_full_name = resolved.repo_full_name },
      opts
    )
  end
  return false
end

function M.follow(url)
  local target, provider = resolve(url)
  local jump = require("config.atlas.herdr-jump")
  if target and target.entity == "issue" and provider then
    local ref = provider.issue_ref(target)
    if ref then
      if use_split() then
        return jump.open_jira(ref.key)
      end
      return M.open_here(url)
    end
  elseif
    target
    and target.entity == "pr"
    and target.id
    and target.repo_full_name
  then
    if use_split() then
      return jump.open_pr_url(url)
    end
    return M.open_here(url)
  end
  vim.ui.open(url)
end

M.use_split = use_split

return M
