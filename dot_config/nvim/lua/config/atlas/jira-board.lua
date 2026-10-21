local M = {}

local MARGIN = 1

local column_rank, rank_loading = nil, false

local function load_column_rank(board_id)
  if column_rank or rank_loading then
    return
  end
  rank_loading = true
  require("atlas.providers.jira.client").request(
    "GET",
    string.format("/rest/agile/1.0/board/%s/configuration", board_id),
    nil,
    function(result)
      vim.schedule(function()
        rank_loading = false
        column_rank = {}
        local config = type(result) == "table" and result.columnConfig or {}
        for index, column in ipairs(config.columns or {}) do
          for _, status in ipairs(column.statuses or {}) do
            column_rank[tostring(status.id)] = index
          end
        end
        pcall(require("atlas.issues.ui.dashboard").render)
      end)
    end
  )
end

local function board_order(statuses)
  local ranked = {}
  for index, status in ipairs(statuses or {}) do
    local rank = column_rank and column_rank[tostring(status.id)]
    ranked[index] = { status = status, rank = rank or math.huge, index = index }
  end
  table.sort(ranked, function(a, b)
    if a.rank ~= b.rank then
      return a.rank < b.rank
    end
    return a.index < b.index
  end)
  return vim.tbl_map(function(entry)
    return entry.status
  end, ranked)
end

local function status_groups(issues, statuses, provider)
  local groups, by_key = {}, {}
  local function group_for(id, name, status)
    local key = (id and id ~= "") and ("id:" .. id) or ("name:" .. (name or ""))
    if not by_key[key] then
      local icon = status and provider.column_icon(status) or ""
      local label = name and name ~= "" and name or "Unknown"
      by_key[key] = {
        name = icon ~= "" and (icon .. " " .. label) or label,
        issues = {},
      }
      table.insert(groups, by_key[key])
    end
    return by_key[key]
  end
  for _, status in ipairs(statuses or {}) do
    group_for(tostring(status.id or ""), status.name, status)
  end
  for _, issue in ipairs(issues) do
    local group = group_for(tostring(issue.status_id or ""), issue.status)
    table.insert(group.issues, issue)
  end
  return vim.tbl_filter(function(group)
    return #group.issues > 0
  end, groups)
end

local function trailing(issue)
  local person = require("atlas.issues.ui.layouts.utils")
  local truncate = require("atlas.ui.shared.utils").truncate
  local segments = {}
  if issue.parent then
    local icon = require("atlas.ui.shared.icons").get("link")
    local label = issue.parent.title ~= "" and issue.parent.title
      or issue.parent.key
    table.insert(segments, {
      text = icon .. " " .. truncate(label, 30),
      hl_group = "AtlasTextMuted",
    })
  end
  table.insert(segments, {
    text = person.person_value(issue.assignee, "Unassigned"),
    hl_group = person.person_hl(issue, "assignee") or "AtlasTextMuted",
  })
  return segments
end

local function stacked(groups, opts, provider)
  local lines, line_map, spans = {}, {}, {}
  local pad = string.rep(" ", MARGIN)
  local width = opts.width - 2 * MARGIN
  for index, group in ipairs(groups) do
    if index > 1 then
      table.insert(lines, "")
    end
    local header = string.format("%s (%d)", group.name, #group.issues)
    table.insert(lines, pad .. header)
    table.insert(spans, {
      line = #lines - 1,
      start_col = MARGIN,
      end_col = MARGIN + #header,
      hl_group = "AtlasColumnHeader",
    })
    for _, issue in ipairs(group.issues) do
      local tail = trailing(issue)
      local tail_width = 0
      for _, segment in ipairs(tail) do
        tail_width = tail_width + vim.fn.strdisplaywidth(segment.text) + 1
      end
      local kind = issue.icon and issue.icon.icon ~= "" and issue.icon
      local lead = kind and (kind.icon .. " ") or ""
      local card =
        provider.card(issue, width - tail_width - vim.fn.strdisplaywidth(lead))
      local text = pad .. lead .. card.text
      table.insert(lines, text)
      line_map[#lines] = { kind = "issue", issue = issue }
      if kind then
        table.insert(spans, {
          line = #lines - 1,
          start_col = MARGIN,
          end_col = MARGIN + #kind.icon,
          hl_group = kind.hl_group,
        })
      end
      for _, span in ipairs(card.spans) do
        table.insert(spans, {
          line = #lines - 1,
          start_col = MARGIN + #lead + span.start_col,
          end_col = MARGIN + #lead + span.end_col,
          hl_group = span.hl_group,
        })
      end
      for _, segment in ipairs(tail) do
        text = text .. " "
        table.insert(spans, {
          line = #lines - 1,
          start_col = #text,
          end_col = #text + #segment.text,
          hl_group = segment.hl_group,
        })
        text = text .. segment.text
      end
      lines[#lines] = text
    end
  end
  if opts.loading then
    vim.list_extend(lines, { "", " " .. (opts.spinner or "") .. " Loading..." })
  end
  return lines, line_map, spans
end

-- Atlas sorts board columns by status category and name, not by board column.
function M.setup(board_id)
  local board = require("atlas.issues.ui.layouts.board")
  local render = board.render
  board.render = function(opts, issues, provider)
    load_column_rank(board_id)
    opts =
      vim.tbl_extend("force", opts, { statuses = board_order(opts.statuses) })
    local groups = status_groups(issues, opts.statuses, provider)
    if #groups == 0 then
      return render(opts, issues, provider)
    end
    return stacked(groups, opts, provider)
  end
end

return M
