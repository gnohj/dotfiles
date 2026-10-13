local jira_url = "https://ihm-it.atlassian.net"

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
  { "D", "diff", "Diff in hunk + agent notes" },
  { "E", "enhance", "Checks in ENHANCE" },
  { "C", "claude", "Claude /review" },
}

local function current_pr()
  local item = require("atlas.ui.navigation").current_item()
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

local function review_open(mode, label)
  local pr = current_pr()
  if not pr then
    return
  end
  local script = vim.fn.expand("~/.config/gh-dash/review-open.sh")
  local args = { "bash", script, mode, tostring(pr.id), pr.repo_full_name }
  table.insert(args, repo_path(pr.repo_full_name))
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
  local item = require("atlas.ui.navigation").current_item()
  local pr = type(item) == "table" and item.pr or {}
  local key = pr_jira_key(pr)
    or vim.api.nvim_get_current_line():match("%u[%u%d]+%-%d+")
  if not key then
    vim.notify("No Jira key on this PR", vim.log.levels.WARN)
  end
  return key
end

local function open_pr_links(pr)
  if type(pr) ~= "table" then
    return vim.notify("No PR selected", vim.log.levels.WARN)
  end
  local choices =
    { { label = "GitHub PR #" .. pr.id, url = pr.link and pr.link.html } }
  local key = pr_jira_key(pr)
  if key then
    table.insert(
      choices,
      { label = "Jira " .. key, url = jira_url .. "/browse/" .. key }
    )
  end
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

local function open_jira()
  local key = jira_key()
  if key then
    require("atlas.commands.open").open(key)
  end
end

local function open_jira_in_browser()
  local key = jira_key()
  if key then
    vim.ui.open(jira_url .. "/browse/" .. key)
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
      local item = require("atlas.ui.navigation").current_item()
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
    local state = require("atlas.pulls.state")
    detail_wanted = require("atlas.pulls.ui.detail").is_open()
      or #state.pulls == 0 and detail_wanted
    require("atlas.pulls.ui.dashboard.controller").switch_view(target)
    sync_detail_when_loaded()
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
        review_open(k[2], k[3])
      end,
    })
  end
  vim.list_extend(items, {
    {
      key = "o",
      desc = "Open PR or Jira in browser",
      callback = function()
        local item = require("atlas.ui.navigation").current_item()
        open_pr_links(type(item) == "table" and item.pr or nil)
      end,
    },
    { key = "v", desc = "Approve PR", callback = approve },
    { key = "X", desc = "Reclaim idle review slots", callback = reclaim },
    { key = "J", desc = "Jira ticket details", callback = open_jira },
    {
      key = "gJ",
      desc = "Open Jira ticket in browser",
      callback = open_jira_in_browser,
    },
  })
  return items
end

local function extend_pulls_detail()
  local help = require("atlas.ui.popups.help")
  local keymaps = require("atlas.pulls.ui.detail.keymaps")
  local register, remove = keymaps.register, keymaps.remove
  local items = {
    {
      key = "o",
      desc = "Open PR or Jira in browser",
      callback = function()
        open_pr_links(require("atlas.pulls.ui.detail.state").current_pr)
      end,
    },
  }
  keymaps.register = function(buf, ...)
    register(buf, ...)
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

return {
  "emrearmagan/atlas.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "esmuellert/codediff.nvim",
  },
  cmd = "Atlas",
  keys = {
    { "<leader>gA", "<cmd>Atlas<cr>", desc = "Atlas" },
    { "<leader>gp", "<cmd>Atlas pulls github<cr>", desc = "Atlas PRs" },
    { "<leader>gP", "<cmd>Atlas review<cr>", desc = "Atlas review current PR" },
  },
  opts = function()
    return {
      ui = { picker = "snacks" },
      keymaps = {
        ui = {
          open_in_browser = "gP",
          toggle_panel = "P",
          help = "?",
          search = "/",
        },
        pulls = { open_repository = "gO" },
      },
      providers = {
        github = {},
        jira = jira_provider(),
      },
      pulls = {
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
  end,
  config = function(_, opts)
    -- Bitwarden's scope-less GH_TOKEN shadows the keyring gh login and hides private repos.
    vim.env.GH_TOKEN = nil
    vim.env.GITHUB_TOKEN = nil
    require("atlas").setup(opts)
    extend_pulls_dashboard()
    extend_pulls_detail()
    vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
      callback = function(ev)
        if vim.bo[ev.buf].filetype:match("^atlas") then
          vim.opt_local.list = false
        end
      end,
    })
  end,
}
