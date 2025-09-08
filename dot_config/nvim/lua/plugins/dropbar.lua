if vim.g.vscode then
  return {}
end

local function get_gitsigns_stats(buf)
  local buffer = buf or vim.api.nvim_get_current_buf()
  local gitsigns = vim.b[buffer].gitsigns_status_dict
  if gitsigns then
    return {
      added = gitsigns.added,
      modified = gitsigns.changed,
      removed = gitsigns.removed,
    }
  end
end

return {
  "Bekaboo/dropbar.nvim",
  enabled = true,

  event = "BufEnter",
  name = "dropbar",
  config = function()
    local bar = require("dropbar.bar")
    local colors = require("config.colors")

    -- Create custom highlight groups for mode indicator with fg color only
    vim.api.nvim_set_hl(0, "DropbarModeNormal", {
      fg = colors["gnohj_color03"],
      bold = true,
    })
    vim.api.nvim_set_hl(0, "DropbarModeInsert", {
      fg = colors["gnohj_color02"],
      bold = true,
    })
    vim.api.nvim_set_hl(0, "DropbarModeVisual", {
      fg = colors["gnohj_color04"],
      bold = true,
    })
    vim.api.nvim_set_hl(0, "DropbarModeCommand", {
      fg = colors["gnohj_color05"],
      bold = true,
    })
    vim.api.nvim_set_hl(0, "DropbarModeReplace", {
      fg = colors["gnohj_color11"],
      bold = true,
    })

    -- Custom highlight for dimmed path
    vim.api.nvim_set_hl(0, "DropbarPathDim", {
      fg = colors["gnohj_color08"],
      italic = true,
    })

    -- Mode indicator source
    local mode_source = {
      get_symbols = function(buf, win, cursor)
        local mode_map = {
          ["n"] = "N",
          ["no"] = "N",
          ["nov"] = "N",
          ["noV"] = "N",
          ["no\22"] = "N",
          ["niI"] = "N",
          ["niR"] = "N",
          ["niV"] = "N",
          ["nt"] = "N",
          ["ntT"] = "N",
          ["v"] = "V",
          ["vs"] = "V",
          ["V"] = "V",
          ["Vs"] = "V",
          ["\22"] = "V",
          ["\22s"] = "V",
          ["s"] = "S",
          ["S"] = "S",
          ["\19"] = "S",
          ["i"] = "I",
          ["ic"] = "I",
          ["ix"] = "I",
          ["R"] = "R",
          ["Rc"] = "R",
          ["Rx"] = "R",
          ["Rv"] = "R",
          ["Rvc"] = "R",
          ["Rvx"] = "R",
          ["c"] = "C",
          ["cv"] = "C",
          ["ce"] = "C",
          ["r"] = "R",
          ["rm"] = "R",
          ["r?"] = "R",
          ["!"] = "!",
          ["t"] = "T",
        }

        local mode = vim.api.nvim_get_mode().mode
        local mode_text = mode_map[mode] or mode:upper():sub(1, 1)
        local mode_char = mode:sub(1, 1):lower()

        -- Determine highlight group based on mode (matching lualine colors)
        local hl_group = "DropbarModeNormal"
        if mode_char == "i" then
          hl_group = "DropbarModeInsert"
        elseif mode_char == "v" then
          hl_group = "DropbarModeVisual"
        elseif mode_char == "c" then
          hl_group = "DropbarModeCommand"
        elseif mode_char == "r" then
          hl_group = "DropbarModeReplace"
        end

        return {
          bar.dropbar_symbol_t:new({
            icon = "",
            icon_hl = "",
            name = "[" .. mode_text .. "]",
            name_hl = hl_group,
          }),
        }
      end,
    }

    -- Diagnostics source
    local diagnostics_source = {
      get_symbols = function(buf, win, cursor)
        local diagnostics = vim.diagnostic.get(buf)
        if not diagnostics or #diagnostics == 0 then
          return {}
        end

        local counts = { 0, 0, 0, 0 } -- Error, Warn, Info, Hint
        for _, diagnostic in ipairs(diagnostics) do
          counts[diagnostic.severity] = counts[diagnostic.severity] + 1
        end

        local symbols = {}
        local icons = require("lazyvim.config").icons.diagnostics

        -- Add diagnostics counts with proper colors
        if counts[1] > 0 then -- Error
          table.insert(
            symbols,
            bar.dropbar_symbol_t:new({
              icon = icons.Error,
              icon_hl = "DiagnosticError",
              name = tostring(counts[1]),
              name_hl = "DiagnosticError",
            })
          )
        end

        if counts[2] > 0 then -- Warning
          table.insert(
            symbols,
            bar.dropbar_symbol_t:new({
              icon = icons.Warn,
              icon_hl = "DiagnosticWarn",
              name = tostring(counts[2]),
              name_hl = "DiagnosticWarn",
            })
          )
        end

        if counts[3] > 0 then -- Info
          table.insert(
            symbols,
            bar.dropbar_symbol_t:new({
              icon = icons.Info,
              icon_hl = "DiagnosticInfo",
              name = tostring(counts[3]),
              name_hl = "DiagnosticInfo",
            })
          )
        end

        if counts[4] > 0 then -- Hint
          table.insert(
            symbols,
            bar.dropbar_symbol_t:new({
              icon = icons.Hint,
              icon_hl = "DiagnosticHint",
              name = tostring(counts[4]),
              name_hl = "DiagnosticHint",
            })
          )
        end

        return symbols
      end,
    }

    local gitsigns_stats = {
      get_symbols = function(buf, win, cursor)
        local gitsigns_stats = get_gitsigns_stats(buf)
        if not gitsigns_stats then
          return {}
        end

        local stats = {}

        if gitsigns_stats.added and gitsigns_stats.added > 0 then
          table.insert(
            stats,
            bar.dropbar_symbol_t:new({
              icon = " ",
              icon_hl = "Added",
              name = tostring(gitsigns_stats.added),
              name_hl = "Added",
            })
          )
        end

        if gitsigns_stats.removed and gitsigns_stats.removed > 0 then
          table.insert(
            stats,
            bar.dropbar_symbol_t:new({
              icon = " ",
              icon_hl = "Removed",
              name = tostring(gitsigns_stats.removed),
              name_hl = "Removed",
            })
          )
        end

        if gitsigns_stats.modified and gitsigns_stats.modified > 0 then
          table.insert(
            stats,
            bar.dropbar_symbol_t:new({
              icon = " ",
              icon_hl = "Changed",
              name = tostring(gitsigns_stats.modified),
              name_hl = "Changed",
            })
          )
        end

        return stats
      end,
    }

    ---@class dropbar_source_t
    require("dropbar").setup({
      icons = {
        ui = {
          bar = {
            separator = " ", -- Keep space separator between sources
            extends = "…",
          },
        },
      },
      bar = {
        hover = false, -- Disable highlighting symbol under cursor
        padding = { left = 0, right = 1 }, -- Remove left padding to align with left edge
        truncate = true,
        sources = function(buf, _)
          local sources = require("dropbar.sources")
          local utils = require("dropbar.utils")

          -- Custom path source that shows filename first, then path (dimmed, no icons)
          local custom_path = {
            get_symbols = function(buff, win, cursor)
              -- Get the full file path
              local file_path = vim.api.nvim_buf_get_name(buff)
              if file_path == "" then
                return {}
              end

              -- Get home directory
              local home = vim.fn.expand("~")

              -- Expand file_path if it starts with ~
              if file_path:sub(1, 1) == "~" then
                file_path = home .. file_path:sub(2)
              end

              -- Check if path is in home directory
              local is_home_path = file_path:find("^" .. vim.pesc(home))

              -- Build symbols
              local bar = require("dropbar.bar")
              local symbols = {}

              -- Get the default path symbols for file icon
              local default_path_symbols =
                sources.path.get_symbols(buff, win, cursor)
              local file_symbol = default_path_symbols
                  and default_path_symbols[#default_path_symbols]
                or nil

              if is_home_path then
                -- For home paths: show filename first, then path from ~
                local relative_path = file_path:gsub("^" .. vim.pesc(home), "")
                local components = {}

                for component in relative_path:gmatch("[^/]+") do
                  table.insert(components, component)
                end

                if #components > 0 then
                  -- Filename with appropriate icon (first)
                  if file_symbol then
                    table.insert(symbols, file_symbol)
                  else
                    -- Fallback if no symbol available
                    table.insert(
                      symbols,
                      bar.dropbar_symbol_t:new({
                        icon = "",
                        icon_hl = "",
                        name = components[#components],
                        name_hl = "DropBarKindFile",
                      })
                    )
                  end

                  -- Build the folder path string from home (dimmed, no icon)
                  if #components > 1 then
                    local folder_path = "~"
                    -- Add all folders except the filename
                    for i = 1, #components - 1 do
                      folder_path = folder_path .. "/" .. components[i]
                    end

                    -- Path without icon, dimmed
                    table.insert(
                      symbols,
                      bar.dropbar_symbol_t:new({
                        icon = "",
                        icon_hl = "",
                        name = folder_path,
                        name_hl = "DropbarPathDim",
                      })
                    )
                  end
                end
              else
                -- For paths outside home: show filename first, then full path
                local components = {}
                for component in file_path:gmatch("[^/]+") do
                  table.insert(components, component)
                end

                if #components > 0 then
                  -- Filename with appropriate icon (first)
                  if file_symbol then
                    table.insert(symbols, file_symbol)
                  else
                    -- Fallback if no symbol available
                    table.insert(
                      symbols,
                      bar.dropbar_symbol_t:new({
                        icon = "",
                        icon_hl = "",
                        name = components[#components],
                        name_hl = "DropBarKindFile",
                      })
                    )
                  end

                  -- Build full path except filename (dimmed, no icon)
                  if #components > 1 then
                    local folder_path = ""
                    if file_path:sub(1, 1) == "/" then
                      folder_path = "/"
                    end

                    for i = 1, #components - 1 do
                      if i > 1 or folder_path ~= "/" then
                        folder_path = folder_path .. "/"
                      end
                      folder_path = folder_path .. components[i]
                    end

                    -- Path without icon, dimmed
                    if folder_path ~= "" then
                      table.insert(
                        symbols,
                        bar.dropbar_symbol_t:new({
                          icon = "",
                          icon_hl = "",
                          name = folder_path,
                          name_hl = "DropbarPathDim",
                        })
                      )
                    end
                  end
                end
              end

              return symbols
            end,
          }

          return { mode_source, custom_path, diagnostics_source, gitsigns_stats }
        end,
        -- Enable dropbar for all file types
        enable = function(buf, win, _)
          if
            not vim.api.nvim_buf_is_valid(buf)
            or not vim.api.nvim_win_is_valid(win)
            or vim.fn.win_gettype(win) ~= ""
            or vim.wo[win].winbar ~= ""
            or vim.bo[buf].ft == "help"
          then
            return false
          end
          -- Check file size to avoid enabling for very large files
          local stat = vim.uv.fs_stat(vim.api.nvim_buf_get_name(buf))
          if stat and stat.size > 1024 * 1024 then
            return false
          end
          -- Enable for all other files
          return true
        end,
      },
      sources = {
        path = {
          max_depth = 3, -- Show only last 3 path components
          relative_to = "cwd", -- Show relative to current working directory
        },
      },
    })

    -- Don't override fillchars here, let options.lua handle it
    vim.opt.scrolloff = 3 -- Minimum lines to keep above/below cursor
  end,
}
