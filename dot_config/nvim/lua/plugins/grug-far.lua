return {
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    opts = {
      -- Disable folding.
      folding = { enabled = false },
      -- Don't numerate the result list.
      resultLocation = { showNumberLabel = false },
      -- showCompactInputs = true,
    },
    keys = {
      {
        "<leader>sr",
        function()
          local grug = require("grug-far")
          local current_file = vim.api.nvim_buf_get_name(0)
          local path

          if current_file ~= "" then
            -- Use current file's directory if buffer has a file
            path = vim.fn.fnamemodify(current_file, ":h")
          else
            -- Fallback to current working directory
            path = vim.fn.getcwd()
          end

          grug.open({
            prefills = {
              paths = path,
            },
          })
        end,
        mode = { "n", "v" },
        desc = "Search and Replace",
      },
    },
  },
}
