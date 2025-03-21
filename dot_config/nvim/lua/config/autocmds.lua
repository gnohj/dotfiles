-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    vim.opt.formatoptions:remove({ "c", "r", "o" })
  end,
  desc = "Disable New Line Comment",
})

-- Disable built-in spellchecking for Markdown - https://github.com/LazyVim/LazyVim/discussions/392
vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("lazyvim_user_markdown", { clear = true }),
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
  end,
})

-- Fold keymaps in markdown files
vim.api.nvim_create_autocmd("BufRead", {
  pattern = "*.md",
  callback = function()
    -- Avoid running zk multiple times for the same buffer
    if vim.b.zk_executed then
      return
    end
    vim.b.zk_executed = true -- Mark as executed
    -- Use `vim.defer_fn` to add a slight delay before executing `zk`
    vim.defer_fn(function()
      vim.cmd("normal zk")
      vim.cmd("silent write")
      vim.notify("Folded keymaps", vim.log.levels.INFO)
    end, 100) -- Delay in milliseconds (100ms should be enough)
  end,
})

-- :OpenPRChanges - Uses the default origin/master
-- :OpenPRChanges origin/develop - Uses origin/develop instead
-- :OpenPRChanges + Tab - Shows completion options for branches
vim.api.nvim_create_user_command("OpenPRChanges", function(opts)
  local base_branch = opts.args ~= "" and opts.args or "origin/master"

  local changed_files = vim.fn.systemlist("git diff --name-only " .. base_branch .. "...HEAD")

  for _, file in ipairs(changed_files) do
    vim.cmd("edit " .. file)
  end
end, {
  nargs = "?",
  complete = function(ArgLead, CmdLine, CursorPos)
    local branches = vim.fn.systemlist("git branch -a | cut -c 3-")
    local matches = {}
    for _, branch in ipairs(branches) do
      if branch:match("^" .. ArgLead) then
        table.insert(matches, branch)
      end
    end
    return matches
  end,
})

-- :ReviewPRChanges (uses Avante and origin/master)
-- :ReviewPRChanges avante (uses Avante with origin/master)
-- :ReviewPRChanges avante origin/develop (uses Avante with origin/develop)
-- :ReviewPRChanges copilot origin/develop (uses CopilotChat with origin/develop)
vim.api.nvim_create_user_command("ReviewPRChanges", function(opts)
  local args = vim.split(opts.args, " ", { trimempty = true })
  local ai_tool = args[1] or "avante"
  local base_branch = args[2] or "origin/master"

  local diff_cmd = "git diff " .. base_branch .. "...HEAD > /tmp/pr_changes.diff"
  vim.fn.system(diff_cmd)

  vim.cmd("split /tmp/pr_changes.diff")

  local prompt =
    "Review these PR changes and provide specific feedback on potential issues, improvements, and best practices. Focus only on the changed lines shown with + and - prefixes."

  if ai_tool:lower() == "avante" then
    vim.cmd(":AvanteAsk " .. prompt)
  elseif ai_tool:lower() == "copilot" then
    vim.cmd(":CopilotChat " .. prompt)
  else
    print("Unknown AI tool: " .. ai_tool .. ". Supported tools are 'avante' and 'copilot'.")
  end
end, {
  nargs = "*",
  complete = function(ArgLead, CmdLine, CursorPos)
    local args = vim.split(CmdLine, " ", { trimempty = true })

    if #args <= 2 then
      local tools = { "avante", "copilot" }
      local matches = {}
      for _, tool in ipairs(tools) do
        if tool:match("^" .. ArgLead) then
          table.insert(matches, tool)
        end
      end
      return matches
    elseif #args <= 3 then
      local branches = vim.fn.systemlist("git branch -a | cut -c 3-")
      local matches = {}
      for _, branch in ipairs(branches) do
        if branch:match("^" .. ArgLead) then
          table.insert(matches, branch)
        end
      end
      return matches
    end

    return {}
  end,
})
