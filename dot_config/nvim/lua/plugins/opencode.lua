if vim.g.vscode then
  return {}
end

return {
  "NickvanDyke/opencode.nvim",
  opts = {},
  -- stylua: ignore
  keys = {
    { '<leader>oo', { 'n', 'v' }, function() require('opencode').ask('@file ') end, desc = 'Ask opencode about current file' },
    { '<leader>oa', { 'n', 'v' }, function() require('opencode').ask() end, desc = 'Ask opencode' },
    { '<leader>od', 'v', function() require('opencode').prompt('Add documentation comments for @selection') end, desc = 'Add Docs to selection' },
    { '<leader>oe', function() require('opencode').prompt('Explain @cursor and its context') end, desc = 'Explain code near cursor' },
    { '<leader>of', function() require('opencode').prompt('Fix these @diagnostics') end, desc = 'Fix errors' },
    { '<leader>oO', 'v', function() require('opencode').prompt('Optimize @selection for performance and readability') end, desc = 'Optimize selection' },
    { '<leader>or', function() require('opencode').prompt('Review @file for correctness and readability') end, desc = 'Review file' },
    { '<leader>ot', 'v', function() require('opencode').prompt('Add tests for @selection') end, desc = 'Test selection' },
  },
}
