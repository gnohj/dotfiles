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

-- Escape Lua pattern special characters
local function escape_pattern(str)
  return str:gsub("([%-%+%.%*%?%^%$%(%)%[%]%%])", "%%%1")
end

local function discover_packages(repo_root)
  local packages = {}
  local repo_root_escaped = escape_pattern(repo_root .. "/")

  -- Check for common monorepo patterns (including nested)
  local patterns = {
    "/packages/*/package.json",
    "/packages/*/*/package.json",
    "/apps/*/package.json",
    "/apps/*/*/package.json",
    "/apps-legacy/*/package.json",
    "/apps-legacy/*/*/package.json",
    "/libs/*/package.json",
    "/libs/*/*/package.json",
    "/services/*/package.json",
    "/services/*/*/package.json",
    "/modules/*/package.json",
    "/modules/*/*/package.json",
    "/shared/*/package.json",
    "/shared/*/*/package.json",
    "/generator/*/package.json",
    "/generator/*/*/package.json",
    "/tooling/*/package.json",
    "/tooling/*/*/package.json",
  }

  local seen = {} -- Track seen paths to avoid duplicates
  for _, pattern in ipairs(patterns) do
    local glob_path = repo_root .. pattern
    local matches = vim.fn.glob(glob_path, false, true)
    for _, match in ipairs(matches) do
      local pkg_dir = vim.fn.fnamemodify(match, ":h")
      if not seen[pkg_dir] then
        seen[pkg_dir] = true
        local pkg_name = vim.fn.fnamemodify(pkg_dir, ":t")
        -- Get relative path from repo root for proper display
        local relative_path = pkg_dir:gsub(repo_root_escaped, "")
        -- Category is the top-level directory (apps, packages, etc.)
        local category = relative_path:match("^([^/]+)")
        table.insert(packages, {
          name = pkg_name,
          path = pkg_dir,
          category = category,
          display = relative_path,
        })
      end
    end
  end

  -- Add special directories if they exist
  local special_dirs = { ".github", ".changeset", ".fastly-vcl", ".scripts", ".husky" }
  for _, dir in ipairs(special_dirs) do
    local dir_path = repo_root .. "/" .. dir
    if vim.fn.isdirectory(dir_path) == 1 then
      table.insert(packages, {
        name = dir,
        path = dir_path,
        category = dir,
        display = dir,
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
          local relative = pkg_dir:gsub(repo_root_escaped, "")
          local category = relative:match("^([^/]+)")
          table.insert(packages, {
            name = vim.fn.fnamemodify(pkg_dir, ":t"),
            path = pkg_dir,
            category = category,
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
      local display = item.text
      local first_slash = display:find("/")
      if first_slash then
        local prefix = display:sub(1, first_slash)
        local rest = display:sub(first_slash + 1)
        return {
          { prefix, "Comment" },
          { rest, "Normal" },
        }
      end
      return {
        { display, "Normal" },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      require("mini.files").open(item.path, true)
    end,
  })
end

return M
