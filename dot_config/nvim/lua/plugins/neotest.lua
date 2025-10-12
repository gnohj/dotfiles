return {
  "nvim-neotest/neotest",
  enabled = true,
  lazy = true,
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    "marilari88/neotest-vitest",
  },
  -- Fixes relative path resolution in monorepo - https://github.com/marilari88/neotest-vitest/issues/75
  config = function()
    local neotest = require("neotest")

    local function find_nearest_node_modules_dir()
      local current_dir = vim.fn.expand("%:p:h") -- current buffer dir
      while current_dir ~= "/" do
        if vim.fn.isdirectory(current_dir .. "/node_modules") == 1 then
          return current_dir
        end
        current_dir = vim.fn.fnamemodify(current_dir, ":h")
      end
      return nil
    end

    local function get_root_dir()
      local original_cwd = vim.fn.getcwd()
      local node_modules_dir = find_nearest_node_modules_dir()
      return node_modules_dir or original_cwd
    end

    neotest.setup({
      adapters = {
        require("neotest-vitest")({
          cwd = get_root_dir,
          filter_dir = function(name, rel_path, root)
            return name ~= "node_modules"
          end,
        }),
      },
    })
  end,
}
