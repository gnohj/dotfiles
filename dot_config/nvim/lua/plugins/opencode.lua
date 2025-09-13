if vim.g.vscode then
  return {}
end

return {
  "NickvanDyke/opencode.nvim",
  config = function()
    -- Opencode uses vim.g.opencode_opts for configuration
    vim.g.opencode_opts = {}
  end,
  -- stylua: ignore
  keys = {
    { '<leader>ot', function() require('opencode').prompt('Add tests for @selection') end, mode = 'v', desc = 'Add tests for selected code' },
    { '<leader>or', function() require('opencode').prompt('Review @file for correctness and readability') end, mode = 'n', desc = 'Review file' },
    { '<leader>oq', function()
        vim.ui.input({ prompt = 'Opencode Quick Edit: ' }, function(input)
          if input and input ~= '' then
            -- Add @selection to the prompt if not already included
            if not input:match('@selection') then
              input = input .. ' for @selection'
            end
            -- Include @file for context and prepend instruction to edit inline
            input = 'Edit the code inline: ' .. input .. ' @file'
            require('opencode').prompt(input)
          end
        end)
      end, mode = 'v', desc = 'Custom prompt for selected code' },
    { '<leader>oO', function() require('opencode').prompt('Optimize @selection for performance and readability') end, mode = 'v', desc = 'Optimize selected code' },
    { '<leader>oo', function() require('opencode').ask('@file') end, mode = { 'n', 'v' }, desc = 'Ask opencode about current file' },
    { '<leader>oF', function() require('opencode').prompt('Fix these @diagnostics') end, mode = 'n', desc = 'Fix errors' },
    { '<leader>of', function() require('opencode').prompt('Fix @selection') end, mode = 'v', desc = 'Fix selected code' },
    { '<leader>oe', function() require('opencode').prompt('Explain @cursor and its context') end, mode = 'n', desc = 'Explain code near cursor' },
    { '<leader>od', function() require('opencode').prompt('Add documentation comments for @selection') end, mode = 'v', desc = 'Add Docs to selected code' },
    { '<leader>oa', function() require('opencode').ask() end, mode = { 'n', 'v' }, desc = 'Ask opencode' },
  },
}
