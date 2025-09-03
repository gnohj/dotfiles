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
        -- Core background and foreground
        global_colors.bg = colors["gnohj_color10"]
        global_colors.bg_dark = colors["gnohj_color07"]
          or colors["gnohj_color10"]
        global_colors.bg_dark1 = colors["gnohj_color28"]
          or colors["gnohj_color07"]
          or colors["gnohj_color10"]
        global_colors.bg_highlight = transparent and global_colors.none
          or colors["gnohj_color17"]
        global_colors.bg_float = transparent and global_colors.none
          or colors["gnohj_color07"]
          or global_colors.bg_float
        global_colors.bg_popup = colors["gnohj_color07"]
          or colors["gnohj_color17"]
        global_colors.bg_search = colors["gnohj_color39"]
          or colors["gnohj_color04"]
        global_colors.bg_sidebar = transparent and global_colors.none
          or colors["gnohj_color07"]
          or global_colors.bg_sidebar
        global_colors.bg_statusline = transparent and global_colors.none
          or colors["gnohj_color10"]
        global_colors.bg_visual = colors["gnohj_color13"]
        global_colors.fg = colors["gnohj_color14"]
        global_colors.fg_dark = colors["gnohj_color09"]
        global_colors.fg_float = colors["gnohj_color14"]
        global_colors.fg_gutter = colors["gnohj_color13"]
        global_colors.fg_sidebar = colors["gnohj_color09"]
          or colors["gnohj_color13"]

        -- Border colors
        global_colors.border = colors["gnohj_color13"]
        global_colors.border_highlight = colors["gnohj_color42"]
          or colors["gnohj_color03"]
        global_colors.black = colors["gnohj_color10"]

        -- blue variants (using new evergarden blue structure with fallbacks)
        global_colors.blue = colors["gnohj_color04"]
        global_colors.blue0 = colors["gnohj_color39"] or colors["gnohj_color04"] -- darker blue
        global_colors.blue1 = colors["gnohj_color42"] or colors["gnohj_color03"] -- bright blue
        global_colors.blue2 = colors["gnohj_color43"] or colors["gnohj_color03"] -- cyan-blue
        global_colors.blue5 = colors["gnohj_color44"] or colors["gnohj_color04"] -- light blue
        global_colors.blue6 = colors["gnohj_color45"] or colors["gnohj_color03"] -- very light blue
        global_colors.blue7 = colors["gnohj_color46"] or colors["gnohj_color13"] -- dark blue-gray

        -- Grays and darks
        global_colors.comment = colors["gnohj_color09"]
        global_colors.dark3 = colors["gnohj_color47"] or colors["gnohj_color13"] -- medium gray
        global_colors.dark5 = colors["gnohj_color48"] or colors["gnohj_color09"] -- lighter gray
        global_colors.terminal_black = colors["gnohj_color53"]
          or colors["gnohj_color13"]

        -- Core colors
        global_colors.red = colors["gnohj_color11"]
        global_colors.red1 = colors["gnohj_color31"] or colors["gnohj_color11"] -- darker red
        global_colors.orange = colors["gnohj_color06"]
        global_colors.yellow = colors["gnohj_color41"]
          or colors["gnohj_color05"]
        global_colors.green = colors["gnohj_color40"] or colors["gnohj_color02"]
        global_colors.green1 = colors["gnohj_color50"]
          or colors["gnohj_color02"] -- lime variant
        global_colors.green2 = colors["gnohj_color51"]
          or colors["gnohj_color03"] -- aqua variant
        global_colors.cyan = colors["gnohj_color03"]
        global_colors.purple = colors["gnohj_color04"]
        global_colors.magenta = colors["gnohj_color01"]
        global_colors.magenta2 = colors["gnohj_color52"]
          or colors["gnohj_color01"] -- purple variant
        global_colors.teal = colors["gnohj_color49"] or colors["gnohj_color03"] -- darker snow

        -- Status colors
        global_colors.error = colors["gnohj_color11"]
        global_colors.warning = colors["gnohj_color06"]
        global_colors.info = colors["gnohj_color43"] or colors["gnohj_color04"]
        global_colors.hint = colors["gnohj_color49"] or colors["gnohj_color03"]
        global_colors.todo = colors["gnohj_color04"]

        -- Diff colors
        global_colors.diff = {
          add = colors["gnohj_color30"] or "#334330",
          change = colors["gnohj_color28"] or "#202325",
          delete = colors["gnohj_color32"] or "#433030",
          text = colors["gnohj_color46"] or colors["gnohj_color13"],
        }

        -- Terminal colors
        global_colors.terminal = {
          black = colors["gnohj_color10"],
          black_bright = colors["gnohj_color53"] or colors["gnohj_color13"],
          blue = colors["gnohj_color04"],
          blue_bright = colors["gnohj_color44"] or colors["gnohj_color04"],
          cyan = colors["gnohj_color03"],
          cyan_bright = colors["gnohj_color45"] or colors["gnohj_color03"],
          green = colors["gnohj_color02"],
          green_bright = colors["gnohj_color50"] or colors["gnohj_color02"],
          magenta = colors["gnohj_color01"],
          magenta_bright = colors["gnohj_color52"] or colors["gnohj_color01"],
          red = colors["gnohj_color11"],
          red_bright = colors["gnohj_color31"] or colors["gnohj_color11"],
          white = colors["gnohj_color09"],
          white_bright = colors["gnohj_color14"],
          yellow = colors["gnohj_color05"],
          yellow_bright = colors["gnohj_color41"] or colors["gnohj_color05"],
        }

        -- Rainbow colors for various plugins
        global_colors.rainbow = {
          colors["gnohj_color04"], -- blue
          colors["gnohj_color41"] or colors["gnohj_color05"], -- yellow
          colors["gnohj_color40"] or colors["gnohj_color02"], -- green
          colors["gnohj_color49"] or colors["gnohj_color03"], -- teal
          colors["gnohj_color01"], -- magenta
          colors["gnohj_color52"] or colors["gnohj_color01"], -- purple
          colors["gnohj_color06"], -- orange
          colors["gnohj_color11"], -- red
        }

        -- Git colors
        global_colors.git = {
          add = colors["gnohj_color02"],
          change = colors["gnohj_color03"],
          delete = colors["gnohj_color11"],
          ignore = colors["gnohj_color47"] or colors["gnohj_color13"],
        }
        global_colors.gitSigns = {
          change = colors["gnohj_color03"],
          add = colors["gnohj_color02"],
          delete = colors["gnohj_color11"],
        }

        -- Additional functional colors (keeping existing)
        global_colors.dark_cyan = colors["gnohj_color12"]
        global_colors.dark_yellow = colors["gnohj_color05"]
        global_colors.dark_green = colors["gnohj_color02"]
        global_colors.pink = colors["gnohj_color01"]
        global_colors.menu = colors["gnohj_color10"]
        global_colors.visual = colors["gnohj_color16"]
        global_colors.gutter_fg = colors["gnohj_color16"]
        global_colors.nontext = colors["gnohj_color16"]
        global_colors.white = colors["gnohj_color14"]
        global_colors.selection = colors["gnohj_color16"]
        global_colors.none = "NONE"
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

        -- Core syntax elements
        hl["@variable"] = { fg = colors["gnohj_color14"] } -- normal text color for variables
        hl.Function = { fg = colors["gnohj_color04"] } -- blue for functions
        hl.Type = { fg = colors["gnohj_color02"] } -- green for types (keep consistent with @type)
        hl["@function.method.call"] = { fg = colors["gnohj_color04"] } -- method calls
        hl["@keyword"] = { fg = colors["gnohj_color04"] } -- keywords like const, let, if
        hl["@keyword.function"] = { fg = colors["gnohj_color04"] } -- function keyword
        hl["@keyword.return"] = { fg = colors["gnohj_color04"] } -- return keyword
        hl["@constant"] = { fg = colors["gnohj_color06"] } -- constants
        hl["@constant.builtin"] = { fg = colors["gnohj_color06"] } -- true, false, null
        hl["@string"] = { fg = colors["gnohj_color05"] } -- string literals
        hl["@number"] = { fg = colors["gnohj_color06"] } -- numbers
        hl["@operator"] = { fg = colors["gnohj_color04"] } -- +, -, =, etc.
        hl["@module.builtin"] = { fg = colors["gnohj_color06"] } -- built-in modules like 'react', 'node:fs'
        hl["@module"] = { fg = colors["gnohj_color04"] } -- regular modules

        -- Object members and properties
        hl["@variable.member"] = { fg = colors["gnohj_color03"] } -- cyan for object members
        hl["@property"] = { fg = colors["gnohj_color03"] } -- cyan for properties (consistent)

        -- Types and constructors
        hl["@type"] = { fg = colors["gnohj_color02"] } -- green for types
        hl["@constructor"] = { fg = colors["gnohj_color02"] } -- green for constructors (consistent with types)

        -- Special/built-in elements
        hl["@type.builtin"] = { fg = colors["gnohj_color06"] } -- orange for built-in types (distinct)
        hl.Special = { fg = colors["gnohj_color06"] } -- orange for special/built-in methods

        hl.MiniFilesNormal = { bg = colors["gnohj_color10"] }
        hl.MiniFilesBorder = { fg = colors["gnohj_color04"] }
        hl.MiniFilesTitle = { fg = colors["gnohj_color04"] }
        hl.MiniFilesTitleFocused = { fg = colors["gnohj_color02"], bold = true }

        hl.MiniFilesDirectory = { fg = colors["gnohj_color04"] } -- Folder names
        hl.MiniFilesFile = { fg = colors["gnohj_color14"] } -- Regular file names

        -- Cursor and selection
        hl.MiniFilesCursorLine = { bg = colors["gnohj_color16"] } -- Current line highlight

        -- Copilot ghost text
        hl.CopilotSuggestion = { fg = colors["gnohj_color09"], italic = true }
        hl.CopilotAnnotation = { fg = colors["gnohj_color09"], italic = true }
        hl.Comment = {
          fg = colors["gnohj_color54"] or colors["gnohj_color09"],
          italic = true,
        }

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

        hl.DiagnosticError = { fg = colors["gnohj_color11"] }
        hl.DiagnosticWarn = { fg = colors["gnohj_color06"] } -- use orange instead of gnohj_color12
        hl.DiagnosticInfo = { fg = colors["gnohj_color04"] } -- use blue instead of cyan
        hl.DiagnosticHint = { fg = colors["gnohj_color09"] } -- use comment color
        DiagnosticInfo = { fg = colors["gnohj_color04"] }
        DiagnosticHint = { fg = colors["gnohj_color09"] }
        DiagnosticWarn = { fg = colors["gnohj_color06"] }
        DiagnosticOk = { fg = colors["gnohj_color04"] }
        DiagnosticError = { fg = colors["gnohj_color11"] }

        hl.GitSignsAdd = { fg = colors["gnohj_color02"] }
        hl.GitSignsChange = { fg = colors["gnohj_color03"] }
        hl.GitSignsDelete = { fg = colors["gnohj_color11"] }

        -- Dropbar git signs colors
        hl.Added = { fg = colors["gnohj_color02"] }
        hl.Changed = { fg = colors["gnohj_color03"] }
        hl.Removed = { fg = colors["gnohj_color11"] }

        -- Dropbar path colors
        hl.DropBarIconKindFolder = { fg = colors["gnohj_color09"] }
        hl.DropBarKindFolder = { fg = colors["gnohj_color04"] }
        hl.DropBarKindFile = { fg = colors["gnohj_color06"] }
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
