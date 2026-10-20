local jira_url = "https://ihm-it.atlassian.net"
local jira_board_id = 1254

local function jira_provider()
  if not (vim.env.JIRA_EMAIL and vim.env.JIRA_API_TOKEN) then
    return nil
  end
  return {
    base_url = jira_url,
    email = vim.env.JIRA_EMAIL,
    token = vim.env.JIRA_API_TOKEN,
    auth_method = "basic",
    api_type = "cloud",
  }
end

local review_paths = {
  ["iheartradio/web"] = "~/Developer/web/review/",
  ["iheartradio/inferno-monorepo"] = "~/Developer/inferno/review/",
}

local review_keys = {
  { "M", "full", "Lavish review on this machine" },
  { "Z", "full", "Lavish review on the dev box", true },
  { "D", "diff", "Diff in hunk + agent notes" },
  { "E", "enhance", "Checks in ENHANCE" },
  { "C", "claude", "Claude /review" },
}

local function current_pr()
  local item = require("atlas.pulls.ui.dashboard.navigation").current_item()
  local pr = type(item) == "table" and item.pr
  if type(pr) ~= "table" or not pr.repo_full_name then
    vim.notify("No PR selected", vim.log.levels.WARN)
    return nil
  end
  return pr
end

local function repo_path(repo)
  local path = review_paths[repo] or ("~/Developer/" .. repo:match("[^/]+$"))
  return vim.fn.expand(path)
end

local function review_open(mode, label, devbox)
  local pr = current_pr()
  if not pr then
    return
  end
  local name = devbox and "review-devbox.sh" or "review-open.sh"
  local script = vim.fn.expand("~/.config/gh-dash/" .. name)
  local args = { "bash", script, mode, tostring(pr.id), pr.repo_full_name }
  if not devbox then
    table.insert(args, repo_path(pr.repo_full_name))
  end
  vim.system(args, { detach = true })
  vim.notify(string.format("Starting %s for #%s", label, pr.id))
end

local function approve()
  local pr = current_pr()
  if not pr then
    return
  end
  local args = { "gh", "pr", "review", tostring(pr.id), "--approve" }
  vim.list_extend(args, { "--repo", pr.repo_full_name })
  vim.system(args, { text = true }, function(res)
    local ok = res.code == 0
    vim.schedule(function()
      vim.notify(
        ok and ("Approved #" .. pr.id) or vim.trim(res.stderr),
        ok and vim.log.levels.INFO or vim.log.levels.ERROR
      )
    end)
  end)
end

local function reclaim()
  local script = vim.fn.expand("~/.config/gh-dash/review-worktree.sh")
  vim.system({ "bash", script, "reclaim" }, { detach = true })
  vim.notify("Reclaiming idle treehouse review slots")
end

local function pr_jira_key(pr)
  local pattern = "%u[%u%d]+%-%d+"
  local branch = type(pr.source) == "table" and pr.source.branch or ""
  return branch:match(pattern) or (pr.title or ""):match(pattern)
end

local function jira_key()
  local item = require("atlas.pulls.ui.dashboard.navigation").current_item()
  local pr = type(item) == "table" and item.pr or {}
  local key = pr_jira_key(pr)
    or vim.api.nvim_get_current_line():match("%u[%u%d]+%-%d+")
  if not key then
    vim.notify("No Jira key on this PR", vim.log.levels.WARN)
  end
  return key
end

local function pick_and_open(choices)
  vim.ui.select(choices, {
    prompt = "Open in browser",
    format_item = function(c)
      return c.label
    end,
  }, function(choice)
    if choice and choice.url then
      vim.ui.open(choice.url)
    end
  end)
end

local function jira_choice(key)
  return { label = "Jira " .. key, url = jira_url .. "/browse/" .. key }
end

local function open_pr_links(pr)
  if type(pr) ~= "table" then
    return vim.notify("No PR selected", vim.log.levels.WARN)
  end
  local choices =
    { { label = "GitHub PR #" .. pr.id, url = pr.link and pr.link.html } }
  local key = pr_jira_key(pr)
  if key then
    table.insert(choices, jira_choice(key))
  end
  pick_and_open(choices)
end

