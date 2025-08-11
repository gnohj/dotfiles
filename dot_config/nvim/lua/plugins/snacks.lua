if vim.g.vscode then
  return {}
end

local colors = require("config.colors")

return {
  "folke/snacks.nvim",
  lazy = false,
  priority = 1000,
  keys = {
    {
      "<M-k>",
      function()
        Snacks.picker.keymaps({
          layout = "vertical",
        })
      end,
      desc = "Keymaps",
    },
    { "<leader><space>", false },
    -- Open git log in vertical view
    {
      "<leader>gl",
      function()
        Snacks.picker.git_log({
          finder = "git_log",
          format = "git_log",
          preview = "git_show",
          confirm = "git_checkout",
          layout = "vertical",
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

    -- Find Nvim Config File (Chezmoi)
    {
      "<leader>fc",
      function()
        local chezmoi_source =
          vim.fn.system("chezmoi source-path"):gsub("\n", "")
        local nvim_config_path = chezmoi_source .. "/dot_config/nvim"
        require("snacks").picker.files({
          hidden = true,
          title = "Nvim Chezmoi Config Source Files",
          cwd = nvim_config_path,
        })
      end,
      desc = "Find Config File",
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
            ["<Es>"] = { "close", mode = { "n", "i" } },
            -- I'm used to scrolling like this in LazyGit
            ["J"] = { "preview_scroll_down", mode = { "i", "n" } },
            ["K"] = { "preview_scroll_up", mode = { "i", "n" } },
            ["Z"] = { "preview_scroll_left", mode = { "i", "n" } },
            ["X"] = { "preview_scroll_right", mode = { "i", "n" } },
            -- Disable default Ctrl bindings and add Alt bindings
            ["<c-v>"] = false,
            ["<c-s>"] = false,
            ["<M-v>"] = { "vsplit", mode = { "i", "n" } },
            ["<M-s>"] = { "split", mode = { "i", "n" } },
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
  },
}
