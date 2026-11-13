local M = {}

local KEY_PATTERN = "%u[%u%d]+%-%d+"

local function open(label, target, counterpart)
  local links = require("config.atlas.jira-links")
  local split = counterpart and links.use_counterpart_split()
    or links.use_split()
  if not split then
    return links.open_here(target)
  end
  vim.system({
    vim.fn.expand("~/.local/bin/mux/rex/rex-atlas-open.sh"),
    vim.env.REX_BLOCK,
    label,
    target,
  }, { text = true }, function(res)
    if res.code ~= 0 then
      vim.schedule(function()
        vim.notify(vim.trim(res.stdout .. res.stderr), vim.log.levels.ERROR)
      end)
    end
  end)
end

function M.open_jira(key, counterpart)
  open("🔷 " .. key, key, counterpart)
end

function M.open_pr_url(url, counterpart)
  local number = url:match("/pull/(%d+)")
  open(
    "🐙 PR-" .. number,
    url:match("^(https://github%.com/[^/]+/[^/]+/pull/%d+)") or url,
    counterpart
  )
end

function M.current_pr()
  local detail = require("atlas.pulls.ui.detail.state")
  if vim.bo.filetype == "atlas-ui.detail" and detail.current_pr then
    return detail.current_pr
  end
  local item = require("atlas.pulls.ui.dashboard.navigation").current_item()
  return type(item) == "table" and item.pr or nil
end

function M.pr_to_jira()
  local pr = M.current_pr()
  if type(pr) ~= "table" then
    return vim.notify("No PR selected", vim.log.levels.WARN)
  end
  local branch = type(pr.source) == "table" and pr.source.branch or ""
  local key = branch:match(KEY_PATTERN) or (pr.title or ""):match(KEY_PATTERN)
  if not key then
    return vim.notify("No Jira key on this PR", vim.log.levels.WARN)
  end
  M.open_jira(key, true)
end

local function dev_panel_prs(issue_id, on_done)
  local client = require("atlas.providers.jira.client")
  local base = "/rest/dev-status/1.0/issue/"
  client.request(
    "GET",
    base .. "summary?issueId=" .. issue_id,
    nil,
    function(summary)
      local types = vim.tbl_get(
        summary or {},
        "summary",
        "pullrequest",
        "byInstanceType"
      ) or {}
      local apps = vim.tbl_keys(types)
      local prs, pending = {}, #apps
      if pending == 0 then
        return on_done(prs)
      end
      for _, app in ipairs(apps) do
        local endpoint = string.format(
          "%sdetail?issueId=%s&applicationType=%s&dataType=pullrequest",
          base,
          issue_id,
          app
        )
        client.request("GET", endpoint, nil, function(result)
          for _, detail in
            ipairs(type(result) == "table" and result.detail or {})
          do
            for _, pr in ipairs(detail.pullRequests or {}) do
              if type(pr.url) == "string" and pr.url:match("/pull/%d+") then
                table.insert(prs, {
                  url = pr.url,
                  status = pr.status or "",
                  title = pr.name or "",
                })
              end
            end
          end
          pending = pending - 1
          if pending == 0 then
            on_done(prs)
          end
        end)
      end
    end
  )
end

M.dev_panel_prs = dev_panel_prs

local function search_prs(key, on_done)
  local args = { "gh", "search", "prs", key, "--owner", "iheartradio" }
  vim.list_extend(args, { "--json", "url,state,title", "--limit", "10" })
  vim.system(args, { text = true }, function(res)
    local ok, list = pcall(vim.json.decode, res.stdout or "")
    local prs = {}
    for _, pr in ipairs(ok and type(list) == "table" and list or {}) do
      table.insert(prs, {
        url = pr.url,
        status = (pr.state or ""):upper(),
        title = pr.title or "",
      })
    end
    on_done(prs)
  end)
end

local function open_pr(pr)
  M.open_pr_url(pr.url, true)
end

local function choose(key, prs)
  if #prs == 0 then
    return vim.notify("No pull request found for " .. key, vim.log.levels.WARN)
  end
  if #prs == 1 then
    return open_pr(prs[1])
  end
  vim.ui.select(prs, {
    prompt = "Pull requests for " .. key,
    format_item = M.pr_label,
  }, function(pr)
    if pr then
      open_pr(pr)
    end
  end)
end

function M.pr_label(pr)
  local repo, number = pr.url:match("github%.com/[^/]+/([^/]+)/pull/(%d+)")
  return string.format(
    "%s #%s  [%s]  %s",
    repo or "",
    number or "",
    pr.status,
    pr.title
  )
end

function M.linked_prs(issue, on_done)
  local function sorted(prs)
    table.sort(prs, function(a, b)
      return (a.status == "OPEN" and 0 or 1) < (b.status == "OPEN" and 0 or 1)
    end)
    vim.schedule(function()
      on_done(prs)
    end)
  end
  local function done(prs)
    if #prs > 0 then
      return sorted(prs)
    end
    search_prs(issue.key, sorted)
  end
  if issue.id then
    return dev_panel_prs(issue.id, done)
  end
  done({})
end

function M.jira_to_pr(issue)
  if not (issue and issue.key) then
    return vim.notify("No issue selected", vim.log.levels.WARN)
  end
  M.linked_prs(issue, function(prs)
    choose(issue.key, prs)
  end)
end

function M.jump(ctx)
  if type(ctx) == "table" and ctx.issue then
    return M.jira_to_pr(ctx.issue)
  end
  M.pr_to_jira()
end

return M
