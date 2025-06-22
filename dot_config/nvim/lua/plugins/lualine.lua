if vim.g.vscode then
  return {}
end

local colors = require("config.colors")

vim.api.nvim_set_hl(
  0,
  "CustomTeal",
  { fg = colors["gnohj_color11"], bg = colors["gnohj_color05"] }
)

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
    return "●"
  else
    return ""
  end
end

-- Custom component to display the file path, with `~` for the home directory
local function file_path()
  local full_path = vim.fn.expand("%:p") -- Get the full file path
  return full_path:gsub(vim.fn.expand("$HOME"), "  ~") -- Replace $HOME with ~
end

return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
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
        section_separators = { left = " " }, -- Remove arrows
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
          },
          insert = {
            a = {
              bg = colors["gnohj_color02"],
              fg = colors["gnohj_color10"],
              gui = "bold",
            },
          },
          visual = {
            a = {
              bg = colors["gnohj_color04"],
              fg = colors["gnohj_color10"],
              gui = "bold",
            },
          },
          command = {
            a = {
              bg = colors["gnohj_color05"],
              fg = colors["gnohj_color10"],
              gui = "bold",
            },
          },
          replace = {
            a = {
              bg = colors["gnohj_color11"],
              fg = colors["gnohj_color10"],
              gui = "bold",
            },
          },
          inactive = {
            a = {
              bg = colors["gnohj_color07"],
              fg = colors["gnohj_color13"],
              gui = "bold",
            },
          },
        },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },
        lualine_c = {
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
            current_buffer_unsaved_dot,
            color = { fg = colors["gnohj_color11"] },
          },
          {
            buffer_count_with_unsaved,
            color = { fg = colors["gnohj_color11"] },
          },
          {
            require("package-info").get_status,
            color = { fg = colors["gnohj_color11"] },
            -- color = Snacks.util.color("Statement"),
          },
        },
        lualine_x = {
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
            lazy_status.updates,
            cond = lazy_status.has_updates,
            color = { fg = colors["gnohj_color11"] },
          },
          {
            buffer_count,
            color = { fg = colors["gnohj_color04"], gui = "bold" },
          },
          {
            function()
              local cwd = vim.uv.cwd()
              local home = vim.env.HOME
              if cwd:find(home, 1, true) then
                cwd = "~" .. cwd:sub(#home + 1)
              end

              local parts = vim.split(cwd, "/")
              -- For monorepo: always show repo name + current context
              if #parts <= 3 then
                return parts[#parts]
              else
                return parts[3] .. "/.../" .. parts[#parts]
              end
            end,
            icon = "📁",
            color = { fg = colors["gnohj_color06"] },
          },
          { "encoding", color = { fg = colors["gnohj_color12"] } },
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
        -- lualine_a = {
        --   { current_buffer_unsaved, color = { fg = "", bg = "", gui = "bold" } },
        -- },
        -- lualine_x = {
        --   {
        --     buffer_count,
        --     color = { fg = colors["gnohj_color02"], gui = "bold" },
        --   },

        -- },
        lualine_b = {
          { file_path, color = { fg = colors["gnohj_color03"], gui = "bold" } },
        },
      },
      inactive_winbar = {
        -- lualine_a = {
        --   { current_buffer_unsaved, color = { fg = "", gui = "italic" } },
        -- },
        -- lualine_x = {
        --   {
        --     buffer_count,
        --     color = { fg = colors["gnohj_color09"], gui = "italic" },
        --   },
        -- },
        lualine_b = {
          {
            file_path,
            color = { fg = colors["gnohj_color09"], gui = "italic" },
          },
        },
      },
    }
  end,
}
