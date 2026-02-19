local colors = require("config.colors")

local function get_header()
  local rainbow_colors = {
    colors["gnohj_color04"],
    colors["gnohj_color02"],
    colors["gnohj_color03"],
    colors["gnohj_color05"],
    colors["gnohj_color06"],
  }
  for i, color in ipairs(rainbow_colors) do
    if color then
      vim.api.nvim_set_hl(0, "SnacksDashboardRainbow" .. i, { fg = color })
    end
  end
  local blue = colors["gnohj_color04"]
  if blue then
    vim.api.nvim_set_hl(0, "SnacksDashboardRecentFile", { fg = blue })
  end
  vim.api.nvim_set_hl(
    0,
    "SnacksDashboardTitle",
    { link = "SnacksDashboardDesc" }
  )
  vim.api.nvim_set_hl(
    0,
    "SnacksDashboardIcon",
    { link = "SnacksDashboardDesc" }
  )

  local name = vim.fn.system('tmux display-message -p "#S"')
  if vim.v.shell_error ~= 0 or name:match("^%s*$") then
    name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  else
    name = name:gsub("%s+$", "")
    name = name:match("[^/]+$") or name
  end

  local section = { width = 2000, align = "center", padding = 0 }

  local fonts = { "larry3d" }
  math.randomseed(os.time())
  local font = fonts[math.random(#fonts)]

  name = name:gsub("_", " ")
  local figlet = vim.fn.system({ "figlet", "-w", "1000", "-f", font, name })
  if vim.v.shell_error ~= 0 then
    section.text = name
    return section
  end

  figlet = figlet:gsub("%s+$", "") .. "\n"

  local result = {}
  local color_idx = 1
  local num_colors = #rainbow_colors
  for char in figlet:gmatch(".") do
    if char:match("%S") then
      table.insert(result, { char, hl = "SnacksDashboardRainbow" .. color_idx })
      color_idx = color_idx % num_colors + 1
    else
      table.insert(result, { char })
    end
  end
  section.text = result
  return section
end

local function get_unstaged_changes()
  if not Snacks.git.get_root() then
    return
  end
  local result = vim.fn.system("git diff --stat")
  if vim.v.shell_error ~= 0 or result:match("^%s*$") then
    return
  end
  local red = colors["gnohj_color11"] or "#da858e"
  local r = tonumber(red:sub(2, 3), 16)
  local g = tonumber(red:sub(4, 5), 16)
  local b = tonumber(red:sub(6, 7), 16)
  local ansi = string.format("\\033[38;2;%d;%d;%dm", r, g, b)
  local cmd = string.format(
    'git diff --color=always --stat=55 | awk \'{a[NR]=$0} END{for(i=1;i<=4&&i<NR;i++) print a[i]; if(NR>5) print " ...and more"; print "%s" a[NR] "\\033[0m"}\'',
    ansi
  )
  return {
    icon = " ",
    title = "Unstaged Changes",
    section = "terminal",
    cmd = cmd,
    height = 7,
    indent = 2,
    padding = 0,
    ttl = 0,
  }
end

return {
  "folke/snacks.nvim",
  lazy = false,
  priority = 1000,
  keys = {
    { "<leader><space>", false },
    { "<leader>fg", false }, -- Disabled
    { "<leader>sg", false }, -- Replaced by Seeker grep
    -- Find Files with frecency (git files only)
    {
      "<leader>ff",
      function()
        Snacks.picker.smart({
          title = "Git Files",
          multi = { "buffers", "recent", "git_files" },
          format = "file",
          matcher = {
            cwd_bonus = true,
            frecency = true,
            sort_empty = true,
          },
          filter = {
            cwd = true,
          },
          transform = "unique_file",
          win = {
            preview = {
              wo = { number = false, relativenumber = false },
            },
          },
        })
      end,
      desc = "Find Git Files (frecency)",
    },
    -- LazyVim default find files (moved to fF)
    {
      "<leader>fF",
      function()
        Snacks.picker.smart({
          title = "Files",
          multi = { "buffers", "recent", "files" },
          format = "file",
          hidden = false,
          ignored = false,
          matcher = {
            cwd_bonus = true,
            frecency = true,
            sort_empty = true,
          },
          filter = {
            cwd = true,
          },
          transform = "unique_file",
          win = {
            preview = {
              wo = { number = false, relativenumber = false },
            },
          },
        })
      end,
      desc = "Find Files (frecency)",
    },
    -- Recent files (cwd only)
    {
      "<leader>fr",
      function()
        Snacks.picker.recent({
          filter = { cwd = true },
        })
      end,
      desc = "Recent Files (cwd)",
    },
    -- Recent files (global)
    {
      "<leader>fR",
      function()
        Snacks.picker.recent()
      end,
      desc = "Recent Files (global)",
    },
    -- Harper diagnostics picker (overrides default search highlight)
    {
      "<leader>sh",
      function()
        require("snacks").picker.diagnostics({
          title = "Harper Diagnostics",
          filter = {
            cwd = false, -- Show all, not just cwd
            filter = function(item)
              return item.source == "Harper"
                or (item.item and item.item.source == "Harper")
            end,
          },
        })
      end,
      desc = "Harper Diagnostics",
    },
    -- Ignore all Harper diagnostics in current buffer
    {
      "<leader>sH",
      function()
        local bufnr = vim.api.nvim_get_current_buf()
        local diagnostics = vim.diagnostic.get(bufnr, {})
        local harper_diagnostics = vim.tbl_filter(function(d)
          return d.source == "Harper"
        end, diagnostics)

        if #harper_diagnostics == 0 then
          vim.notify("No Harper diagnostics to ignore", vim.log.levels.INFO)
          return
        end

        local ignored = 0
        for _, d in ipairs(harper_diagnostics) do
          vim.api.nvim_win_set_cursor(0, { d.lnum + 1, d.col })
          vim.lsp.buf.code_action({
            filter = function(action)
              return action.title and action.title:match("Ignore")
            end,
            apply = true,
          })
          ignored = ignored + 1
        end
        vim.notify(
          string.format("Ignored %d Harper diagnostics", ignored),
          vim.log.levels.INFO
        )
      end,
      desc = "Ignore all Harper diagnostics",
    },
    { "<leader>gh", false }, -- Disable git_log_line (blank)
    { "<leader>gl", false, mode = { "n", "v" } }, -- Disable default git_log completely
    {
      "<leader>gL",
      function()
        Snacks.picker.git_log()
      end,
      desc = "Git Log",
    },
    -- gh-dash keybindings
    {
      "<leader>gp",
      function()
        local cwd = vim.fn.getcwd()
        vim.fn.jobstart(
          { "tmux", "new-window", "-n", "🐙", "-c", cwd, "gh-dash" },
          { detach = true }
        )
      end,
      desc = "gh-dash PRs (tmux)",
    },
    -- Package Picker (monorepo) - overrides LazyVim's <leader>fp
    {
      "<leader>fp",
      function()
        require("config.monorepo-picker").pick()
      end,
      desc = "Monorepo Picker",
    },
    -- Move LazyVim's projects picker to <leader>fP
    {
      "<leader>fP",
      function()
        Snacks.picker.projects()
      end,
      desc = "Projects (LazyVim)",
    },
    {
      "<S-u>",
      function()
        -- Create the highlight group
        vim.api.nvim_set_hl(0, "CustomTeal", { fg = colors["gnohj_color11"] })

        -- Get all unsaved buffers
        local unsaved_buffers = {}
        local buffer_map = {}
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if
            vim.api.nvim_buf_is_loaded(buf)
            and vim.api.nvim_buf_get_option(buf, "modified")
          then
            local name = vim.api.nvim_buf_get_name(buf)
            local display_name = name == "" and "[No Name]"
              or vim.fn.fnamemodify(name, ":~:.")
            local display_text = "● " .. display_name
            table.insert(unsaved_buffers, display_text)
            buffer_map[display_text] = buf
          end
        end
        if #unsaved_buffers == 0 then
          vim.notify("No unsaved buffers", vim.log.levels.INFO)
          return
        end
        vim.ui.select(unsaved_buffers, {
          prompt = "Select unsaved buffer:",
          format_item = function(item)
            return item
          end,
        }, function(choice)
          if choice then
            local buf = buffer_map[choice]
            if buf then
              vim.api.nvim_set_current_buf(buf)
            end
          end
        end)
      end,
      desc = "[P]Unsaved buffers",
    },
    -- Also map Alt+h for unsaved buffers
    {
      "<M-h>",
      function()
        -- Create the highlight group
        vim.api.nvim_set_hl(0, "CustomTeal", { fg = colors["gnohj_color11"] })

        -- Get all unsaved buffers
        local unsaved_buffers = {}
        local buffer_map = {}
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if
            vim.api.nvim_buf_is_loaded(buf)
            and vim.api.nvim_buf_get_option(buf, "modified")
          then
            local name = vim.api.nvim_buf_get_name(buf)
            local display_name = name == "" and "[No Name]"
              or vim.fn.fnamemodify(name, ":~:.")
            local display_text = "● " .. display_name
            table.insert(unsaved_buffers, display_text)
            buffer_map[display_text] = buf
          end
        end
        if #unsaved_buffers == 0 then
          vim.notify("No unsaved buffers", vim.log.levels.INFO)
          return
        end
        vim.ui.select(unsaved_buffers, {
          prompt = "Select unsaved buffer:",
          format_item = function(item)
            return item
          end,
        }, function(choice)
          if choice then
            local buf = buffer_map[choice]
            if buf then
              vim.api.nvim_set_current_buf(buf)
            end
          end
        end)
      end,
      desc = "[P]Unsaved buffers (Alt)",
    },

    -- Find Config Files (Chezmoi)
    {
      "<leader>fC",
      function()
        local chezmoi_source =
          vim.fn.system("chezmoi source-path"):gsub("\n", "")
        local config_path = chezmoi_source .. "/dot_config"
        require("snacks").picker.files({
          hidden = true,
          title = "Find Config Files (Chezmoi)",
          cwd = config_path,
        })
      end,
      desc = "Find Config Files (Chezmoi)",
    },
    -- Find Config Files (~/.config)
    {
      "<leader>fc",
      function()
        local config_path = vim.fn.expand("~/.config")
        require("snacks").picker.files({
          hidden = true,
          title = "Find Config Files (~/.config)",
          cwd = config_path,
        })
      end,
      desc = "Find Config Files (~/.config)",
    },
    -- Git status with preview, respects .gitignore
    {
      "<leader>gs",
      function()
        -- Custom git status that respects .gitignore
        require("snacks").picker({
          title = "Git Status",
          -- layout = "ivy",
          hidden = true, -- show hidden files (like .env, .gitignore, etc)
          finder = "proc",
          cmd = "git",
          args = { "status", "--porcelain", "-unormal" },
          format = "git_status",
          preview = "git_status",
          transform = function(item)
            local status, file = item.text:match("^(..) (.+)$")
            if status then
              item.status = status
              item.file = file
              item.text = file
            end
            return item
          end,
          win = {
            input = {
              keys = {
                ["<Tab>"] = { "git_stage", mode = { "n", "i" } },
              },
            },
          },
        })
      end,
      desc = "Git Status (with preview)",
    },
    -- Git unstaged changes (modified but not staged)
    {
      "<leader>gu",
      function()
        require("snacks").picker.git_diff({
          staged = false,
          title = "Git Unstaged Changes",
        })
      end,
      desc = "Git Unstaged Changes",
    },
    -- PR branch changes (diff against base branch)
    {
      "<leader>gP",
      function()
        local root = vim.fn.systemlist("git rev-parse --show-toplevel")[1] or ""
        local base
        if root:match("/Developer/web/") then
          base = "origin/master"
        elseif root:match("/Developer/inferno/") then
          base = "origin/develop"
        else
          local head = vim.fn.systemlist("git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null")[1]
          base = head and head:match("(refs/remotes/origin/.+)") or "origin/main"
        end
        Snacks.picker.git_diff({
          title = "PR Changes (vs " .. base:gsub("origin/", "") .. ")",
          base = base,
          group = true,
        })
      end,
      desc = "PR Branch Changes",
    },
    -- Environment variables picker
    {
      "<leader>se",
      function()
        local env_items = {}
        for key, value in pairs(vim.fn.environ()) do
          table.insert(env_items, {
            text = key .. "=" .. value,
            key = key,
            value = value,
            preview = {
              text = "Key: " .. key .. "\n\nValue:\n" .. value,
            },
          })
        end
        table.sort(env_items, function(a, b)
          return a.key < b.key
        end)

        require("snacks").picker({
          title = "Environment Variables",
          -- layout = "ivy",
          preview = "preview", -- Use the preview field from items
          finder = function()
            return env_items
          end,
          confirm = function(picker, item)
            vim.fn.setreg("+", item.value)
            vim.notify("Copied to clipboard: " .. item.key, vim.log.levels.INFO)
            picker:close()
            return true -- Prevent default action
          end,
        })
      end,
      desc = "Environment Variables",
    },

    -- Navigate buffers
    {
      "<S-h>",
      function()
        Snacks.picker.buffers({
          on_show = function()
            vim.cmd.stopinsert()
          end,
          sort_lastused = true,
          finder = "buffers",
          format = "buffer",
          unloaded = true,
          current = true,
          win = {
            input = {
              keys = {
                ["d"] = "bufdelete",
              },
            },
            list = { keys = { ["d"] = "bufdelete" } },
          },
        })
      end,
      desc = "[P]Snacks picker buffers",
    },
  },
  opts = {
    picker = {
      hidden = false,
      ignored = true,
      sources = {
        grep = {
          exclude = {
            "index.js",
            "index.js.map",
            "index.d.ts",
            "*.min.js",
            "*.min.css",
            "*.ts.html",
          },
        },
      },
      matcher = {
        frecency = true,
        cwd_bonus = true, -- rank cwd matches higher than nested sub dir matches
        smartcase = true, -- Case-insensitive unless uppercase letters are used
      },
      formatters = { file = { filename_first = true, truncate = 80 } },
      transform = function(item)
        if not item.file then
          return item
        end
        if item.file:match("lazyvim/lua/config/keymaps%.lua") then
          item.score_add = (item.score_add or 0) - 30
        end
        return item
      end,
      debug = {
        scores = false,
      },
      layout = {
        -- preset = "ivy",
        cycle = false,
      },
      layouts = {
        ivy = {
          layout = {
            box = "vertical",
            backdrop = false,
            row = -1,
            width = 0,
            height = 0.5,
            border = "top",
            title = " {title} {live} {flags}",
            title_pos = "left",
            { win = "input", height = 1, border = "bottom" },
            {
              box = "horizontal",
              { win = "list", border = "none" },
              {
                win = "preview",
                title = "{preview}",
                width = 0.5,
                border = "left",
              },
            },
          },
        },
        vertical = {
          layout = {
            backdrop = false,
            width = 0.8,
            min_width = 80,
            height = 0.8,
            min_height = 30,
            box = "vertical",
            border = "rounded",
            title = "{title} {live} {flags}",
            title_pos = "center",
            { win = "input", height = 1, border = "bottom" },
            { win = "list", border = "none" },
            {
              win = "preview",
              title = "{preview}",
              height = 0.4,
              border = "top",
            },
          },
        },
      },
      win = {
        input = {
          keys = {
            -- to close the picker on ESC instead of going to normal mode,
            -- add the following keymap to your config
            ["<Esc>"] = { "close", mode = { "n", "i" } },
            -- I'm used to scrolling like this in LazyGit (normal mode only)
            ["J"] = { "preview_scroll_down", mode = { "n" } },
            ["K"] = { "preview_scroll_up", mode = { "n" } },
            ["H"] = { "preview_scroll_left", mode = { "n" } },
            ["L"] = { "preview_scroll_right", mode = { "n" } },
          },
        },
      },
    },
    -- Configure the dashboard
    dashboard = {
      width = 60,
      formats = {
        file = function(item, ctx)
          local fname = vim.fn.fnamemodify(item.file, ":t")
          return { { fname, hl = "SnacksDashboardRecentFile" } }
        end,
      },
      sections = {
        get_header,
        { section = "startup", padding = 1 },
        { section = "keys", gap = 1, padding = 1 },
        {
          icon = " ",
          title = "Recent Files",
          section = "recent_files",
          limit = 3,
          cwd = true,
          indent = 3,
          padding = 1,
        },
        get_unstaged_changes,
      },
      preset = {
        keys = {
          {
            icon = " ",
            key = "s",
            desc = "Restore Session",
            section = "session",
          },
          {
            icon = " ",
            key = "<Esc>",
            hidden = true,
            desc = "Quit",
            action = ":qa",
          },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
    },
    -- DISABLED: Testing zen.nvim (sand4rt) instead
    -- zen = require("config.auto-zen").get_zen_config(),
    zen = { enabled = false },
    scratch = {
      ft = "markdown",
      cmd = "Scratch",
      name = "Scratch",
    },
    styles = {
      snacks_image = {
        relative = "editor",
        col = -1,
      },
    },
    image = {
      enabled = true,
      doc = {
        inline = false,
        float = true,
        max_width = 60,
        max_height = 30,
      },
    },
    -- Configure notifier
    notifier = {
      enabled = true,
      top_down = false,
    },
    lazygit = {
      -- configure lazygit to not use nvim color scheme and load the global config file
      configure = false,
      args = {
        "--use-config-file",
        vim.fn.expand("~/.config/lazygit/config.yml"),
      },
      win = {
        width = 0.99,
        height = 0.99,
        row = 0.025,
        col = 0.025,
      },
    },
    bigfile = {},
    bufdelete = {},
    input = {},
    gitbrowse = {},
    dim = {},
    toggle = {},
    scroll = { enabled = false },
    indent = { enabled = false },
    animate = { enabled = false },
    words = { enabled = false }, -- Disable automatic word highlighting under cursor
  },
}
