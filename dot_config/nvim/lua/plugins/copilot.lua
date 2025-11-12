return {
  "zbirenbaum/copilot.lua",
  event = "InsertEnter",
  opts = function()
    -- Node.js is managed by mise (language runtime)
    -- Use global node (not project-local) for Copilot since it requires Node 22+
    -- Project may use older versions via .mise.toml
    local node_cmd = vim.fn.expand("~/.local/share/mise/installs/node/22/bin/node")

    return {
      suggestion = {
        -- change this back to false for adding suggestions through cmp
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = "<S-z>",
          next = "<M-j>",
          prev = "<M-k>",
          dismiss = "<S-l>",
        },
      },
      panel = { enabled = false },
      filetypes = { markdown = true, help = true, yaml = true },
      copilot_node_command = node_cmd,
    }
  end,
}
