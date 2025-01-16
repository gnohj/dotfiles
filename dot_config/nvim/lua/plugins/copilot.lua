if vim.g.vscode then
  return {}
end

return {
  "zbirenbaum/copilot.lua",
  event = "InsertEnter",
  opts = {
    suggestion = {
      -- change this back to false for adding suggestions through cmp
      enabled = true,
      auto_trigger = true,
      keymap = {
        accept = "<S-z>",
      },
    },
    panel = { enabled = false },
    filetypes = { markdown = true, help = true, yaml = true },
  },
}
