local M = {}

local KEY_PATTERN = "%u[%u%d]+%-%d+"

local function open(label, target)
  if not require("config.atlas.jira-links").use_split() then
    return require("config.atlas.jira-links").open_here(target)
  end
  local script = vim.fn.expand("~/.local/bin/mux/herdr/herdr-atlas-open.sh")
  vim.system(
    { script, vim.env.HERDR_PANE_ID, label, target },
    { text = true },
    function(res)
      if res.code ~= 0 then
        vim.schedule(function()
          vim.notify(vim.trim(res.stdout .. res.stderr), vim.log.levels.ERROR)
        end)
      end
    end
  )
end

function M.open_jira(key)
  open("🔷 " .. key, key)
end

function M.open_pr_url(url)
  local number = url:match("/pull/(%d+)")
  open(
    "🐙 PR-" .. number,
    url:match("^(https://github%.com/[^/]+/[^/]+/pull/%d+)") or url
  )
end

local function current_pr()
  local detail = require("atlas.pulls.ui.detail.state")
  if vim.bo.filetype == "atlas-ui.detail" and detail.current_pr then
    return detail.current_pr
  end
  local item = require("atlas.pulls.ui.dashboard.navigation").current_item()
  return type(item) == "table" and item.pr or nil
end

function M.pr_to_jira()
  local pr = current_pr()
  if type(pr) ~= "table" then
    return vim.notify("No PR selected", vim.log.levels.WARN)
  end
  local branch = type(pr.source) == "table" and pr.source.branch or ""
  local key = branch:match(KEY_PATTERN) or (pr.title or ""):match(KEY_PATTERN)
  if not key then
    return vim.notify("No Jira key on this PR", vim.log.levels.WARN)
  end
  M.open_jira(key)
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
  M.open_pr_url(pr.url)
end

local function choose(key, prs)
  if #prs == 0 then
    return vim.notify("No pull request found for " .. key, vim.log.levels.WARN)
  end
  table.sort(prs, function(a, b)
    return (a.status == "OPEN" and 0 or 1) < (b.status == "OPEN" and 0 or 1)
  end)
  if #prs == 1 then
    return open_pr(prs[1])
  end
  vim.ui.select(prs, {
    prompt = "Pull requests for " .. key,
    format_item = function(pr)
      local repo, number = pr.url:match("github%.com/[^/]+/([^/]+)/pull/(%d+)")
      return string.format(
        "%s #%s  [%s]  %s",
        repo or "",
        number or "",
        pr.status,
        pr.title
      )
    end,
  }, function(pr)
    if pr then
      open_pr(pr)
    end
  end)
end

function M.jira_to_pr(issue)
  if not (issue and issue.key) then
    return vim.notify("No issue selected", vim.log.levels.WARN)
  end
  local function done(prs)
    vim.schedule(function()
      if #prs > 0 then
        return choose(issue.key, prs)
      end
      search_prs(issue.key, function(found)
        vim.schedule(function()
          choose(issue.key, found)
        end)
      end)
    end)
  end
  if issue.id then
    return dev_panel_prs(issue.id, done)
  end
  done({})
end

return M
