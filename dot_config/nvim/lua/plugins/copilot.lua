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
        next = "<S-j>",
        prev = "<S-k>",
        dismiss = "<S-l>",
      },
    },
    panel = { enabled = false },
    filetypes = { markdown = true, help = true, yaml = true },
    copilot_node_command = vim.fn.expand(
      "~/.local/share/fnm/node-versions/v22.15.1/installation/bin/node"
    ),
  },
}
