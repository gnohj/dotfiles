return {
  "zbirenbaum/copilot.lua",
  event = "InsertEnter",
  opts = function()
    -- Node.js is managed by mise (language runtime)
    -- mise shims are in PATH, so just use "node"
    local node_cmd = "node"

    return {
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
      copilot_node_command = node_cmd,
    }
  end,
}
