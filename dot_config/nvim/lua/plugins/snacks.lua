if vim.g.vscode then
  return {}
end

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
    -- Navigate my buffers
    {
      "<S-h>",
      function()
        Snacks.picker.buffers({
          -- I always want my buffers picker to start in normal mode
          on_show = function()
            vim.cmd.stopinsert()
          end,
          finder = "buffers",
          format = "buffer",
          hidden = false,
          unloaded = true,
          current = true,
          sort_lastused = true,
          win = {
            input = {
              keys = {
                ["d"] = "bufdelete",
              },
            },
            list = { keys = { ["d"] = "bufdelete" } },
          },
          -- In case you want to override the layout for this keymap
          -- layout = "ivy",
        })
      end,
      desc = "[P]Snacks picker buffers",
    },
  },
  opts = {
    picker = {
      sources = {
        files = { hidden = true },
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
        -- When reaching the bottom of the results in the picker, I don't want
        -- it to cycle and go back to the top
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
              { win = "preview", title = "{preview}", width = 0.5, border = "left" },
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
            { win = "preview", title = "{preview}", height = 0.4, border = "top" },
          },
        },
      },
      matcher = {
        frecency = true,
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
            -- ["H"] = { "preview_scroll_left", mode = { "i", "n" } },
            -- ["L"] = { "preview_scroll_right", mode = { "i", "n" } },
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
          { icon = " ", key = "s", desc = "Restore Session", section = "session" },
          { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
          { icon = " ", key = "<Esc>", desc = "Quit", action = ":qa" },
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
    -- This keeps the image on the top right corner, basically leaving your
    -- text area free, suggestion found in reddit by user `Redox_ahmii`
    -- https://www.reddit.com/r/neovim/comments/1irk9mg/comment/mdfvk8b/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
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

    -- Configure LazyGit - use macoS global shorttcut to open lazygit via new tmux window - command + g
    -- lazygit = {
    --   -- Automatically configure lazygit to use the current colorscheme
    --   configure = true,
    --   -- Extra configuration for lazygit that will be merged with the default
    --   config = {
    --     os = { editPreset = "nvim-remote" },
    --     gui = { nerdFontsVersion = "3" },
    --   },
    --   theme_path = vim.fs.normalize(vim.fn.stdpath("cache") .. "/lazygit-theme.yml"),
    --   -- Theme for lazygit
    --   theme = {
    --     [241] = { fg = "Special" },
    --     activeBorderColor = { fg = "MatchParen", bold = true },
    --     cherryPickedCommitBgColor = { fg = "Identifier" },
    --     cherryPickedCommitFgColor = { fg = "Function" },
    --     defaultFgColor = { fg = "Normal" },
    --     inactiveBorderColor = { fg = "FloatBorder" },
    --     optionsTextColor = { fg = "Function" },
    --     searchingActiveBorderColor = { fg = "MatchParen", bold = true },
    --     selectedLineBgColor = { bg = "Visual" }, -- Set to `default` to have no background colour
    --     unstagedChangesColor = { fg = "DiagnosticError" },
    --   },
    --   win = {
    --     style = "lazygit",
    --   },
    -- },

    -- Ensure the LazyGit theme and config are applied

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
