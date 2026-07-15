return {
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    opts = {
      folding = { enabled = false },
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

          -- Handle mini.files buffer (format: minifiles://N/path)
          if current_file:match("^minifiles://") then
            path = current_file:match("^minifiles://%d+/(.+)$")
          elseif current_file ~= "" then
            path = vim.fn.fnamemodify(current_file, ":h")
          else
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
