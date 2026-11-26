-- Reports this nvim to Rex's program resume (OSC 7577) when it was started bare or with -c only; init.lua's resume.trust.nvim decides.
local token = vim.env.OSC7577_TOKEN
vim.env.OSC7577_TOKEN = nil
if not token or token == "" then
  return
end

local function resume_argv()
  local argv, i = { "nvim" }, 2
  while i <= #vim.v.argv do
    local arg = vim.v.argv[i]
    if arg == "--cmd" then
      i = i + 1
    elseif arg == "-c" then
      local value = vim.v.argv[i + 1]
      if not value then
        return nil
      end
      vim.list_extend(argv, { "-c", value })
      i = i + 1
    elseif arg ~= "--embed" then
      return nil
    end
    i = i + 1
  end
  return argv
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local argv = resume_argv()
    if not argv then
      return
    end
    local encoded = vim.tbl_map(vim.base64.encode, argv)
    local body = ("pid=%d:time=%d:argv=%s"):format(vim.uv.os_getppid(), os.time(), table.concat(encoded, ","))
    io.stderr:write("\27]7577;" .. body .. ":mac=" .. vim.fn.sha256(body .. ":" .. token) .. "\27\\")
  end,
})
