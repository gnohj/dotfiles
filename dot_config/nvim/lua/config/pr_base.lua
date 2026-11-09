local M = {}

local bases = {}

local function realpath(path)
  return vim.uv.fs_realpath(path) or path
end

local function base_for(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" or name:find("/node_modules/", 1, true) then
    return nil
  end
  name = realpath(name)
  for root, rev in pairs(bases) do
    if name:sub(1, #root + 1) == root .. "/" then
      return root, rev, name:sub(#root + 2)
    end
  end
end

local function ref_text(root, rev, path)
  local out = vim
    .system({ "git", "-C", root, "show", rev .. ":" .. path }, { text = true })
    :wait()
  return out.code == 0 and out.stdout or ""
end

local gitsigns_ready = {}
local gitsigns_applied = {}

local function gitsigns_base(buf, rev)
  local gs = package.loaded.gitsigns
  if gs and gitsigns_ready[buf] and gitsigns_applied[buf] ~= rev then
    gitsigns_applied[buf] = rev
    vim.api.nvim_buf_call(buf, function()
      gs.change_base(rev)
    end)
  end
end

function M.apply(buf)
  local root, rev, path = base_for(buf)
  if not root then
    return
  end
  local MiniDiff = require("mini.diff")
  if MiniDiff.get_buf_data(buf) then
    MiniDiff.disable(buf)
  end
  vim.b[buf].minidiff_config = { source = MiniDiff.gen_source.none() }
  MiniDiff.set_ref_text(buf, ref_text(root, rev, path))
  gitsigns_base(buf, rev)
end

function M.setup()
  vim.api.nvim_create_user_command(
    "PrDiffBase",
    function(opts)
      bases[realpath(opts.fargs[2])] = opts.fargs[1]
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
          M.apply(buf)
        end
      end
    end,
    {
      nargs = "+",
      desc = "Diff PR worktree buffers against REV: PrDiffBase REV ROOT",
    }
  )

  local group = vim.api.nvim_create_augroup("pr_base", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "GitSignsUpdate",
    callback = function(ev)
      local buf = ev.data and ev.data.buffer
      if not buf then
        return
      end
      local root, rev = base_for(buf)
      if root and require("gitsigns.cache").cache[buf] then
        gitsigns_ready[buf] = true
        gitsigns_base(buf, rev)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(ev)
      if next(bases) then
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(ev.buf) then
            M.apply(ev.buf)
          end
        end)
      end
    end,
  })
end

return M
