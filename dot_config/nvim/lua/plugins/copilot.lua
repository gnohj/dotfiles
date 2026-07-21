return {
  "zbirenbaum/copilot.lua",
  event = "InsertEnter",
  opts = function()
    -- Copilot needs Node 22+; use the newest mise-managed GLOBAL node so a
    -- project-local .mise.toml pinning an older version can't break it.
    local nodes =
      vim.fn.glob(vim.fn.expand("~/.local/share/mise/installs/node/*/bin/node"), true, true)
    local node_cmd = #nodes > 0 and nodes[#nodes]
      or vim.fn.expand("~/.local/share/mise/installs/node/22/bin/node")

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
      filetypes = { markdown = true, help = true, yaml = true, rust = false },
      copilot_node_command = node_cmd,
    }
  end,
}
