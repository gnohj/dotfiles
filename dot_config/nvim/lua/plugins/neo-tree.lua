return {
  "nvim-neo-tree/neo-tree.nvim",
  enabled = false,
  keys = {
    -- I'm using these 2 keyamps already with mini.files, so avoiding conflict
    { "<leader>e", false },
    { "<leader>E", false },
    -- -- When I press <leader>r I want to show the current file in neo-tree,
    -- -- But if neo-tree is open it, close it, to work like a toggle
    {
      "<leader>r",
      function()
        local buf_name = vim.api.nvim_buf_get_name(0)
        -- Function to check if NeoTree is open in any window
        local function is_neo_tree_open()
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "neo-tree" then
              return true
            end
          end
          return false
        end
        -- Check if the current file exists
        if
          vim.fn.filereadable(buf_name) == 1
          or vim.fn.isdirectory(vim.fn.fnamemodify(buf_name, ":p:h")) == 1
        then
          if is_neo_tree_open() then
            -- Close NeoTree if it's open
            vim.cmd("Neotree close")
          else
            -- Open NeoTree and reveal the current file
            vim.cmd("Neotree reveal")
          end
        else
          -- If the file doesn't exist, execute the logic for <leader>R
          require("neo-tree.command").execute({
            toggle = true,
            dir = vim.uv.cwd(),
          })
        end
      end,
      desc = "[P]Toggle current file in NeoTree or open cwd if file doesn't exist",
    },
    {
      "<leader>R",
      function()
        require("neo-tree.command").execute({
          toggle = true,
          dir = vim.uv.cwd(),
        })
      end,
      desc = "Explorer NeoTree (cwd)",
    },
  },
  opts = {
    filesystem = {
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = true,
      },
      follow_current_file = {
        enabled = false,
      },
    },
  },
}
