if vim.g.vscode then
  return {}
end

local colors = require("config.colors")

-- set in ~/.config/colorscheme/colorscheme-vars.sh
-- set in ~/.config/nvim/init.lua
local transparent = vim.g.theme_transparent == "transparent"

return {
  "folke/tokyonight.nvim",
  lazy = true,
  config = function()
    require("tokyonight").setup({
      style = "storm",
      transparent = transparent,
      styles = {
        sidebars = transparent and "transparent" or "dark",
        floats = transparent and "transparent" or "dark",
      },
      on_colors = function(global_colors)
        global_colors.bg = colors["gnohj_color10"]
        -- global_colors.bg_dark = colors["gnohj_color13"]
        global_colors.bg_float = transparent and global_colors.none
          or global_colors.bg_float
        global_colors.bg_highlight = transparent and global_colors.none
          or colors["gnohj_color17"]
        -- global_colors.bg_popup = bg_dark
        -- global_colors.bg_search = bg_search
        global_colors.bg_sidebar = transparent and global_colors.none
          or global_colors.bg_sidebar
        global_colors.bg_statusline = transparent and global_colors.none
          or colors["gnohj_color10"]
        global_colors.bg_visual = colors["gnohj_color16"]
        global_colors.border = colors["gnohj_color13"]
        global_colors.fg = colors["gnohj_color14"]
        global_colors.fg_dark = colors["gnohj_color09"]
        global_colors.fg_float = colors["gnohj_color14"]
        global_colors.fg_gutter = colors["gnohj_color13"]
        global_colors.fg_sidebar = colors["gnohj_color13"]
        global_colors.red = colors["gnohj_color11"]
        global_colors.orange = colors["gnohj_color06"]
        global_colors.yellow = colors["gnohj_color41"]
          or colors["gnohj_color05"]
        global_colors.green = colors["gnohj_color40"] or colors["gnohj_color02"]
        global_colors.purple = colors["gnohj_color04"]
        global_colors.cyan = colors["gnohj_color03"]
        global_colors.dark_cyan = colors["gnohj_color12"]
        global_colors.terminal_black = colors["gnohj_color13"]
        global_colors.dark3 = colors["gnohj_color13"]
        global_colors.dark5 = colors["gnohj_color13"]
        global_colors.magenta = colors["gnohj_color01"]
        global_colors.magenta2 = colors["gnohj_color01"]
        global_colors.magenta3 = colors["gnohj_color01"]
        global_colors.dark_yellow = colors["gnohj_color05"]
        global_colors.dark_green = colors["gnohj_color02"]
        global_colors.pink = colors["gnohj_color01"]
        global_colors.bright_red = colors["gnohj_color08"]
        global_colors.bright_green = colors["gnohj_color02"]
        global_colors.bright_yellow = colors["gnohj_color05"]
        global_colors.bright_blue = colors["gnohj_color04"]
        global_colors.bright_magenta = colors["gnohj_color01"]
        global_colors.bright_cyan = colors["gnohj_color03"]
        global_colors.bright_white = colors["gnohj_color14"]
        global_colors.menu = colors["gnohj_color10"]
        global_colors.visual = colors["gnohj_color16"]
        global_colors.gutter_fg = colors["gnohj_color16"]
        global_colors.nontext = colors["gnohj_color16"]
        global_colors.white = colors["gnohj_color14"]
        global_colors.black = colors["gnohj_color10"]
        global_colors.selection = colors["gnohj_color16"]
        global_colors.comment = colors["gnohj_color09"]
        global_colors.gitSigns = {
          change = colors["gnohj_color03"],
          add = colors["gnohj_color02"],
          delete = colors["gnohj_color11"],
        }
      end,
      on_highlights = function(hl, hl_colors)
        -- Change the spell underline color
        SpellBad = {
          sp = colors["gnohj_color11"],
          undercurl = true,
          bold = true,
          italic = true,
        }
        SpellCap = {
          sp = colors["gnohj_color12"],
          undercurl = true,
          bold = true,
          italic = true,
        }
        SpellLocal = {
          sp = colors["gnohj_color12"],
          undercurl = true,
          bold = true,
          italic = true,
        }
        SpellRare = {
          sp = colors["gnohj_color04"],
          undercurl = true,
          bold = true,
          italic = true,
        }

        -- Codeblocks for the render-markdown plugin
        -- RenderMarkdownCode = { bg = colors["gnohj_color02"] }

        hl.Type = { fg = colors["gnohj_color06"] }
        hl["@variable"] = { fg = colors["gnohj_color14"] }
        hl["@type"] = { fg = colors["gnohj_color02"] }
        hl.Function = { fg = colors["gnohj_color06"] }

        hl.MiniFilesNormal = { bg = colors["gnohj_color10"] }
        hl.MiniFilesBorder = { fg = colors["gnohj_color13"] }
        hl.MiniFilesTitle = { fg = colors["gnohj_color04"] }
        hl.MiniFilesTitleFocused = { fg = colors["gnohj_color02"], bold = true }

        hl.MiniFilesDirectory = { fg = colors["gnohj_color04"] } -- Folder names
        hl.MiniFilesFile = { fg = colors["gnohj_color14"] } -- Regular file names

        -- Cursor and selection
        hl.MiniFilesCursorLine = { bg = colors["gnohj_color16"] } -- Current line highlight

        -- Copilot ghost text
        hl.CopilotSuggestion = { fg = colors["gnohj_color09"], italic = true }
        hl.CopilotAnnotation = { fg = colors["gnohj_color09"], italic = true }
        hl.Comment = { fg = colors["gnohj_color09"], italic = true }

        -- Diffview
        hl.DiffChange =
          { fg = colors["gnohj_color27"], bg = colors["gnohj_color28"] }
        hl.DiffAdd =
          { fg = colors["gnohj_color29"], bg = colors["gnohj_color30"] }
        hl.DiffDelete =
          { fg = colors["gnohj_color31"], bg = colors["gnohj_color32"] }
        hl.DiffText = {
          fg = colors["gnohj_color33"],
          bg = colors["gnohj_color34"],
          bold = true,
        }

        hl.DiffviewFolderSign = { fg = colors["gnohj_color35"] }
        hl.DiffviewNonText = { fg = hl_colors.comment }
        hl.diffAdded = { fg = colors["gnohj_color36"], bold = true }
        hl.diffChanged = { fg = colors["gnohj_color37"], bold = true }
        hl.diffRemoved = { fg = colors["gnohj_color38"], bold = true }

        DiagnosticInfo = { fg = colors["gnohj_color03"] }
        DiagnosticHint = { fg = colors["gnohj_color02"] }
        DiagnosticWarn = { fg = colors["gnohj_color12"] }
        DiagnosticOk = { fg = colors["gnohj_color04"] }
        DiagnosticError = { fg = colors["gnohj_color11"] }
        -- RenderMarkdownQuote = { fg = colors["gnohj_color12"] }
        -- hl.RenderMarkdownLink = { fg = hl_colors.blue, sp = "NONE", undercurl = false }

        -- Noice
        -- Default/generic elements
        hl.NoiceCmdlinePopupBorder = { fg = hl_colors.border }
        hl.NoiceCmdlinePopupTitle = { fg = colors["gnohj_color04"] }
        hl.NoiceCmdlineIcon = { fg = colors["gnohj_color04"] }

        -- Filter-specific elements
        hl.NoiceCmdlinePopupBorderFilter = { fg = colors["gnohj_color02"] }
        hl.NoiceCmdlineIconFilter = { fg = colors["gnohj_color02"] }
        hl.NoiceCmdlinePopupTitleFilter = { fg = colors["gnohj_color02"] }

        -- Command line elements
        hl.NoiceCmdlineIconCmdline = { fg = colors["gnohj_color04"] }
        hl.NoiceCmdlinePopupBorderCmdline = { fg = colors["gnohj_color04"] }
        hl.NoiceCmdlinePopupTitleCmdline = { fg = colors["gnohj_color04"] }

        -- Search elements
        hl.NoiceCmdlineIconSearch = { fg = colors["gnohj_color02"] }
        hl.NoiceCmdlinePopupBorderSearch = { fg = colors["gnohj_color02"] }
        hl.NoiceCmdlinePopupTitleSearch = { fg = colors["gnohj_color02"] }

        -- Lua elements
        hl.NoiceCmdlineIconLua = { fg = colors["gnohj_color05"] }
        hl.NoiceCmdlinePopupBorderLua = { fg = colors["gnohj_color05"] }
        hl.NoiceCmdlinePopupTitleLua = { fg = colors["gnohj_color05"] }

        -- Help elements
        hl.NoiceCmdlineIconHelp = { fg = colors["gnohj_color06"] }
        hl.NoiceCmdlinePopupBorderHelp = { fg = colors["gnohj_color06"] }
        hl.NoiceCmdlinePopupTitleHelp = { fg = colors["gnohj_color06"] }

        -- Input elements
        hl.NoiceCmdlineIconInput = { fg = colors["gnohj_color04"] }
        hl.NoiceCmdlinePopupBorderInput = { fg = colors["gnohj_color04"] }
        hl.NoiceCmdlinePopupTitleInput = { fg = colors["gnohj_color04"] }

        -- Calculator elements
        hl.NoiceCmdlineIconCalculator = { fg = colors["gnohj_color04"] }
        hl.NoiceCmdlinePopupBorderCalculator = { fg = colors["gnohj_color04"] }
        hl.NoiceCmdlinePopupTitleCalculator = { fg = colors["gnohj_color04"] }

        -- Completion and mini elements
        hl.NoiceCompletionItemKindDefault = { fg = colors["gnohj_color04"] }
        hl.NoiceMini = { bg = hl_colors.bg_highlight, fg = hl_colors.fg }
      end,
    })
  end,
}
