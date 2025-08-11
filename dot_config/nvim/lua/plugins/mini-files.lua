if vim.g.vscode then
  return {}
end

return {
  "echasnovski/mini.files",
  opts = function(_, opts)
    opts.mappings = vim.tbl_deep_extend("force", opts.mappings or {}, {
      close = "<esc>",
      -- Use this if you want to open several files
      go_in = "l",
      -- This opens the file, but quits out of mini.files (default L)
      go_in_plus = "<CR>",
      -- I swapped the following 2 (default go_out: h)
      -- go_out_plus: when you go out, it shows you only 1 item to the right
      -- go_out: shows you all the items to the right
      go_out = "H",
      go_out_plus = "h",
      -- Default <BS>
      reset = "<BS>",
      -- Default @
      reveal_cwd = ".",
      show_help = "g?",
      -- Default = synchronize = "s",
      trim_left = "<",
      trim_right = ">",
    })

    opts.windows = vim.tbl_deep_extend("force", opts.windows or {}, {
      preview = true,
      width_focus = 30,
      width_preview = 80,
    })

    vim.g.mini_files_show_c = vim.g.mini_files_show_c or false

    opts.content = vim.tbl_deep_extend("force", opts.content or {}, {
      filter = function(entry)
        local name = entry.name
        local name_lower = name:lower()

        if entry.fs_type == "directory" and name == ".git" then
          return false
        end

        if vim.g.mini_files_show_c then
          return true
        end

        if
          name_lower == "claude.md"
          or name_lower == ".claude.json"
          or name == ".claude"
          or name_lower == ".claude.json.backup"
        then
          return false
        end

        if entry.fs_type == "directory" and name_lower == "tasks" then
          return false
        end

        return true
      end,
    })

    opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
      -- Whether to use for editing directories
      -- Disabled by default in LazyVim because neo-tree is used for that
      use_as_default_explorer = true,
      -- If set to false, files are moved to the trash directory
      -- To get this dir run :echo stdpath('data')
      -- ~/.local/share/nvim/mini.files/trash
      permanent_delete = false,
    })
    return opts
  end,

  keys = {
    {
      -- Open the directory of the file currently being edited
      -- If the file doesn't exist because you maybe switched to a new git branch
      -- open the current working directory
      "<leader>e",
      function()
        local buf_name = vim.api.nvim_buf_get_name(0)
        local dir_name = vim.fn.fnamemodify(buf_name, ":p:h")
        if vim.fn.filereadable(buf_name) == 1 then
          -- Pass the full file path to highlight the file
          require("mini.files").open(buf_name, true)
        elseif vim.fn.isdirectory(dir_name) == 1 then
          -- If the directory exists but the file doesn't, open the directory
          require("mini.files").open(dir_name, true)
        else
          -- If neither exists, fallback to the current working directory
          require("mini.files").open(vim.uv.cwd(), true)
        end
      end,
      desc = "Open mini.files (Directory of Current File or CWD if not exists)",
    },
    -- Open the current working directory
    {
      "<leader>E",
      function()
        require("mini.files").open(vim.uv.cwd(), true)
      end,
      desc = "Open mini.files (cwd)",
    },
    {
      "<leader>mc",
      function()
        vim.g.mini_files_show_c = not vim.g.mini_files_show_c
        local status = vim.g.mini_files_show_c and "shown" or "hidden"
        vim.notify("C is now " .. status, vim.log.levels.INFO)

        local MiniFiles = require("mini.files")
        if MiniFiles.get_explorer_state() ~= nil then
          MiniFiles.refresh({
            content = {
              filter = function(entry)
                local name = entry.name
                local name_lower = name:lower()

                if entry.fs_type == "directory" and name == ".git" then
                  return false
                end

                if vim.g.mini_files_show_c then
                  return true
                end

                if
                  name_lower == "claude.md"
                  or name_lower == ".claude.json"
                  or name == ".claude"
                  or name_lower == ".claude.json.backup"
                then
                  return false
                end

                if entry.fs_type == "directory" and name_lower == "tasks" then
                  return false
                end

                return true
              end,
            },
          })
        end
      end,
      desc = "Toggle c files and tasks folders",
    },
  },
}
