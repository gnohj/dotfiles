if vim.g.vscode then
  return {}
end

return {
  "NickvanDyke/opencode.nvim",
  opts = {},
  -- stylua: ignore
  keys = {
    { '<leader>oo', function() require('opencode').ask('@file') end, mode = { 'n', 'v' }, desc = 'Ask opencode about current file' },
    { '<leader>oa', function() require('opencode').ask() end, mode = { 'n', 'v' }, desc = 'Ask opencode' },
    { '<leader>oe', function() require('opencode').prompt('Explain @cursor and its context') end, mode = 'n', desc = 'Explain code near cursor' },
    { '<leader>oF', function() require('opencode').prompt('Fix these @diagnostics') end, mode = 'n', desc = 'Fix errors' },
    { '<leader>or', function() require('opencode').prompt('Review @file for correctness and readability') end, mode = 'n', desc = 'Review file' },
    -- selection mappings
    { '<leader>od', function() require('opencode').prompt('Add documentation comments for @selection') end, mode = 'v', desc = 'Add Docs to selected code' },
    { '<leader>of', function() require('opencode').prompt('Fix @selection') end, mode = 'v', desc = 'Fix selected code' },
    { '<leader>oO', function() require('opencode').prompt('Optimize @selection for performance and readability') end, mode = 'v', desc = 'Optimize selected code' },
    { '<leader>ot', function() require('opencode').prompt('Add tests for @selection') end, mode = 'v', desc = 'Add tests for selected code' },
  },
}
