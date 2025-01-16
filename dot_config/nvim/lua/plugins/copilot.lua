if vim.g.vscode then
  return {}
end

return {
  "zbirenbaum/copilot.lua",
  event = "InsertEnter",
  opts = {
    suggestion = {
      -- change this back to true for virtual text and not blink-cmp suggestions
      enabled = false,
      auto_trigger = true,
      keymap = {
        accept = "<S-z>",
      },
    },
    panel = { enabled = false },
    filetypes = { markdown = true, help = true, yaml = true },
  },
}