local function open_issue_links(issue)
  local jump = require("config.atlas.herdr-jump")
  jump.linked_prs(issue, function(prs)
    local choices = { jira_choice(issue.key) }
    for _, pr in ipairs(prs) do
      table.insert(
        choices,
        { label = "GitHub " .. jump.pr_label(pr), url = pr.url }
      )
    end
    pick_and_open(choices)
  end)
end

local function jump_counterpart()
  return {
    key = "J",
    desc = "Open the linked PR or Jira ticket in a split",
    callback = function(ctx)
      require("config.atlas.herdr-jump").jump(ctx)
    end,
  }
end

local function open_links()
  return {
    key = "o",
    desc = "Open PR or Jira in browser",
    callback = function(ctx)
      if type(ctx) == "table" and ctx.issue then
        return open_issue_links(ctx.issue)
      end
      open_pr_links(require("config.atlas.herdr-jump").current_pr())
    end,
  }
end

local function open_jira_in_browser()
  local key = jira_key()
  if key then
    vim.ui.open(jira_url .. "/browse/" .. key)
  end
end

-- Atlas binds gs only on the issues dashboard; a custom key reaches the detail view too.
local function transition_issue(ctx, done)
  if ctx.issue then
    require("atlas.issues.actions").run("transition", ctx, done)
  end
end

local function adf_text(value)
  if type(value) == "table" then
    return require("atlas.formats.adf.to_markdown").to_markdown(value)
  end
  return value
end

local function field_text(value)
  if type(value) ~= "table" then
    return value ~= nil and tostring(value) or nil
  end
  if vim.islist(value) then
    local names = vim.tbl_map(field_text, value)
    return #names > 0 and table.concat(names, ", ") or nil
  end
  return value.displayName or value.name or value.value
end

local function parent_text(value)
  local summary = type(value.fields) == "table" and value.fields.summary
  return summary and (value.key .. " " .. summary) or value.key
end

local function date_text(value)
  local y, mo, d, h, mi, sign, oh, om =
    value:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):%d+[%.%d]*([+-])(%d%d)(%d%d)$")
  if not y then
    return value
  end
  local wall = os.time({ year = y, month = mo, day = d, hour = h, min = mi })
  local local_offset = os.time() - os.time(os.date("!*t"))
  local offset = (sign == "-" and -1 or 1) * (oh * 3600 + om * 60)
  return os.date("%B %-d, %Y at %-I:%M %p", wall + local_offset - offset)
end

local jira_fields = {
  { "parent", "Parent", parent_text },
  { "customfield_10587", "Target Release" },
  { "fixVersions", "Fix versions" },
  { "customfield_10131", "TestEng Required" },
  { "customfield_10802", "DQA Required" },
  { "customfield_10010", "Sprint" },
  { "customfield_10022", "Story Points" },
  { "customfield_10038", "Developer" },
  { "components", "Components" },
  { "labels", "Labels" },
  { "customfield_10801", "UXD Owner" },
  { "customfield_10132", "TestEng Owner" },
  { "customfield_10596", "Issue Source" },
  { "customfield_10533", "Found by" },
  { "customfield_17316", "Defect Category" },
  { "customfield_10579", "Escaped Bug" },
  { "customfield_10620", "Exists on Prod" },
  { "customfield_10611", "Test Case Required" },
  { "customfield_10614", "Analytics Required" },
  { "customfield_10615", "Analytics Owner" },
  { "customfield_10134", "Country" },
  { "customfield_10503", "Severity" },
  { "customfield_10088", "Start date" },
  { "customfield_10136", "TestEng Points" },
  { "created", "Created", date_text },
  { "updated", "Updated", date_text },
  { "resolutiondate", "Resolved", date_text },
  { "customfield_10111", "Acceptance Criteria", "section" },
  { "customfield_10613", "Weekly Status", "section" },
  { "customfield_10535", "Technical Notes", "section" },
  { "customfield_10106", "Testing Notes", "section" },
  { "customfield_10612", "Change Log", "section" },
  { "attachment", "Attachments", "attachments" },
}

local function edit_issue(ctx, done)
  local fields = vim.tbl_map(function(f)
    return { id = f[1], name = f[2], section = type(f[3]) == "string" }
  end, jira_fields)
  require("config.atlas.jira-edit").edit(ctx, done, fields)
end

local show_mine = true

