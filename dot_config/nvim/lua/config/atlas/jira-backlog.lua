local M = {}

local options = {}
local sprint_rank, rank_loading = nil, false

local function load_sprint_rank()
  if sprint_rank or rank_loading then
    return
  end
  rank_loading = true
  local endpoint = string.format(
    "/rest/agile/1.0/board/%s/sprint?state=active,future&maxResults=100",
    options.board_id
  )
  require("atlas.providers.jira.client").request(
    "GET",
    endpoint,
    nil,
    function(result)
      vim.schedule(function()
        rank_loading = false
        sprint_rank = {}
        for index, sprint in
          ipairs(type(result) == "table" and result.values or {})
        do
          sprint_rank[sprint.id] = index
        end
        pcall(require("atlas.issues.ui.dashboard").render)
      end)
    end
  )
end

local function rank_of(sprint)
  local rank = sprint_rank and sprint_rank[sprint.id]
  return rank or (10000 + sprint.id)
end

local function open_sprint(issue)
  local best
  for _, sprint in
    ipairs(type(issue.sprints) == "table" and issue.sprints or {})
  do
    if
      sprint.state ~= "closed" and (not best or rank_of(sprint) < rank_of(best))
    then
      best = sprint
    end
  end
  return best
end

local function group_by_sprint(issues)
  local groups, by_id = {}, {}
  local backlog = { name = "Backlog", rank = math.huge, issues = {} }
  for _, issue in ipairs(issues) do
    local sprint = open_sprint(issue)
    local group = backlog
    if sprint then
      group = by_id[sprint.id]
      if not group then
        local name = sprint.state == "active" and (sprint.name .. " (active)")
          or sprint.name
        group = { name = name, rank = rank_of(sprint), issues = {} }
        by_id[sprint.id] = group
        table.insert(groups, group)
      end
    end
    table.insert(group.issues, issue)
  end
  table.sort(groups, function(a, b)
    return a.rank < b.rank
  end)
  if #backlog.issues > 0 then
    table.insert(groups, backlog)
  end
  return groups
end

local function points(issues)
  local total = 0
  for _, issue in ipairs(issues) do
    total = total + (tonumber(issue.story_points) or 0)
  end
  return total
end

local function tighten(rows, row_map, row_spans, keep_header)
  local first_row = math.huge
  for lnum in pairs(row_map) do
    first_row = math.min(first_row, lnum)
  end
  local new_index, lines, map, spans = {}, {}, {}, {}
  for lnum, text in ipairs(rows) do
    local header = lnum < first_row
    if vim.trim(text) ~= "" and (keep_header or not header) then
      table.insert(lines, text)
      new_index[lnum] = #lines
      map[#lines] = row_map[lnum]
    end
  end
  for _, span in ipairs(row_spans) do
    local line = new_index[span.line + 1]
    if line then
      table.insert(spans, vim.tbl_extend("force", span, { line = line - 1 }))
    end
  end
  return lines, map, spans
end

function M.render(opts, issues)
  if opts.loading and #issues == 0 then
    return { " " .. (opts.spinner or "") .. " Loading..." }, {}, {}
  end
  load_sprint_rank()
  local utils = require("atlas.ui.shared.utils")
  local rows_layout = require("atlas.issues.ui.layouts.plain")
  local row_opts = vim.tbl_extend("force", opts, { loading = false })
  row_opts.groups = nil
  local lines, spans, line_map = {}, {}, {}
  for index, group in ipairs(group_by_sprint(issues)) do
    if index > 1 then
      table.insert(lines, "")
    end
    local title = " " .. group.name
    local count = string.format(
      "  %d issue%s · %g pts",
      #group.issues,
      #group.issues == 1 and "" or "s",
      points(group.issues)
    )
    table.insert(lines, title .. count)
    table.insert(
      spans,
      { line = #lines - 1, start_col = 0, end_col = #title, hl_group = "Title" }
    )
    table.insert(spans, {
      line = #lines - 1,
      start_col = #title,
      end_col = #title + #count,
      hl_group = "Comment",
    })
    local rows, row_map, row_spans = rows_layout.render(
      row_opts,
      group.issues,
      rows_layout[opts.provider_id] or rows_layout.default
    )
    rows, row_map, row_spans = tighten(rows, row_map, row_spans, index == 1)
    local base = #lines
    utils.append_block(lines, spans, { lines = rows, highlights = row_spans })
    for lnum, node in pairs(row_map) do
      line_map[base + lnum] = node
    end
  end
  if #lines == 0 then
    return { " No issues found." }, {}, {}
  end
  return lines, line_map, spans
end

local function is_backlog_search(data)
  for _, view in ipairs(require("atlas.config").options.issues.jira.views) do
    if view.layout == "sprints" and view.jql == data.jql then
      return true
    end
  end
  return false
end

-- Sprint groups are only whole when every page is loaded, so follow nextPageToken to the end.
local function fetch_all(request, endpoint, data, on_done, ...)
  local issues, extra = {}, { ... }
  local function step(page_data)
    return request("POST", endpoint, page_data, function(result, err)
      if err or type(result) ~= "table" then
        return on_done(result, err)
      end
      vim.list_extend(issues, result.issues or {})
      if result.nextPageToken and not result.isLast and #issues < 3000 then
        local next_page = { nextPageToken = result.nextPageToken }
        return step(vim.tbl_extend("force", page_data, next_page))
      end
      local merged = { issues = issues, nextPageToken = vim.NIL, isLast = true }
      on_done(vim.tbl_extend("force", result, merged), nil)
    end, unpack(extra))
  end
  return step(data)
end

-- Search results carry no sprint, so request the field and copy it onto each mapped issue.
function M.setup(opts)
  options = opts
  local client = require("atlas.providers.jira.client")
  local request = client.request
  client.request = function(method, endpoint, data, ...)
    if
      method == "POST"
      and endpoint:match("/search")
      and type(data) == "table"
      and data.fields
    then
      if not vim.tbl_contains(data.fields, opts.sprint_field) then
        table.insert(data.fields, opts.sprint_field)
      end
      data.maxResults = 100
      if is_backlog_search(data) then
        return fetch_all(request, endpoint, data, ...)
      end
    elseif method == "GET" and endpoint:match("^/issue/[^/?]+%?fields=") then
      if not endpoint:find(opts.sprint_field, 1, true) then
        endpoint =
          endpoint:gsub("%?fields=", "?fields=" .. opts.sprint_field .. ",", 1)
      end
    end
    return request(method, endpoint, data, ...)
  end

  local mapper = require("atlas.issues.providers.jira.api.mapper")
  local to_issue = mapper.to_issue
  mapper.to_issue = function(raw, ...)
    local issue = to_issue(raw, ...)
    local fields = type(raw) == "table" and raw.fields
    issue.sprints = type(fields) == "table" and fields[opts.sprint_field] or nil
    return issue
  end

  local layouts = require("atlas.issues.ui.layouts")
  local resolve, render = layouts.resolve, layouts.render
  layouts.resolve = function(layout, ...)
    return layout == "sprints" and "sprints" or resolve(layout, ...)
  end
  layouts.render = function(layout_opts, issues)
    if layout_opts.layout == "sprints" then
      return M.render(layout_opts, issues)
    end
    return render(layout_opts, issues)
  end
end

return M
