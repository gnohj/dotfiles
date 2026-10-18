local colors = require("config.colors")

local function buffer_count()
  local buffers = vim.fn.getbufinfo({ buflisted = 1 })
  return "(" .. tostring(#buffers) .. ")"
end
local function buffer_count_with_unsaved()
  local unsaved_count = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
      unsaved_count = unsaved_count + 1
    end
  end

  if unsaved_count > 0 then
    return tostring(unsaved_count)
  else
    return ""
  end
end

local function current_buffer_unsaved_dot()
  if vim.bo[0].modified then
    local count = buffer_count_with_unsaved()

    return "🚨" .. count
  else
    return ""
  end
end

local function get_file_permissions()
  if vim.bo.filetype ~= "sh" then
    return ""
  end
  local file_path = vim.fn.expand("%:p")
  return file_path and vim.fn.getfperm(file_path) or ""
end

-- Count active-tab CodeDiff navigation hunks; empty output hides the component.
local function codediff_hunk_count()
  local lifecycle = package.loaded["codediff.ui.lifecycle"]
  if not lifecycle then
    return ""
  end
  local session = lifecycle.get_session(vim.api.nvim_get_current_tabpage())
  if not session or not session.stored_diff_result then
    return ""
  end
  local changes = session.stored_diff_result.changes
  if not changes or #changes == 0 then
    return ""
  end
  -- Explorer paths are repo-relative; deletes/renames may need original_path.
  local path = session.modified_path or session.original_path
  local hunks = "󰊢 " .. tostring(#changes) .. " hunks"
  if path and path ~= "" then
    return "󰈔 " .. path .. " │ " .. hunks
  end
  return hunks
end

return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  enabled = true,
  opts = function(_, opts)
    local lazy_status = require("lazy.status") -- to configure lazy pending updates count
    local icons = require("lazyvim.config").icons

    -- If in tmux or herdr, show minimal statusline with unsaved buffer indicator and lazy updates on the right
    if vim.env.TMUX or vim.env.HERDR_SOCKET_PATH then
      return {
        options = {
          component_separators = "",
          section_separators = "",
          theme = "auto",
        },
        sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = {},
          lualine_x = {
            {
              codediff_hunk_count,
              color = { fg = colors["gnohj_color04"], gui = "bold" },
            },
            {
              current_buffer_unsaved_dot,
              color = { fg = colors["gnohj_color11"] },
            },
            {
              lazy_status.updates,
              cond = lazy_status.has_updates,
              color = { fg = colors["gnohj_color06"] },
            },
          },
          lualine_y = {},
          lualine_z = {},
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = {},
          lualine_x = {},
          lualine_y = {},
          lualine_z = {},
        },
      }
    end

    -- Full lualine configuration when not in tmux
    table.remove(opts.sections.lualine_c, 1)
    table.remove(opts.sections.lualine_c, 2)
    table.remove(opts.sections.lualine_c, 3)
    table.remove(opts.sections.lualine_c, #opts.sections.lualine_c)
    table.insert(opts.sections.lualine_c, {
      "filename",
      path = 3,
    })

    return {

      options = {
        -- component_separators = { left = ")", right = "(" },
        section_separators = { left = "", right = "" },
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
          -- Optional branch: bold color24, optional color08 bg, no separators.
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
          -- Optional diff: icons.git signs with vim.b.gitsigns_status_dict counts.
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
            codediff_hunk_count,
            color = { fg = colors["gnohj_color04"], gui = "bold" },
          },
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
          -- Optional progress: color04 on NONE, no separators, padding 0/1.
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
      -- Optional lualine_b file_path winbar: bold color03, inactive italic color09; bg NONE.
    }
  end,
}