local function scoped_view(view)
  local mine = " AND (assignee = currentUser() OR Developer = currentUser())"
  view.jql = view.base .. (show_mine and mine or "") .. " ORDER BY Rank ASC"
  view.name = view.label
  return view
end

-- Atlas copies view configs on setup, so rescope its copies and reload the current one.
local function toggle_scope()
  show_mine = not show_mine
  for _, view in ipairs(require("atlas.config").options.issues.jira.views) do
    if view.base then
      scoped_view(view)
    end
  end
  local state = require("atlas.issues.state")
  if state.view and state.view.base then
    require("atlas.issues.ui.dashboard.controller").switch_view(state.view)
  else
    require("atlas.issues.ui.dashboard").render()
  end
  vim.notify(show_mine and "Showing my issues" or "Showing everyone's issues")
end

local function jira_project_config()
  local fields = {}
  for _, f in ipairs(jira_fields) do
    local formats = {
      section = adf_text,
      attachments = function(value)
        return value
      end,
    }
    fields[f[1]] = {
      name = f[2],
      display = type(f[3]) == "string" and f[3] or "table",
      format = formats[f[3]] or type(f[3]) == "function" and f[3] or field_text,
    }
  end
  return fields
end

-- Header rows stay in custom_fields; sections and attachments move out so only Overview shows them.
local function split_fields(details, raw)
  local rank = {}
  for i, f in ipairs(jira_fields) do
    rank[f[2]] = i
  end
  local rows = {}
  details.sections, details.attachments = {}, {}
  for _, field in ipairs(details.custom_fields) do
    if field.display == "section" then
      table.insert(details.sections, field)
    elseif field.display == "attachments" then
      details.attachments = field.formatted
    else
      table.insert(rows, field)
    end
  end
  local shown = {}
  for _, row in ipairs(rows) do
    shown[row.name] = true
  end
  local editable = type(raw) == "table" and raw.editmeta and raw.editmeta.fields
    or {}
  for _, f in ipairs(jira_fields) do
    if type(f[3]) ~= "string" and not shown[f[2]] and editable[f[1]] then
      table.insert(rows, {
        name = f[2],
        formatted = "None",
        hl_group = "AtlasTextMuted",
        display = "table",
      })
    end
  end
  table.sort(rows, function(a, b)
    return (rank[a.name] or math.huge) < (rank[b.name] or math.huge)
  end)
  table.sort(details.sections, function(a, b)
    return rank[a.name] < rank[b.name]
  end)
  details.custom_fields = rows
  local raw_fields = type(raw) == "table" and raw.fields or {}
  details.links = require("config.atlas.jira-links").collect(raw_fields)
  return details
end

local function with_sections(details)
  local parts = { details.description or "" }
  for _, field in ipairs(details.sections or {}) do
    table.insert(parts, "## " .. field.name .. "\n\n" .. field.formatted)
  end
  return vim.tbl_extend(
    "force",
    details,
    { description = vim.trim(table.concat(parts, "\n\n")) }
  )
end

local function issue_detail_ratio()
  local dashboard = require("atlas.issues.ui.dashboard.window")
  return dashboard.is_active() and 0.75 or 0.45
end

local function size_issue_detail()
  local ratio = issue_detail_ratio()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "atlas-ui.detail" then
      local width = math.max(math.floor(vim.o.columns * ratio), 40)
      pcall(vim.api.nvim_win_set_width, win, width)
    end
  end
end

-- Atlas pins the issue detail split to 45% on open and on every VimResized.
local function extend_issue_detail_width()
  local window = require("atlas.issues.ui.detail.window")
  local open = window.open
  window.open = function(...)
    local result = { open(...) }
    vim.schedule(size_issue_detail)
    return unpack(result)
  end
  -- Scheduled after other handlers; returning from an external app was evening the split out.
  vim.api.nvim_create_autocmd({ "VimResized", "FocusGained" }, {
    group = vim.api.nvim_create_augroup("AtlasIssueDetailWidth", {}),
    callback = function()
      vim.schedule(size_issue_detail)
    end,
  })
end

