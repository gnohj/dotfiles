local M = {}

local atlas_actions = {
  Status = "transition",
  Assignee = "assign",
  Reporter = "reporter",
}

local function client()
  return require("atlas.providers.jira.client")
end

local function item_name(item)
  return item.name or item.value or item.displayName or tostring(item.id)
end

local function notify_error(err)
  vim.notify(err or "Jira update failed", vim.log.levels.ERROR)
end

local function save(key, field, value, done)
  local fields = { [field.id] = value }
  require("atlas.issues.providers.jira.api.issues").update_issue(
    key,
    fields,
    function(ok, err)
      vim.schedule(function()
        if not ok then
          return notify_error(err)
        end
        vim.notify(string.format("%s %s updated", key, field.name))
        done({ issue_key = key })
      end)
    end
  )
end

local function pick(items, prompt, format, on_choice)
  vim.ui.select(
    items,
    { prompt = prompt, format_item = format },
    function(choice)
      if choice then
        on_choice(choice)
      end
    end
  )
end

local function edit_single(key, field, meta, current, done)
  local none = { name = "(none)" }
  local items = vim.list_extend({ none }, meta.allowedValues)
  local current_id = type(current) == "table" and current.id
  pick(items, field.name, function(item)
    return (item.id and item.id == current_id and "✓ " or "  ")
      .. item_name(item)
  end, function(choice)
    save(key, field, choice == none and vim.NIL or { id = choice.id }, done)
  end)
end

local function edit_multi(key, field, meta, current, done)
  local selected = {}
  for _, item in ipairs(type(current) == "table" and current or {}) do
    selected[item.id] = true
  end
  pick(meta.allowedValues, field.name .. " (toggle)", function(item)
    return (selected[item.id] and "✓ " or "  ") .. item_name(item)
  end, function(choice)
    selected[choice.id] = not selected[choice.id] or nil
    local value = {}
    for id in pairs(selected) do
      table.insert(value, { id = id })
    end
    save(key, field, value, done)
  end)
end

local function input(prompt, default, on_confirm)
  vim.ui.input({ prompt = prompt .. ": ", default = default }, function(text)
    if text then
      on_confirm(vim.trim(text))
    end
  end)
end

local function edit_labels(key, field, current, done)
  local default = table.concat(type(current) == "table" and current or {}, ", ")
  input(field.name, default, function(text)
    local labels = vim.split(text, "[,%s]+", { trimempty = true })
    save(key, field, labels, done)
  end)
end

local function edit_user(key, field, done)
  input(field.name .. " search", "", function(query)
    local endpoint = "/user/search?query=" .. vim.uri_encode(query)
    client().request("GET", endpoint, nil, function(users, err)
      vim.schedule(function()
        if err or type(users) ~= "table" then
          return notify_error(err)
        end
        local none = { displayName = "(none)" }
        local people = vim.tbl_filter(function(user)
          return user.accountType == "atlassian"
        end, users)
        pick(
          vim.list_extend({ none }, people),
          field.name,
          item_name,
          function(user)
            local value = user == none and vim.NIL
              or { accountId = user.accountId }
            save(key, field, value, done)
          end
        )
      end)
    end)
  end)
end

local function edit_scalar(key, field, schema, current, done)
  local default = type(current) == "table" and (current.key or "")
    or tostring(current or "")
  input(field.name, default, function(text)
    if text == "" then
      return save(key, field, vim.NIL, done)
    end
    if schema.type == "number" then
      local number = tonumber(text)
      if not number then
        return notify_error(field.name .. " must be a number")
      end
      return save(key, field, number, done)
    end
    save(
      key,
      field,
      schema.type == "issuelink" and { key = text } or text,
      done
    )
  end)
end

local function edit_field(ctx, field, done)
  local key = ctx.issue.key
  local endpoint =
    string.format("/issue/%s?fields=%s&expand=editmeta", key, field.id)
  client().request("GET", endpoint, nil, function(issue, err)
    vim.schedule(function()
      if err or type(issue) ~= "table" then
        return notify_error(err)
      end
      local meta = issue.editmeta and issue.editmeta.fields[field.id]
      if not meta then
        return vim.notify(
          field.name .. " is not editable on " .. key,
          vim.log.levels.WARN
        )
      end
      local schema = meta.schema or {}
      local current = issue.fields and issue.fields[field.id]
      if schema.custom and schema.custom:match("gh%-sprint$") then
        return vim.notify(
          "Move sprints from the Jira board (gB)",
          vim.log.levels.WARN
        )
      elseif schema.type == "array" and schema.items == "string" then
        edit_labels(key, field, current, done)
      elseif schema.type == "array" and meta.allowedValues then
        edit_multi(key, field, meta, current, done)
      elseif meta.allowedValues then
        edit_single(key, field, meta, current, done)
      elseif schema.type == "user" then
        edit_user(key, field, done)
      else
        edit_scalar(key, field, schema, current, done)
      end
    end)
  end)
end

local function run(ctx, field, done)
  local action = field.action or atlas_actions[field.name]
  if action then
    return require("atlas.issues.actions").run(action, ctx, done)
  end
  edit_field(ctx, field, done)
end

local function editable_fields(fields)
  local list = {
    { name = "Title & description", action = "edit_issue" },
    { name = "Status" },
    { id = "priority", name = "Priority" },
    { name = "Assignee" },
    { name = "Reporter" },
  }
  for _, field in ipairs(fields) do
    if not field.section then
      table.insert(list, field)
    end
  end
  return list
end

local function field_at_cursor(fields, line, col)
  local best
  for _, field in ipairs(fields) do
    local start = line:find(field.name .. ":", 1, true)
    if start and start - 1 <= col and (not best or start > best.start) then
      best = { field = field, start = start }
    end
  end
  if best then
    return best.field
  end
  for _, field in ipairs(fields) do
    if line:find(field.name .. ":", 1, true) then
      return field
    end
  end
end

local function tab_bar_line(buf)
  for i, text in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if text:find("Overview", 1, true) and text:find("History", 1, true) then
      return i
    end
  end
end

local function detail_target(fields)
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "atlas-ui.detail" then
    return nil
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local tabs = tab_bar_line(buf)
  if row <= 2 then
    return fields[1]
  end
  if tabs and row > tabs then
    local tab = require("atlas.issues.ui.detail.state").current_tab
    return tab == "overview" and fields[1] or nil
  end
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
  return field_at_cursor(fields, line, col)
end

function M.edit(ctx, done, jira_fields)
  if not (ctx and ctx.issue) then
    return
  end
  local fields = editable_fields(jira_fields)
  local target = detail_target(fields)
  if target then
    return run(ctx, target, done)
  end
  pick(fields, "Edit " .. ctx.issue.key, function(field)
    return field.name
  end, function(field)
    run(ctx, field, done)
  end)
end

return M
