if vim.g.vscode then
  return {}
end

local colors = require("config.colors")

-- Custom component to display buffer count
local function buffer_count()
  local buffers = vim.fn.getbufinfo({ buflisted = 1 }) -- Only count listed buffers
  return "(" .. tostring(#buffers) .. ")"
end
local function buffer_count_with_unsaved()
  -- Count only unsaved buffers
  local unsaved_count = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_loaded(buf)
      and vim.api.nvim_buf_get_option(buf, "modified")
    then
      unsaved_count = unsaved_count + 1
    end
  end

  -- Only show count if there are unsaved buffers
  if unsaved_count > 0 then
    return tostring(unsaved_count) -- Just the number, no dot
  else
    return ""
  end
end

local function current_buffer_unsaved_dot()
  if vim.api.nvim_buf_get_option(0, "modified") then
    local count = buffer_count_with_unsaved()

    return "🚨 " .. count
  else
    return ""
  end
end

-- File permissions component
local function get_file_permissions()
  if vim.bo.filetype ~= "sh" then
    return ""
  end
  local file_path = vim.fn.expand("%:p")
  return file_path and vim.fn.getfperm(file_path) or ""
end

-- Custom component to display the file path, with `~` for the home directory
local function file_path()
  local full_path = vim.fn.expand("%:p") -- Get the full file path
  return full_path:gsub(vim.fn.expand("$HOME"), "  ~") -- Replace $HOME with ~
end

return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  enabled = false,
  opts = function(_, opts)
    table.remove(opts.sections.lualine_c, 1)
    table.remove(opts.sections.lualine_c, 2)
    table.remove(opts.sections.lualine_c, 3)
    table.remove(opts.sections.lualine_c, #opts.sections.lualine_c)
    table.insert(opts.sections.lualine_c, {
      "filename",
      path = 3,
    })
    local lazy_status = require("lazy.status") -- to configure lazy pending updates count
    local icons = require("lazyvim.config").icons

    return {

      options = {
        -- component_separators = { left = ")", right = "(" },
        section_separators = { left = "", right = "" },
        disabled_filetypes = {
          statusline = { "Avante", "AvanteInput", "AvanteSelectedFiles" },
          winbar = { "Avante", "AvanteInput", "AvanteSelectedFiles" },
        },
        theme = {
          normal = {
            a = {
              bg = colors["gnohj_color03"],
              fg = colors["gnohj_color10"],
              gui = "bold",
            },
            b = {
              -- bg = colors["gnohj_color08"],
              fg = colors["gnohj_color09"],
              separator = { left = "", right = "" },
            },
          },
          insert = {
            a = {
              bg = colors["gnohj_color02"],
              fg = colors["gnohj_color10"],
              gui = "bold",
            },
            b = {
              -- bg = colors["gnohj_color08"],
              fg = colors["gnohj_color09"],
              separator = { left = "", right = "" },
            },
          },
          visual = {
            a = {
              bg = colors["gnohj_color04"],
              fg = colors["gnohj_color10"],
              gui = "bold",
            },
            b = {
              -- bg = colors["gnohj_color08"],
              fg = colors["gnohj_color09"],
              separator = { left = "", right = "" },
            },
          },
          command = {
            a = {
              bg = colors["gnohj_color05"],
              fg = colors["gnohj_color10"],
              gui = "bold",
            },
            b = {
              -- bg = colors["gnohj_color08"],
              fg = colors["gnohj_color09"],
              separator = { left = "", right = "" },
            },
          },
          replace = {
            a = {
              bg = colors["gnohj_color11"],
              fg = colors["gnohj_color10"],
              gui = "bold",
            },
            b = {
              -- bg = colors["gnohj_color08"],
              fg = colors["gnohj_color09"],
              separator = { left = "", right = "" },
            },
          },
          inactive = {
            a = {
              bg = colors["gnohj_color07"],
              fg = colors["gnohj_color13"],
              gui = "bold",
            },
            b = {
              -- bg = colors["gnohj_color08"],
              fg = colors["gnohj_color09"],
              separator = { left = "", right = "" },
            },
          },
        },
      },
      sections = {
        lualine_a = { { "mode", separator = { left = "", right = "" } } },
        lualine_b = {
          -- {
          --   "branch",
          --   color = {
          --     -- bg = colors["gnohj_color08"],
          --     fg = colors["gnohj_color24"],
          --     gui = "bold",
          --   },
          --   separator = { left = "", right = "" },
          -- },
        },
        lualine_c = {
          {
            buffer_count,
            color = { fg = colors["gnohj_color04"], gui = "bold" },
          },
          {
            "diagnostics",
            symbols = {
              error = icons.diagnostics.Error,
              warn = icons.diagnostics.Warn,
              info = icons.diagnostics.Info,
              hint = icons.diagnostics.Hint,
            },
          },
          -- {
          --   "diff",
          --   symbols = {
          --     added = icons.git.added,
          --     modified = icons.git.modified,
          --     removed = icons.git.removed,
          --   },
          --   source = function()
          --     local gitsigns = vim.b.gitsigns_status_dict
          --     if gitsigns then
          --       return {
          --         added = gitsigns.added,
          --
          --         modified = gitsigns.changed,
          --         removed = gitsigns.removed,
          --       }
          --     end
          --   end,
          -- },
          {
            current_buffer_unsaved_dot,
            color = { fg = colors["gnohj_color11"] },
          },
          {
            require("package-info").get_status,
            color = { fg = colors["gnohj_color11"] },
          },
        },
        lualine_x = {
          {
            lazy_status.updates,
            cond = lazy_status.has_updates,
            color = { fg = colors["gnohj_color11"] },
          },
          {
            function()
              return require("noice").api.status.command.get()
            end,
            cond = function()
              return package.loaded["noice"]
                and require("noice").api.status.command.has()
            end,
            color = { fg = colors["gnohj_color04"] },
          },
          {
            get_file_permissions,
            cond = function()
              return vim.bo.filetype == "sh" and vim.fn.expand("%:p") ~= ""
            end,
            color = function()
              local f_path = vim.fn.expand("%:p")
              local permissions = f_path and vim.fn.getfperm(f_path) or ""
              local owner_permissions = permissions:sub(1, 3)
              local fg_color = (owner_permissions == "rwx")
                  and colors["gnohj_color02"]
                or colors["gnohj_color11"]
              return { fg = fg_color, gui = "bold" }
            end,
          },

          { "encoding", color = { fg = colors["gnohj_color03"] } },
          { "filetype" },
        },
        lualine_y = {
          -- {
          --   "progress",
          --   color = {
          --     fg = colors["gnohj_color04"],
          --     bg = "NONE",
          --   },
          --   separator = { left = "", right = "" },
          --   padding = { left = 0, right = 1 },
          -- },
        },
        lualine_z = {
          {
            "location",
            -- padding = { left = 1, right = 0 },
            color = {
              fg = colors["gnohj_color10"],
              bg = colors["gnohj_color04"],
            },
            separator = { left = "", right = "" },
          },
        },
      },
      -- winbar = {
      --   lualine_b = {
      --     {
      --       file_path,
      --       color = { fg = colors["gnohj_color03"], bg = "NONE", gui = "bold" },
      --     },
      --   },
      -- },
      -- inactive_winbar = {
      --   lualine_b = {
      --     {
      --       file_path,
      --       color = {
      --         fg = colors["gnohj_color09"],
      --         bg = "NONE",
      --         gui = "italic",
      --       },
      --     },
      --   },
      -- },
    }
  end,
}
