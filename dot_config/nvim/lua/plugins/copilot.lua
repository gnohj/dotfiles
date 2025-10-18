return {
  "zbirenbaum/copilot.lua",
  event = "InsertEnter",
  opts = function()
    -- Find mise-managed Node.js dynamically
    local mise_node = vim.fn.expand("$HOME/.local/share/mise/installs/node")
    local node_cmd = "node"

    -- Try to find the latest mise-managed Node.js
    if vim.fn.isdirectory(mise_node) == 1 then
      local versions = vim.fn.globpath(mise_node, "*", false, true)
      if #versions > 0 then
        -- Sort versions and get the latest (last one)
        table.sort(versions)
        local latest = versions[#versions]
        local node_bin = latest .. "/bin/node"
        if vim.fn.executable(node_bin) == 1 then
          node_cmd = node_bin
        end
      end
    end

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