-- Atlas keeps custom fields in hash order and renders only Description in Overview.
local function extend_issue_details()
  local mapper = require("atlas.issues.providers.jira.api.mapper")
  local to_issue_details = mapper.to_issue_details
  mapper.to_issue_details = function(raw, ...)
    return split_fields(to_issue_details(raw, ...), raw)
  end
  local client = require("atlas.providers.jira.client")
  local request = client.request
  client.request = function(method, endpoint, ...)
    if method == "GET" and endpoint:match("^/issue/[^/?]+%?fields=") then
      endpoint = endpoint:gsub("%?fields=", "?fields=issuelinks,subtasks,", 1)
        .. "&expand=editmeta"
    end
    return request(method, endpoint, ...)
  end
  local navbar = require("atlas.ui.components.navbar")
  local render_navbar = navbar.render
  navbar.render = function(nav)
    local scoped = vim.iter(nav.items or {}):any(function(item)
      return item.label and item.label:find("Active sprint", 1, true)
    end)
    if scoped then
      local scope = show_mine and "Mine" or "Everyone"
      nav = vim.tbl_extend("force", nav, {
        actions = vim.list_extend(
          { { label = scope .. " ⇄ (m)", hl_group = "Special" } },
          nav.actions or {}
        ),
      })
    end
    return render_navbar(nav)
  end
  local dashboard = require("atlas.issues.ui.dashboard")
  local init = dashboard.init
  local function close_issue_detail()
    if require("atlas.issues.ui.detail").is_open() then
      require("atlas.issues.ui.detail").close()
    end
  end
  dashboard.init = function(...)
    init(...)
    close_issue_detail()
  end
  local toggle_detail = dashboard.toggle_detail
  dashboard.toggle_detail = function()
    local detail = require("atlas.issues.ui.detail")
    local was_open = detail.is_open()
    toggle_detail()
    local win = require("atlas.issues.ui.detail.state").win
    if not was_open and detail.is_open() and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
    end
  end
  local controller = require("atlas.issues.ui.dashboard.controller")
  local switch_view = controller.switch_view
  controller.switch_view = function(view)
    switch_view(view)
    close_issue_detail()
  end
  local links = require("config.atlas.jira-links")
  links.setup()
  require("config.atlas.jira-children").setup()
  require("config.atlas.jira-board").setup(jira_board_id)
  local detail_ui = require("atlas.issues.providers.jira.ui.detail")
  local chips = detail_ui.chips
  detail_ui.chips = function(...)
    local list = chips(...)
    local previous = links.previous_label()
    if previous then
      table.insert(
        list,
        1,
        { label = "← " .. previous .. " (q)", hl = "AtlasChipActive" }
      )
    end
    return list
  end
  local overview = require("atlas.issues.providers.jira.ui.overview")
  local render = overview.render
  overview.render = function(issue, details, width)
    local lines, highlights, line_map =
      render(issue, details and with_sections(details), width)
    line_map = line_map or {}
    require("config.atlas.jira-children").append(
      lines,
      highlights,
      line_map,
      issue,
      "customfield_10022"
    )
    require("config.atlas.jira-links").append(
      lines,
      highlights,
      line_map,
      details and details.links
    )
    local attachments = require("config.atlas.jira-attachments")
    attachments.append(
      lines,
      highlights,
      line_map,
      details and details.attachments
    )
    return lines, highlights, line_map
  end
end

local function attachment_at_cursor()
  local state = require("atlas.issues.ui.detail.state")
  local attachments = state.current_details
    and state.current_details.attachments
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_get_current_line()
  return require("config.atlas.jira-attachments").at_line(
    state.line_map[row],
    line,
    attachments
  )
end

local function open_under_cursor()
  local attachment = attachment_at_cursor()
  if attachment then
    return require("config.atlas.jira-attachments").open(attachment)
  end
  local state = require("atlas.issues.ui.detail.state")
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local links = require("config.atlas.jira-links")
  if links.on_back_chip(line, col) then
    return links.go_back()
  end
  local hyperlink = require("config.atlas.hyperlinks").at_cursor()
  if hyperlink then
    return links.follow(hyperlink)
  end
  local target = links.target(state.line_map[row], line, col, jira_url)
  if target then
    links.follow(target)
  end
end

