local colors = require("config.colors")

return {
  "folke/snacks.nvim",
  lazy = false,
  priority = 1000,
  keys = {
    {
      "<leader>gi",
      function()
        Snacks.picker.gh_issue()
      end,
      desc = "GitHub Issues (open)",
    },
    {
      "<leader>gI",
      function()
        Snacks.picker.gh_issue({ state = "all" })
      end,
      desc = "GitHub Issues (all)",
    },
    {
      "<leader>gp",
      function()
        Snacks.picker.gh_pr()
      end,
      desc = "GitHub Pull Requests (open)",
    },
    {
      "<leader>gP",
      function()
        Snacks.picker.gh_pr({ state = "all" })
      end,
      desc = "GitHub Pull Requests (all)",
    },
    {
      "<leader>gz",
      function()
        -- Get git root directory
        local git_root = vim.fn
          .system(
            "git -C "
              .. vim.fn.shellescape(vim.fn.expand("%:p:h"))
              .. " rev-parse --show-toplevel 2>/dev/null"
          )
          :gsub("\n", "")

        if git_root == "" or vim.v.shell_error ~= 0 then
          vim.notify("Not in a git repository", vim.log.levels.WARN)
          return
        end

        -- Get PR number for current branch from git root
        local pr_number = vim.fn
          .system(
            "cd "
              .. vim.fn.shellescape(git_root)
              .. " && gh pr view --json number -q .number 2>/dev/null"
          )
          :gsub("\n", "")

        if pr_number == "" or vim.v.shell_error ~= 0 then
          vim.notify(
            "Current branch is not associated with a PR",
            vim.log.levels.WARN
          )
          return
        end

        -- Open PR diff
        Snacks.picker.gh_diff({ pr = tonumber(pr_number) })
      end,
      desc = "GitHub PR Diff (current branch)",
    },
    {
      "<leader>gZ",
      function()
        -- Get git root directory
        local git_root = vim.fn
          .system(
            "git -C "
              .. vim.fn.shellescape(vim.fn.expand("%:p:h"))
              .. " rev-parse --show-toplevel 2>/dev/null"
          )
          :gsub("\n", "")

        if git_root == "" or vim.v.shell_error ~= 0 then
          vim.notify("Not in a git repository", vim.log.levels.WARN)
          return
        end

        -- Get PR number for current branch from git root
        local pr_number = vim.fn
          .system(
            "cd "
              .. vim.fn.shellescape(git_root)
              .. " && gh pr view --json number -q .number 2>/dev/null"
          )
          :gsub("\n", "")

        if pr_number == "" or vim.v.shell_error ~= 0 then
          vim.notify(
            "Current branch is not associated with a PR",
            vim.log.levels.WARN
          )
          return
        end

        -- Get repo from git remote (format: owner/repo)
        local remote_url = vim.fn
          .system(
            "cd "
              .. vim.fn.shellescape(git_root)
              .. " && git config --get remote.origin.url 2>/dev/null"
          )
          :gsub("\n", "")

        -- Extract owner/repo from git URL (handles both SSH and HTTPS)
        local repo = remote_url:match("github%.com[:/](.+)%.git")
          or remote_url:match("github%.com[:/](.+)$")

        if not repo then
          vim.notify(
            "Failed to extract repository from git remote",
            vim.log.levels.ERROR
          )
          return
        end

        pr_number = tonumber(pr_number)
        if not pr_number then
          vim.notify("Failed to parse PR number", vim.log.levels.ERROR)
          return
        end

        -- Open PR in buffer directly
        local buf_name = "gh://" .. repo .. "/pr/" .. pr_number
        vim.cmd("edit " .. buf_name)
      end,
      desc = "Open GitHub PR (current branch)",
    },
    { "<leader><space>", false },
    {
      "<leader>ga",
      function()
        -- Opens GitHub actions for current PR automatically
        Snacks.picker.gh_actions()
      end,
      desc = "GitHub PR Actions (current branch)",
    },
    { "<leader>gd", false },
    {
      "<leader>gh",
      function()
        Snacks.picker.git_diff()
      end,
      desc = "Git Diff Hunks",
    },
    {
      "<leader>gl",
      function()
        Snacks.picker.git_log({
          finder = "git_log",
          format = "git_log",
          preview = "git_show",
          confirm = "git_checkout",
          layout = "ivy",
        })
      end,
      desc = "Git Log",
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
          layout = "ivy",
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
          layout = "ivy",
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
    -- Find Files - default snacks <leader>ff doesn't work well with frecency and sorting, so overriding here
    {
      "<leader>ff",
      function()
        require("snacks").picker.smart({
          title = "Files", -- Custom title instead of "Smart"
          multi = { "files" },
          matcher = {
            cwd_bonus = true, -- rank cwd matches higher than nested sub dir matches
            fuzzy = true,
            smartcase = true,
          },
          sort = function(a, b) -- gets called after the internal matcher score
            -- Try to pull recency information if available; if not, rely on the internal matcher score.
            local a_time = a.last_used or 0
            local b_time = b.last_used or 0
            if a_time ~= b_time then
              return a_time > b_time
            else
              return (a.score or 0) > (b.score or 0)
            end
          end,
          win = {
            preview = {
              wo = { number = false, relativenumber = false },
            },
          },
        })
      end,
      desc = "[P]Snacks picker files",
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
      matcher = {
        frecency = true,
        cwd_bonus = true, -- rank cwd matches higher than nested sub dir matches
        smartcase = true, -- Case-insensitive unless uppercase letters are used
      },
      sources = {
        gh_issue = {
          layout = {
            preset = "sidebar",
            layout = {
              box = "horizontal",
              width = 0.9,
              min_width = 120,
              height = 0.9,
              {
                box = "vertical",
                border = true,
                title = "{title} {live} {flags}",
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
              },
              {
                win = "preview",
                title = "{preview}",
                border = true,
                width = 0.5,
              },
            },
            preview = "true",
            cycle = false,
          },
          -- your gh_issue picker configuration comes here
          -- or leave it empty to use the default settings
        },
        gh_pr = {
          layout = {
            preset = "sidebar",
            layout = {
              box = "horizontal",
              width = 0.9,
              min_width = 120,
              height = 0.9,
              {
                box = "vertical",
                border = true,
                title = "{title} {live} {flags}",
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
              },
              {
                win = "preview",
                title = "{preview}",
                border = true,
                width = 0.5,
              },
            },
            preview = "true",
            cycle = false,
          },
          -- your gh_pr picker configuration comes here
          -- or leave it empty to use the default settings
        },
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
        preset = "ivy",
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
            -- I'm used to scrolling like this in LazyGit
            ["J"] = { "preview_scroll_down", mode = { "i", "n" } },
            ["K"] = { "preview_scroll_up", mode = { "i", "n" } },
            ["Z"] = { "preview_scroll_left", mode = { "i", "n" } },
            ["X"] = { "preview_scroll_right", mode = { "i", "n" } },
          },
        },
      },
    },
    -- Configure the dashboard
    dashboard = {
      preset = {
        keys = {
          -- {
          --   icon = " ",
          --   key = "c",
          --   desc = "Config",
          --   action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
          -- },
          {
            icon = " ",
            key = "s",
            desc = "Restore Session",
            section = "session",
          },
          -- { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
          {
            icon = " ",
            key = "<Esc>",
            hidden = true,
            desc = "Quit",
            action = ":qa",
          },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
        header = [[
                                                                    
      ████ ██████           █████      ██                     
     ███████████             █████                             
     █████████ ███████████████████ ███   ███████████   
    █████████  ███    █████████████ █████ ██████████████   
   █████████ ██████████ █████████ █████ █████ ████ █████   
 ███████████ ███    ███ █████████ █████ █████ ████ █████  
██████  █████████████████████ ████ █████ █████ ████ ██████ 

 [@gnohj]
]],
      },
    },
    -- Zen mode configuration delegated to auto-zen module
    zen = require("config.auto-zen").get_zen_config(),
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
    gh = {},
    dim = {},
    toggle = {},
    scroll = { enabled = false },
    indent = { enabled = false },
    animate = { enabled = false },
    words = { enabled = false }, -- Disable automatic word highlighting under cursor
  },
}
