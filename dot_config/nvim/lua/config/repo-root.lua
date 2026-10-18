local M = {}
local cache = {}

local function append_stamp(parts, path)
  local info = vim.uv.fs_stat(path)
  if info then
    local stamp = { path, info.ino }
    if info.type ~= "directory" then
      vim.list_extend(stamp, {
        info.size,
        info.mtime.sec,
        info.mtime.nsec,
        info.ctime.sec,
        info.ctime.nsec,
      })
    end
    parts[#parts + 1] = table.concat(stamp, ":")
  end
  return info
end

local function first_line(path)
  local ok, lines = pcall(vim.fn.readfile, path, "", 1)
  return ok and lines[1] or nil
end

local function git_stamp(parts, marker)
  local info = append_stamp(parts, marker)
  if not info then
    return
  end
  local gitdir = marker
  if info.type == "file" then
    local target = (first_line(marker) or ""):match("^gitdir: (.+)$")
    if not target then
      return
    end
    gitdir = target:sub(1, 1) == "/" and target
      or vim.fs.dirname(marker) .. "/" .. target
  end
  append_stamp(parts, gitdir .. "/config")
  append_stamp(parts, gitdir .. "/config.worktree")
  if append_stamp(parts, gitdir .. "/commondir") then
    local common = first_line(gitdir .. "/commondir")
    if common then
      common = common:sub(1, 1) == "/" and common or gitdir .. "/" .. common
      append_stamp(parts, common .. "/config")
    end
  end
end

local function signature(directory)
  local parts = { vim.uv.fs_realpath(directory) or directory }
  append_stamp(parts, directory)
  for _, name in ipairs({
    "GIT_DIR",
    "GIT_WORK_TREE",
    "GIT_COMMON_DIR",
    "GIT_CEILING_DIRECTORIES",
  }) do
    parts[#parts + 1] = vim.env[name] or ""
  end
  local parent = parts[1]
  while parent do
    git_stamp(parts, parent .. "/.git")
    local next_parent = vim.fs.dirname(parent)
    if next_parent == parent then
      break
    end
    parent = next_parent
  end
  if vim.env.GIT_DIR then
    local gitdir = vim.env.GIT_DIR
    git_stamp(
      parts,
      gitdir:sub(1, 1) == "/" and gitdir or directory .. "/" .. gitdir
    )
  end
  return table.concat(parts, "\0")
end

function M.resolve(directory)
  directory = vim.fs.normalize(vim.fn.fnamemodify(directory, ":p"))
  local stamp = signature(directory)
  local previous = cache[directory]
  if previous and previous.stamp == stamp then
    return previous.root
  end
  local output =
    vim.fn.system({ "git", "-C", directory, "rev-parse", "--show-toplevel" })
  local root = vim.v.shell_error == 0 and output:gsub("\n$", "") or ""
  cache[directory] = { stamp = stamp, root = root }
  return root
end

return M
