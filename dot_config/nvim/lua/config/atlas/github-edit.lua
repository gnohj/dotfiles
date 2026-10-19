local M = {}

local FIELDS = {
  { id = "edit_pr", name = "Title & description" },
  { id = "edit_reviewers", name = "Reviewers" },
  { id = "edit_assignees", name = "Assignees" },
  { id = "labels", name = "Labels" },
  { id = "ready_for_review", name = "Mark ready for review" },
  { id = "convert_to_draft", name = "Convert to draft" },
}

local function actions()
  return require("atlas.pulls.actions")
end

local function available(context)
  return vim.tbl_filter(function(field)
    return actions().is_available(field.id, context)
  end, FIELDS)
end

local function pick(context, on_done)
  vim.ui.select(available(context), {
    prompt = "Edit #" .. tostring(context.pr.id),
    format_item = function(field)
      return field.name
    end,
  }, function(field)
    if field then
      actions().run(field.id, context, on_done)
    end
  end)
end

local function line_index(lines, pattern, from)
  for i = from or 1, #lines do
    if lines[i]:find(pattern) then
      return i
    end
  end
end

local function action_at_cursor(context)
  local state = require("atlas.pulls.ui.detail.state")
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local line = lines[row] or ""
  local tabs = line_index(lines, "Overview.*Commits")
  if row <= 3 then
    return "edit_pr"
  end
  if tabs and row < tabs then
    if line:find("Assignees:", 1, true) then
      local start = line:find("Assignees:", 1, true)
      local second = line:find("%S+:", start + 10)
      if not second or col + 1 < second then
        return "edit_assignees"
      end
    end
    if row == tabs - 2 then
      local s, e = line:find("%f[%w]draft%f[%W]")
      local toggle = "ready_for_review"
      if not s then
        s, e = line:find("%f[%w]open%f[%W]")
        toggle = "convert_to_draft"
      end
      if s and col + 1 >= s - 2 and col + 1 <= e then
        return toggle
      end
      return "labels"
    end
    return nil
  end
  if state.current_tab ~= "overview" then
    return nil
  end
  local reviewers = line_index(lines, "^%s*Reviewers %(", tabs)
  if reviewers and row >= reviewers then
    local finish = line_index(lines, "^%s*$", reviewers) or #lines
    return row < finish and "edit_reviewers" or nil
  end
  return "edit_pr"
end

function M.edit_detail()
  local state = require("atlas.pulls.ui.detail.state")
  local pr = state.current_pr
  if not (pr and state.provider) then
    return
  end
  local context = {
    provider = state.provider,
    pr = pr,
    details = state.current_details,
    buf = vim.api.nvim_get_current_buf(),
  }
  local function on_done(result)
    if result and result.changed_pr then
      require("atlas.pulls.ui.detail").refresh()
    end
  end
  local id = action_at_cursor(context)
  if id and actions().is_available(id, context) then
    return actions().run(id, context, on_done)
  end
  pick(context, on_done)
end

function M.edit_dashboard()
  local item = require("atlas.pulls.ui.dashboard.navigation").current_item()
  local pr = type(item) == "table" and item.pr
  local state = require("atlas.pulls.state")
  if type(pr) ~= "table" or not state.provider then
    return vim.notify("No PR selected", vim.log.levels.WARN)
  end
  local context = {
    provider = state.provider,
    pr = pr,
    current_user = state.current_user,
    buf = vim.api.nvim_get_current_buf(),
  }
  pick(context, function(result)
    if result and result.changed_pr then
      require("atlas.pulls.ui.dashboard.controller").refresh_pr(pr)
    end
  end)
end

return M
