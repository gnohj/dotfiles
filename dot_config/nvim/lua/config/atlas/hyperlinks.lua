local M = {}

local ns = vim.api.nvim_create_namespace("config.atlas.hyperlinks")
local KEY_PATTERN = "%f[%w]()(%u[%u%d]+%-%d+)()%f[%W]"
local url_by_group, group_by_url, group_count = {}, {}, 0

-- Atlas drops extra span fields, so the URL rides through as a highlight group name.
local function url_group(url)
  if not group_by_url[url] then
    group_count = group_count + 1
    group_by_url[url] = "AtlasHyperlink" .. group_count
    url_by_group[group_by_url[url]] = url
  end
  return group_by_url[url]
end

local function mark_link_targets()
  local markdown = require("atlas.formats.markdown")
  local parse = markdown.parse
  markdown.parse = function(source, opts)
    local result = parse(source, opts)
    for _, target in ipairs(result.targets or {}) do
      if target.type == "link" and target.url:match("^https?://[%w%p]+$") then
        table.insert(result.highlights, {
          line = target.line,
          start_col = target.start_col,
          end_col = target.end_col,
          hl_group = url_group(target.url),
        })
      end
    end
    return result
  end
end

local function overlaps(spans, s, e)
  for _, span in ipairs(spans or {}) do
    if s < span[2] and e > span[1] then
      return true
    end
  end
  return false
end

-- url extmarks become OSC 8 hyperlinks, which herdr opens on Ctrl-click.
local function tag(buf, key_url)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local taken = {}
  local marks = vim.api.nvim_buf_get_extmarks(
    buf,
    -1,
    0,
    -1,
    { details = true, type = "highlight" }
  )
  for _, mark in ipairs(marks) do
    local row, col, info = mark[2], mark[3], mark[4]
    local url = url_by_group[info.hl_group]
    if url and info.end_row == row then
      vim.api.nvim_buf_set_extmark(
        buf,
        ns,
        row,
        col,
        { end_row = row, end_col = info.end_col, url = url }
      )
      taken[row] = taken[row] or {}
      table.insert(taken[row], { col, info.end_col })
    end
  end
  for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    for s, key, e in line:gmatch(KEY_PATTERN) do
      local url = key_url(key)
      if url and not overlaps(taken[row - 1], s - 1, e - 1) then
        vim.api.nvim_buf_set_extmark(buf, ns, row - 1, s - 1, {
          end_row = row - 1,
          end_col = e - 1,
          url = url,
          hl_group = "AtlasHyperlinkKey",
        })
      end
    end
  end
end

local function project(key)
  return type(key) == "string" and key:match("^(%u[%u%d]+)%-%d+$")
end

-- Only projects the item touches, so UTF-8 never becomes a link.
local function key_url(jira_url, keys)
  local projects = {}
  for _, key in ipairs(keys) do
    local name = project(key)
    if name then
      projects[name] = true
    end
  end
  return function(key)
    return projects[project(key)] and (jira_url .. "/browse/" .. key) or nil
  end
end

local function issue_keys()
  local state = require("atlas.issues.ui.detail.state")
  local keys = { state.current_issue and state.current_issue.key }
  local details = state.current_details
  for _, item in ipairs(details and details.links or {}) do
    table.insert(keys, item.key)
  end
  for _, entry in pairs(state.line_map or {}) do
    table.insert(keys, type(entry) == "table" and entry.issue_key)
  end
  return keys
end

local function pr_keys()
  local pr = require("atlas.pulls.ui.detail.state").current_pr or {}
  local branch = type(pr.source) == "table" and pr.source.branch or ""
  local keys = {}
  for text in vim.iter({ branch, pr.title or "" }) do
    for key in text:gmatch("%u[%u%d]+%-%d+") do
      table.insert(keys, key)
    end
  end
  return keys
end

local function after_render(module, state_module, keys)
  local render = module.render
  module.render = function(...)
    local result = render(...)
    local buf = require(state_module).buf
    if buf and vim.api.nvim_buf_is_valid(buf) then
      tag(buf, keys())
    end
    return result
  end
end

function M.at_cursor()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local marks = vim.api.nvim_buf_get_extmarks(
    0,
    ns,
    { row - 1, 0 },
    { row - 1, -1 },
    { details = true }
  )
  for _, mark in ipairs(marks) do
    if col >= mark[3] and col < mark[4].end_col then
      return mark[4].url
    end
  end
end

local function set_key_hl()
  vim.api.nvim_set_hl(0, "AtlasHyperlinkKey", { underline = true })
end

function M.setup(jira_url)
  set_key_hl()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = set_key_hl })
  mark_link_targets()
  after_render(
    require("atlas.issues.ui.detail.renderer"),
    "atlas.issues.ui.detail.state",
    function()
      return key_url(jira_url, issue_keys())
    end
  )
  after_render(
    require("atlas.pulls.ui.detail.renderer"),
    "atlas.pulls.ui.detail.state",
    function()
      return key_url(jira_url, pr_keys())
    end
  )
end

return M
