if vim.g.vscode then
  return {}
end

-- Custom component to display buffer count
local function buffer_count()
  local buffers = vim.fn.getbufinfo({ buflisted = 1 }) -- Only count listed buffers
  return "(" .. tostring(#buffers) .. ")"
end

-- Custom component to display the file path, with `~` for the home directory
local function file_path()
  local full_path = vim.fn.expand("%:p") -- Get the full file path
  return full_path:gsub(vim.fn.expand("$HOME"), "~") -- Replace $HOME with ~
end

local function unsaved_buffers()
  local unsaved = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_option(buf, "modified") then
      unsaved = true
      break
    end
  end
  return unsaved and "⚠️ Unsaved Buffers" or "" -- Display warning icon if there are unsaved buffers
end

local function current_buffer_unsaved()
  if vim.api.nvim_buf_get_option(0, "modified") then
    return "" -- A red circle (use any symbol you prefer)
  else
    return "" -- No symbol if there are no unsaved changes
  end
end

return {
  "nvim-lualine/lualine.nvim",
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
    local colors = {
      blue = "#65D1FF",
      green = "#3EFFDC",
      violet = "#FF61EF",
      yellow = "#FFDA7B",
      red = "#FF4A4A",
      fg = "#c3ccdc",
      bg = "#112638",
      inactive_bg = "#2c3043",
    }
    local icons = require("lazyvim.config").icons
    local Util = require("lazyvim.util")

    return {

      options = {
        section_separators = { left = " ", right = " " }, -- Remove arrows
        theme = {
          normal = {
            a = { bg = colors.blue, fg = colors.bg, gui = "bold" },
          },
          insert = {
            a = { bg = colors.green, fg = colors.bg, gui = "bold" },
          },
          visual = {
            a = { bg = colors.violet, fg = colors.bg, gui = "bold" },
          },
          command = {
            a = { bg = colors.yellow, fg = colors.bg, gui = "bold" },
          },
          replace = {
            a = { bg = colors.red, fg = colors.bg, gui = "bold" },
          },
          inactive = {
            a = { bg = colors.inactive_bg, fg = colors.semilightgray, gui = "bold" },
          },
        },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },
        lualine_c = {
          { unsaved_buffers, color = { fg = "#FF0000" } }, -- Shows in red if there are unsaved buffers
          { current_buffer_unsaved, color = { fg = "#FF0000" } }, -- Red circle for unsaved changes
          {
            "diagnostics",
            symbols = {
              error = icons.diagnostics.Error,
              warn = icons.diagnostics.Warn,
              info = icons.diagnostics.Info,
              hint = icons.diagnostics.Hint,
            },
          },
          {
            require("package-info").get_status,
            color = { fg = "#ff9e64" },
            -- color = Snacks.util.color("Statement"),
          },
        },
        lualine_x = {
          {
            lazy_status.updates,
            cond = lazy_status.has_updates,
            color = { fg = "#ff9e64" },
          },
          { "encoding" },
          { "filetype" },
          {
            "diff",
            symbols = {
              added = icons.git.added,
              modified = icons.git.modified,
              removed = icons.git.removed,
            },
            source = function()
              local gitsigns = vim.b.gitsigns_status_dict
              if gitsigns then
                return {
                  added = gitsigns.added,
                  modified = gitsigns.changed,
                  removed = gitsigns.removed,
                }
              end
            end,
          },
        },
      },
      winbar = {
        lualine_a = {
          { buffer_count, color = { fg = "#37f499", bg = "", gui = "bold" } }, -- Buffer count with color
        },
        lualine_c = {
          { file_path, color = { fg = "#04d1f9", gui = "bold" } }, -- File path with color
        },
      },
      inactive_winbar = {
        lualine_a = {
          { buffer_count, color = { fg = "#666666", gui = "italic" } }, -- Buffer count for inactive windows
        },
        lualine_c = {
          { file_path, color = { fg = "#666666", gui = "italic" } }, -- File path for inactive windows
        },
      },
    }
  end,
}
