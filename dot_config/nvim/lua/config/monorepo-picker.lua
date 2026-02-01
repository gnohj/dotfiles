-- Smart project/package picker based on current repo
-- Detects monorepo packages automatically with in-memory caching

local M = {}

local cache = {}
local CACHE_TTL = 300 -- 5 minutes

local function get_git_root()
  local result = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")
  if vim.v.shell_error == 0 and result[1] then
    return result[1]
  end
  return nil
end

local function get_repo_name(root)
  return vim.fn.fnamemodify(root, ":t")
end

local function is_cache_valid(repo_root)
  local entry = cache[repo_root]
  if not entry then
    return false
  end
  return (os.time() - entry.timestamp) < CACHE_TTL
end

local function discover_packages(repo_root)
  local packages = {}

  -- Check for common monorepo patterns
  local patterns = {
    "/packages/*/package.json",
    "/apps/*/package.json",
    "/libs/*/package.json",
    "/services/*/package.json",
    "/modules/*/package.json",
  }

  for _, pattern in ipairs(patterns) do
    local glob_path = repo_root .. pattern
    local matches = vim.fn.glob(glob_path, false, true)
    for _, match in ipairs(matches) do
      local pkg_dir = vim.fn.fnamemodify(match, ":h")
      local pkg_name = vim.fn.fnamemodify(pkg_dir, ":t")
      local parent_dir = vim.fn.fnamemodify(pkg_dir, ":h:t")
      table.insert(packages, {
        name = pkg_name,
        path = pkg_dir,
        category = parent_dir,
        display = parent_dir .. "/" .. pkg_name,
      })
    end
  end

  -- Also check for pnpm workspaces or yarn workspaces
  local pnpm_workspace = repo_root .. "/pnpm-workspace.yaml"
  if vim.fn.filereadable(pnpm_workspace) == 1 and #packages == 0 then
    -- Fallback: find all package.json files (excluding node_modules)
    local handle = io.popen(
      "find "
        .. repo_root
        .. " -name 'package.json' -not -path '*/node_modules/*' -not -path '*/.git/*' -maxdepth 4 2>/dev/null"
    )
    if handle then
      for line in handle:lines() do
        local pkg_dir = vim.fn.fnamemodify(line, ":h")
        if pkg_dir ~= repo_root then -- exclude root package.json
          local relative = pkg_dir:gsub(repo_root .. "/", "")
          table.insert(packages, {
            name = vim.fn.fnamemodify(pkg_dir, ":t"),
            path = pkg_dir,
            category = vim.fn.fnamemodify(pkg_dir, ":h:t"),
            display = relative,
          })
        end
      end
      handle:close()
    end
  end

  return packages
end

local function get_packages(repo_root)
  if is_cache_valid(repo_root) then
    return cache[repo_root].packages
  end

  local packages = discover_packages(repo_root)
  cache[repo_root] = {
    packages = packages,
    timestamp = os.time(),
  }

  return packages
end

M.clear_cache = function()
  cache = {}
  vim.notify("Project picker cache cleared", vim.log.levels.INFO)
end

M.pick = function()
  local repo_root = get_git_root()
  if not repo_root then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end

  local repo_name = get_repo_name(repo_root)
  local packages = get_packages(repo_root)

  local items = {
    {
      text = "/ (root)",
      name = repo_name,
      file = repo_root,
      path = repo_root,
      category = "",
      is_root = true,
    },
  }

  for _, pkg in ipairs(packages) do
    table.insert(items, {
      text = pkg.display,
      name = pkg.name,
      file = pkg.path,
      path = pkg.path,
      category = pkg.category,
    })
  end

  table.sort(items, function(a, b)
    if a.is_root then
      return true
    end
    if b.is_root then
      return false
    end
    if a.category == b.category then
      return a.name < b.name
    end
    return a.category < b.category
  end)

  require("snacks").picker({
    title = "Apps & Packages",
    finder = function()
      return items
    end,
    format = function(item)
      if item.is_root then
        return {
          { "📁 ", "Normal" },
          { repo_name .. " (root)", "Special" },
        }
      end
      return {
        { item.category .. "/", "Comment" },
        { item.name, "Normal" },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      require("mini.files").open(item.path, true)
    end,
  })
end

return M
