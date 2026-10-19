local M = {}

local MAX_CHILDREN = 1000
local cache = {}

local function child(raw, points_field)
  local fields = raw.fields or {}
  local status = type(fields.status) == "table" and fields.status or {}
  local category = type(status.statusCategory) == "table"
      and status.statusCategory.key
    or ""
  return {
    key = raw.key,
    summary = fields.summary or "",
    status = status.name or "",
    done = category == "done",
    priority = type(fields.priority) == "table" and fields.priority.name or "",
    assignee = type(fields.assignee) == "table" and fields.assignee.displayName
      or "Unassigned",
    points = tonumber(fields[points_field]),
  }
end

local function fetch(key, points_field, on_done)
  local client = require("atlas.providers.jira.client")
  local items = {}
  local function step(token)
    local data = {
      jql = string.format("parent = %s ORDER BY Rank ASC", key),
      fields = { "summary", "status", "priority", "assignee", points_field },
      maxResults = 100,
      nextPageToken = token,
    }
    client.request("POST", "/search/jql", data, function(result, err)
      vim.schedule(function()
        if err or type(result) ~= "table" then
          return on_done(nil)
        end
        for _, raw in ipairs(result.issues or {}) do
          table.insert(items, child(raw, points_field))
        end
        if
          result.nextPageToken
          and not result.isLast
          and #items < MAX_CHILDREN
        then
          return step(result.nextPageToken)
        end
        on_done(items)
      end)
    end)
  end
  step(nil)
end

local function is_epic(issue)
  local issue_type = issue and issue.type
  local name = type(issue_type) == "table" and issue_type.name or issue_type
  return name == "Epic"
end

local function progress_bar(done, total, width)
  local filled = total > 0 and math.floor(done / total * width + 0.5) or 0
  return string.rep("█", filled), string.rep("░", width - filled)
end

function M.append(lines, highlights, line_map, issue, points_field)
  if not is_epic(issue) then
    return
  end
  local key = issue.key
  local entry = cache[key]
  if not entry then
    entry = { loading = true }
    cache[key] = entry
    fetch(key, points_field, function(items)
      cache[key] = { items = items or {}, failed = items == nil }
      local state = require("atlas.issues.ui.detail.state")
      if state.current_issue and state.current_issue.key == key then
        require("atlas.issues.ui.detail.renderer").render()
      end
    end)
  end
  vim.list_extend(lines, { "", " Child work items", "" })
  table.insert(highlights, {
    line = #lines - 2,
    start_col = 1,
    end_col = #lines[#lines - 1],
    hl_group = "Title",
  })
  if entry.loading or entry.failed then
    table.insert(
      lines,
      entry.loading and " Loading..." or " Could not load child work items"
    )
    table.insert(highlights, {
      line = #lines - 1,
      start_col = 0,
      end_col = #lines[#lines],
      hl_group = "Comment",
    })
    return
  end
  local items = entry.items
  local done = #vim.tbl_filter(function(item)
    return item.done
  end, items)
  local filled, empty = progress_bar(done, #items, 40)
  local summary = string.format(
    "  %d%% done · %d of %d",
    #items > 0 and math.floor(done / #items * 100) or 0,
    done,
    #items
  )
  table.insert(lines, " " .. filled .. empty .. summary)
  local line = #lines - 1
  table.insert(highlights, {
    line = line,
    start_col = 1,
    end_col = 1 + #filled,
    hl_group = "DiagnosticOk",
  })
  table.insert(highlights, {
    line = line,
    start_col = 1 + #filled,
    end_col = 1 + #filled + #empty,
    hl_group = "Comment",
  })
  table.insert(lines, "")
  local status_width = 0
  for _, item in ipairs(items) do
    status_width = math.max(status_width, vim.fn.strdisplaywidth(item.status))
  end
  for _, item in ipairs(items) do
    local key_text = " " .. item.key
    local status = "  "
      .. item.status
      .. string.rep(" ", status_width - vim.fn.strdisplaywidth(item.status))
    local meta = string.format(
      "  %-8s %6s  %-18s",
      item.priority:sub(1, 8),
      item.points and (string.format("%g", item.points) .. " pts") or "-",
      item.assignee:sub(1, 18)
    )
    local text = key_text .. status .. meta .. "  " .. item.summary
    table.insert(lines, text)
    local row = #lines - 1
    local key_hl = item.done and "AtlasChildDone" or "AtlasJiraKey"
    table.insert(
      highlights,
      { line = row, start_col = 0, end_col = #key_text, hl_group = key_hl }
    )
    table.insert(highlights, {
      line = row,
      start_col = #key_text,
      end_col = #key_text + #status,
      hl_group = item.done and "Comment" or "Special",
    })
    table.insert(highlights, {
      line = row,
      start_col = #key_text + #status,
      end_col = #key_text + #status + #meta,
      hl_group = "Comment",
    })
    line_map[#lines] = { issue_key = item.key }
  end
end

function M.setup()
  local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
  vim.api.nvim_set_hl(
    0,
    "AtlasChildDone",
    { fg = comment.fg, strikethrough = true, default = true }
  )
end

return M