local function preview_attachments(buf)
  local attachments = require("config.atlas.jira-attachments")
  local group = vim.api.nvim_create_augroup("AtlasAttachmentPreview" .. buf, {})
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    buffer = buf,
    callback = function()
      attachments.preview(attachment_at_cursor())
    end,
  })
  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    buffer = buf,
    callback = function()
      attachments.close_preview()
      attachments.preview(attachment_at_cursor())
    end,
  })
  vim.api.nvim_create_autocmd({ "BufLeave", "ModeChanged", "BufWipeout" }, {
    group = group,
    buffer = buf,
    callback = attachments.close_preview,
  })
end

-- Atlas leaves Enter unmapped in the issue detail, so use it to open what's under the cursor.
local function extend_issue_detail_keys()
  local help = require("atlas.ui.popups.help")
  local keymaps = require("atlas.issues.ui.detail.keymaps")
  local register, remove = keymaps.register, keymaps.remove
  local items = {
    {
      key = "<CR>",
      desc = "Open attachment, issue, PR or URL",
      callback = open_under_cursor,
    },
    {
      key = "<BS>",
      desc = "Back to previous issue",
      callback = function()
        require("config.atlas.jira-links").go_back()
      end,
    },
  }
  keymaps.register = function(buf, ...)
    register(buf, ...)
    help.register("Open", items, { buffer = buf, index = 4 })
    preview_attachments(buf)
  end
  keymaps.remove = function(buf, ...)
    remove(buf, ...)
    help.remove("Open", items, { buffer = buf })
    pcall(vim.api.nvim_del_augroup_by_name, "AtlasAttachmentPreview" .. buf)
    require("config.atlas.jira-attachments").close_preview()
  end
end

local detail_wanted = true

local function show_detail(item)
  local detail = require("atlas.pulls.ui.detail")
  local dashboard = require("atlas.pulls.ui.dashboard")
  if detail.is_open() then
    dashboard.select(item)
    return
  end
  local win = vim.api.nvim_get_current_win()
  dashboard.toggle_detail()
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
end

-- Atlas only repaints the detail pane on a PR row, so an empty view would keep the last PR.
local sync_timer

local function stop_sync()
  if sync_timer and not sync_timer:is_closing() then
    sync_timer:stop()
    sync_timer:close()
  end
  sync_timer = nil
end

local function sync_detail_when_loaded()
  local state = require("atlas.pulls.state")
  local detail = require("atlas.pulls.ui.detail")
  stop_sync()
  local timer, waited = vim.uv.new_timer(), 0
  sync_timer = timer
  local function finish()
    if sync_timer == timer then
      stop_sync()
    end
  end
  timer:start(
    200,
    100,
    vim.schedule_wrap(function()
      if sync_timer ~= timer then
        return
      end
      waited = waited + 100
      if waited >= 15000 then
        return finish()
      end
      if state.is_loading then
        return
      end
      local item = require("atlas.pulls.ui.dashboard.navigation").current_item()
      if type(item) == "table" and item.kind == "pr" then
        if detail_wanted then
          show_detail(item)
        end
        return finish()
      end
      if #state.pulls == 0 then
        if detail.is_open() then
          detail.close()
        end
        return finish()
      end
    end)
  )
end

local function switch_pull_view(target)
  local state = require("atlas.pulls.state")
  detail_wanted = require("atlas.pulls.ui.detail").is_open()
    or #state.pulls == 0 and detail_wanted
  require("atlas.pulls.ui.dashboard.controller").switch_view(target)
  sync_detail_when_loaded()
end

