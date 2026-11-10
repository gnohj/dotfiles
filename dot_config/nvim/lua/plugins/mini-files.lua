return {
  "nvim-mini/mini.files",
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
      width_preview = 60,
    })

    if vim.g.mini_files_show_c == nil then vim.g.mini_files_show_c = true end

    opts.content = vim.tbl_deep_extend("force", opts.content or {}, {
      filter = function(entry)
        local name = entry.name
        local name_lower = name:lower()

        if entry.fs_type == "directory" and name == ".git" then
          return false
        end

        local cwd = vim.fn.getcwd()
        local is_second_brain = cwd:match("Obsidian/second%-brain") ~= nil

        if is_second_brain then
          return true
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

  init = function()
    local last_bounds

    local function resize_rex_layer(bounds)
      local key = table.concat(bounds, ",")
      if key == last_bounds or not vim.env.REX_SESSION then return end
      last_bounds = key
      local session = vim.env.REX_SESSION
      vim.system({ "rex", "api", "call", "-s", session, "session.view" }, { text = true }, function(view)
        local ok, data = pcall(vim.json.decode, view.stdout or "")
        if view.code ~= 0 or not ok then return end
        local layer_id
        for _, win in ipairs(data.windows or {}) do
          for _, layer in ipairs(win.layers or {}) do
            local block = layer.kind == "floating" and layer.blocks and layer.blocks[1]
            if block and block.label == "neorex" then layer_id = layer.layer_id end
          end
        end
        if not layer_id then return end
        local args = vim.json.encode({ layer_id = layer_id, bounds = bounds })
        vim.system({ "rex", "api", "call", "-s", session, "session.resize_layer", args })
      end)
    end

    local function center_in_neorex()
      local state = require("mini.files").get_explorer_state()
      if not state then return end
      local wins = vim.tbl_filter(function(w) return vim.api.nvim_win_is_valid(w.win_id) end, state.windows)
      if #wins == 0 then return end
      local lines, columns = vim.o.lines - vim.o.cmdheight, vim.o.columns
      local height = math.max(10, math.floor(lines * 0.6))
      local total = 0
      for _, w in ipairs(wins) do
        total = total + vim.api.nvim_win_get_width(w.win_id) + 2
      end
      local col = math.max(0, math.floor((columns - total) / 2))
      local row = math.max(0, math.floor((lines - height - 2) / 2))
      local left = col
      for _, w in ipairs(wins) do
        local config = vim.api.nvim_win_get_config(w.win_id)
        config.row, config.col, config.height = row, col, height
        vim.api.nvim_win_set_config(w.win_id, config)
        col = col + config.width + 2
      end
      local width = math.min((total + 3) / columns, 1)
      local tall = math.min((height + 4) / vim.o.lines, 1)
      return {
        math.max(0, math.min((left - 1) / columns, 1 - width)),
        math.max(0, math.min((row - 1) / vim.o.lines, 1 - tall)),
        width,
        tall,
      }
    end

    local focus_ns = vim.api.nvim_create_namespace("minifiles_focused_line")
    local function mark_focused_line(buf, win)
      if not vim.api.nvim_buf_is_valid(buf) then return end
      vim.api.nvim_buf_clear_namespace(buf, focus_ns, 0, -1)
      if win ~= vim.api.nvim_get_current_win() or not vim.api.nvim_win_is_valid(win) then return end
      local row = vim.api.nvim_win_get_cursor(win)[1] - 1
      vim.api.nvim_buf_set_extmark(buf, focus_ns, row, 0, {
        end_row = row + 1,
        hl_group = "MiniFilesCursorLineFocused",
        priority = 250,
      })
    end

    local pending = false
    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesWindowUpdate",
      callback = function(args)
        local win = args.data.win_id
        local group = win == vim.api.nvim_get_current_win() and "MiniFilesCursorLineFocused" or "MiniFilesCursorLine"
        local entries = vim.tbl_filter(function(entry)
          return entry ~= "" and not entry:match("^CursorLine:")
        end, vim.split(vim.wo[win].winhighlight, ","))
        table.insert(entries, "CursorLine:" .. group)
        vim.wo[win].winhighlight = table.concat(entries, ",")
        mark_focused_line(args.data.buf_id, win)
        if not _G.neorex then return end
        center_in_neorex()
        if pending then return end
        pending = true
        vim.schedule(function()
          pending = false
          local bounds = center_in_neorex()
          if bounds then resize_rex_layer(bounds) end
        end)
      end,
    })
    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesExplorerClose",
      callback = function() last_bounds = nil end,
    })
    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesBufferCreate",
      callback = function(args)
        local buf = args.data.buf_id
        vim.keymap.set("n", "J", "<Nop>", { buffer = buf })
        vim.keymap.set("n", "K", "<Nop>", { buffer = buf })
        vim.api.nvim_create_autocmd("CursorMoved", {
          buffer = buf,
          callback = function() mark_focused_line(buf, vim.api.nvim_get_current_win()) end,
        })
      end,
    })
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
          require("mini.files").open(dir_name, true)
        else
          require("mini.files").open(vim.uv.cwd(), true)
        end
      end,
      desc = "Open mini.files (Directory of Current File or CWD if not exists)",
    },
    -- Open at git root (works from root or nested package)
    {
      "<leader>E",
      function()
        local result = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")
        local root = (vim.v.shell_error == 0 and result[1]) or vim.uv.cwd()
        require("mini.files").open(root, true)
      end,
      desc = "Open mini.files (git root)",
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

                local cwd = vim.fn.getcwd()
                local is_second_brain = cwd:match("Obsidian/second%-brain")
                  ~= nil

                if is_second_brain then
                  return true
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

                return true
              end,
            },
          })
        end
      end,
      desc = "Toggle c files visibility",
    },
  },
}