local function cycle_view(step)
  local state = require("atlas.pulls.state")
  local views = state.views
  local current = 1
  for i, view in ipairs(views) do
    if state.view and view.name == state.view.name then
      current = i
    end
  end
  local target = views[(current - 1 + step) % #views + 1]
  if target then
    switch_pull_view(target)
  end
end

local function dashboard_items()
  local items = {
    {
      key = "h",
      desc = "Previous view",
      callback = function()
        cycle_view(-1)
      end,
    },
    {
      key = "l",
      desc = "Next view",
      callback = function()
        cycle_view(1)
      end,
    },
  }
  for _, k in ipairs(review_keys) do
    table.insert(items, {
      key = k[1],
      desc = k[3],
      callback = function()
        review_open(k[2], k[3], k[4])
      end,
    })
  end
  vim.list_extend(items, {
    open_links(),
    { key = "v", desc = "Approve PR", callback = approve },
    { key = "X", desc = "Reclaim idle review slots", callback = reclaim },
    jump_counterpart(),
    {
      key = "gJ",
      desc = "Open Jira ticket in browser",
      callback = open_jira_in_browser,
    },
    {
      key = "ge",
      desc = "Edit PR field",
      callback = function()
        require("config.atlas.github-edit").edit_dashboard()
      end,
    },
  })
  return items
end

local pr_enter_fallback = {}

local function pr_enter()
  local links = require("config.atlas.jira-links")
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local line = vim.api.nvim_get_current_line()
  if links.on_back_chip(line, col) then
    return links.go_back()
  end
  local target = require("config.atlas.hyperlinks").at_cursor()
    or links.target_here(line, col, jira_url)
  if target then
    return links.follow(target)
  end
  local fallback = pr_enter_fallback[vim.api.nvim_get_current_buf()]
  if fallback and fallback.callback then
    fallback.callback()
  elseif fallback and fallback.rhs and fallback.rhs ~= "" then
    vim.api.nvim_feedkeys(vim.keycode(fallback.rhs), "n", false)
  end
end

local function pr_back_chip()
  local detail_ui = require("atlas.pulls.providers.github.ui.detail")
  local chips = detail_ui.chips
  detail_ui.chips = function(...)
    local list = chips(...)
    local previous = require("config.atlas.jira-links").previous_label()
    if previous then
      local back =
        { label = "← " .. previous .. " (q)", hl = "AtlasChipActive" }
      table.insert(list, 1, back)
    end
    return list
  end
end

local function extend_pulls_detail()
  local help = require("atlas.ui.popups.help")
  local keymaps = require("atlas.pulls.ui.detail.keymaps")
  local register, remove = keymaps.register, keymaps.remove
  pr_back_chip()
  local items = {
    open_links(),
    {
      key = "ge",
      desc = "Edit field under cursor",
      callback = function()
        require("config.atlas.github-edit").edit_detail()
      end,
    },
    jump_counterpart(),
    {
      key = "<CR>",
      desc = "Open PR, Jira or URL under cursor",
      callback = pr_enter,
    },
  }
  keymaps.register = function(buf, ...)
    register(buf, ...)
    vim.api.nvim_buf_call(buf, function()
      local mapping = vim.fn.maparg("<CR>", "n", false, true)
      local ours = mapping.desc == "Open PR, Jira or URL under cursor"
      pr_enter_fallback[buf] = (mapping.buffer == 1 and not ours) and mapping
        or nil
    end)
    help.register("Links", items, { buffer = buf, index = 4 })
  end
  keymaps.remove = function(buf, ...)
    remove(buf, ...)
    help.remove("Links", items, { buffer = buf })
  end
end

-- Atlas has no dashboard custom-keymap option, so piggyback its pulls register/remove pair.
local function extend_pulls_dashboard()
  local help = require("atlas.ui.popups.help")
  local keymaps = require("atlas.pulls.ui.dashboard.keymaps")
  local register, remove = keymaps.register, keymaps.remove
  local items = dashboard_items()
  keymaps.register = function(buf, ...)
    register(buf, ...)
    help.register("Review", items, { buffer = buf, index = 3 })
    detail_wanted = true
    sync_detail_when_loaded()
  end
  keymaps.remove = function(buf, ...)
    remove(buf, ...)
    help.remove("Review", items, { buffer = buf })
  end
end

local function cycle_issue_view(step)
  local state = require("atlas.issues.state")
  local views = require("atlas.ui.shared.bookmarks").views(
    state.views,
    state.bookmarks,
    state.starred_items
  )
  local current = 1
  for i, view in ipairs(views) do
    if view == state.view then
      current = i
    end
  end
  local target = views[(current - 1 + step) % #views + 1]
  if target then
    require("atlas.issues.ui.dashboard.controller").switch_view(target)
  end
end

-- Landing on the bookmarks tab opens Starred instead of the bare bookmark list.
local function expand_starred_on_switch()
  local controller = require("atlas.issues.ui.dashboard.controller")
  local switch_view = controller.switch_view
  controller.switch_view = function(view)
    local state = require("atlas.issues.state")
    if view ~= state.bookmarks.tab or #state.starred_items == 0 then
      return switch_view(view)
    end
    state.view = view
    controller.select_bookmark({ kind = "starred" })
    require("atlas.issues.ui.dashboard.navigation").focus_first_item({
      all_columns = true,
    })
  end
end

-- h/l switch Jira tabs like the PR dashboard instead of stepping stacked columns.
local function extend_issues_dashboard()
  local help = require("atlas.ui.popups.help")
  local keymaps = require("atlas.issues.ui.dashboard.keymaps")
  local register, remove = keymaps.register, keymaps.remove
  expand_starred_on_switch()
  local items = {
    {
      key = "h",
      desc = "Previous view",
      callback = function()
        cycle_issue_view(-1)
      end,
    },
    {
      key = "l",
      desc = "Next view",
      callback = function()
        cycle_issue_view(1)
      end,
    },
  }
  keymaps.register = function(buf, ...)
    register(buf, ...)
    require("atlas.issues.state").bookmarks.tab.key = nil
    help.register("Views", items, { buffer = buf, index = 3 })
  end
  keymaps.remove = function(buf, ...)
    remove(buf, ...)
    help.remove("Views", items, { buffer = buf })
  end
end

local function dashboard_views(state)
  return require("atlas.ui.shared.bookmarks").views(
    state.views,
    state.bookmarks,
    state.starred_items
  )
end

local navbar_clicks = {
  issues = function(segment)
    local state = require("atlas.issues.state")
    local controller = require("atlas.issues.ui.dashboard.controller")
    if segment.kind == "item" then
      local view = dashboard_views(state)[segment.index]
      if view and view ~= state.view then
        controller.switch_view(view)
      end
    elseif segment.label:find("⇄", 1, true) then
      toggle_scope()
    elseif segment.label:find("^Refresh") then
      controller.refresh_view()
    end
  end,
  pulls = function(segment)
    local state = require("atlas.pulls.state")
    local controller = require("atlas.pulls.ui.dashboard.controller")
    if segment.kind == "item" then
      local view = dashboard_views(state)[segment.index]
      if view and not (state.view and view.name == state.view.name) then
        switch_pull_view(view)
      end
    elseif vim.tbl_contains(state.available_states, segment.label:lower()) then
      controller.toggle_status_filter(segment.label:lower())
    end
  end,
}

local function tiled_windows()
  return vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative == ""
  end, vim.api.nvim_tabpage_list_wins(0))
end

local function is_blank(buf)
  return vim.api.nvim_buf_get_name(buf) == ""
    and not vim.bo[buf].modified
    and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

-- A detail opened by `:Atlas open` (the J/P split panes) has no dashboard beside it, so it takes the tab.
local function fill_standalone_detail()
  local detail
  for _, win in ipairs(tiled_windows()) do
    local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
    if ft == "atlas-ui.dashboard" then
      return
    elseif ft == "atlas-ui.detail" then
      detail = win
    end
  end
  if not detail then
    return
  end
  for _, win in ipairs(tiled_windows()) do
    if win ~= detail and is_blank(vim.api.nvim_win_get_buf(win)) then
      pcall(vim.api.nvim_win_close, win, false)
    end
  end
end

local function extend_standalone_detail()
  for _, name in ipairs({ "issues", "pulls" }) do
    local window = require("atlas." .. name .. ".ui.detail.window")
    local open = window.open
    window.open = function(...)
      local result = { open(...) }
      vim.schedule(fill_standalone_detail)
      return unpack(result)
    end
    -- q on a full-tab detail has no window to fall back to, so it ends nvim and its herdr pane.
    local detail = require("atlas." .. name .. ".ui.detail")
    local close = detail.close
    detail.close = function(...)
      local alone = #vim.api.nvim_list_tabpages() == 1 and #tiled_windows() == 1
      if alone and vim.bo.filetype == "atlas-ui.detail" then
        return vim.cmd("qa")
      end
      return close(...)
    end
  end
end

local M = {}

function M.opts()
  return {
    ui = { picker = "snacks" },
    keymaps = {
      ui = {
        open_in_browser = "gB",
        toggle_panel = "p",
        help = "?",
        search = "F",
        previous_column = false,
        next_column = false,
      },
      pulls = {
        open_repository = "gO",
        edit_pr = false,
        -- "-" is CodeDiff's toggle_stage in the same diff buffers.
        review = { toggle_file_reviewed = "<leader>gv" },
      },
      issues = {
        transition_issue = false,
        edit_issue = false,
        custom = {
          {
            key = "gs",
            desc = "Transition issue",
            callback = transition_issue,
          },
          {
            key = "m",
            desc = "Toggle mine / everyone",
            callback = toggle_scope,
          },
          jump_counterpart(),
          open_links(),
          {
            key = "ge",
            desc = "Edit field under cursor",
            callback = edit_issue,
          },
        },
      },
    },
    providers = {
      github = {},
      jira = jira_provider(),
    },
    issues = {
      jira = {
        views = {
          scoped_view({
            label = "Active sprint",
            layout = "board",
            base = "project = IHRWEB AND sprint in openSprints()",
          }),
          scoped_view({
            label = "Backlog",
            layout = "sprints",
            base = "project = IHRWEB AND (sprint in openSprints() OR statusCategory != Done)",
          }),
        },
        project_config = {
          story_points_field = "customfield_10022",
          IHRWEB = jira_project_config(),
        },
      },
    },
    pulls = {
      repo_config = { paths = review_paths },
      github = {
        views = {
          { name = "My PRs", search = "is:open author:@me" },
          {
            name = "Needs Review",
            search = "is:open review-requested:@me",
          },
          {
            name = "Involved",
            search = "is:open involves:@me -author:@me",
          },
          {
            name = "Web",
            search = "is:open repo:iheartradio/web",
          },
          {
            name = "Inferno",
            search = "is:open repo:iheartradio/inferno-monorepo",
          },
        },
      },
    },
  }
end

function M.setup(opts)
  -- Bitwarden's scope-less GH_TOKEN shadows the keyring gh login and hides private repos.
  vim.env.GH_TOKEN = nil
  vim.env.GITHUB_TOKEN = nil
  require("atlas").setup(opts)
  require("config.atlas.tab-clicks").setup(navbar_clicks)
  extend_pulls_dashboard()
  extend_issues_dashboard()
  extend_standalone_detail()
  extend_pulls_detail()
  extend_issue_details()
  extend_issue_detail_width()
  extend_issue_detail_keys()
  require("config.atlas.hyperlinks").setup(jira_url)
  require("config.atlas.jira-backlog").setup({
    board_id = jira_board_id,
    sprint_field = "customfield_10010",
  })
  -- The theme's CursorLine is transparent, so Atlas windows use herdr's sidebar active_row_bg.
  local function sidebar_row_bg()
    local ok, lines =
      pcall(vim.fn.readfile, vim.fn.expand("~/.config/herdr/config.toml"))
    for _, line in ipairs(ok and lines or {}) do
      local hex = line:match('^%s*active_row_bg%s*=%s*"(#%x+)"')
      if hex then
        return hex
      end
    end
    return require("config.colors")["gnohj_color13"]
  end
  local function set_cursorline_hl()
    vim.api.nvim_set_hl(0, "AtlasCursorLine", { bg = sidebar_row_bg() })
  end
  set_cursorline_hl()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = set_cursorline_hl })
  local function without_cursorline(win)
    return vim.tbl_filter(function(entry)
      return entry ~= "" and not entry:match("^CursorLine:")
    end, vim.split(vim.wo[win].winhighlight, ",", { plain = true }))
  end
  -- Windows split or tabbed off an Atlas window inherit its options, so non-Atlas ones are reset.
  local function style_atlas_window(win)
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      return
    end
    local atlas = vim.bo[vim.api.nvim_win_get_buf(win)].filetype:match("^atlas")
    local styled =
      vim.wo[win].winhighlight:find("CursorLine:AtlasCursorLine", 1, true)
    if atlas then
      local entries = without_cursorline(win)
      table.insert(entries, "CursorLine:AtlasCursorLine")
      vim.wo[win].list = false
      vim.wo[win].cursorline = true
      vim.wo[win].winhighlight = table.concat(entries, ",")
    elseif styled then
      vim.wo[win].winhighlight = table.concat(without_cursorline(win), ",")
      vim.wo[win].cursorline = vim.go.cursorline
      vim.wo[win].list = vim.go.list
    end
  end
  -- Scheduled past Atlas's own window setup, which rewrites winhighlight after BufWinEnter.
  vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter", "WinEnter" }, {
    callback = function()
      vim.schedule(function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          style_atlas_window(win)
        end
      end)
    end,
  })
end

return M
