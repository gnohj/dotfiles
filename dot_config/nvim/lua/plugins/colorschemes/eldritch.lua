if vim.g.vscode then
  return {}
end

-- https://github.com/eldritch-theme/eldritch.nvim

local colors = require("config.colors")

return {
  "eldritch-theme/eldritch.nvim",
  lazy = true,
  name = "eldritch",
  opts = {
    transparent = true,
    styles = {
      sidebars = "transparent",
      floats = "transparent",
    },
    -- Overriding colors globally using a definitions table
    on_colors = function(global_colors)
      -- Define all color overrides in a single table
      local color_definitions = {
        -- https://github.com/eldritch-theme/eldritch.nvim/blob/master/lua/eldritch/colors.lua
        bg = colors["gnohj_color10"],
        fg = colors["gnohj_color14"],
        selection = colors["gnohj_color16"],
        comment = colors["gnohj_color09"],
        red = colors["gnohj_color08"], -- default #f16c75
        orange = colors["gnohj_color06"], -- default #f7c67f
        yellow = colors["gnohj_color05"], -- default #f1fc79
        green = colors["gnohj_color02"],
        purple = colors["gnohj_color04"], -- default #a48cf2
        cyan = colors["gnohj_color03"],
        pink = colors["gnohj_color01"], -- default #f265b5
        bright_red = colors["gnohj_color08"],
        bright_green = colors["gnohj_color02"],
        bright_yellow = colors["gnohj_color05"],
        bright_blue = colors["gnohj_color04"],
        bright_magenta = colors["gnohj_color01"],
        bright_cyan = colors["gnohj_color03"],
        bright_white = colors["gnohj_color14"],
        menu = colors["gnohj_color10"],
        visual = colors["gnohj_color16"],
        gutter_fg = colors["gnohj_color16"],
        nontext = colors["gnohj_color16"],
        white = colors["gnohj_color14"],
        black = colors["gnohj_color10"],
        git = {
          change = colors["gnohj_color03"],
          add = colors["gnohj_color02"],
          delete = colors["gnohj_color11"],
        },
        gitSigns = {
          change = colors["gnohj_color03"],
          add = colors["gnohj_color02"],
          delete = colors["gnohj_color11"],
        },
        bg_dark = colors["gnohj_color13"],
        -- Lualine line across
        bg_highlight = colors["gnohj_color17"],
        terminal_black = colors["gnohj_color13"],
        fg_dark = colors["gnohj_color14"],
        fg_gutter = colors["gnohj_color13"],
        dark3 = colors["gnohj_color13"],
        dark5 = colors["gnohj_color13"],
        bg_visual = colors["gnohj_color16"],
        dark_cyan = colors["gnohj_color03"],
        magenta = colors["gnohj_color01"],
        magenta2 = colors["gnohj_color01"],
        magenta3 = colors["gnohj_color01"],
        dark_yellow = colors["gnohj_color05"],
        dark_green = colors["gnohj_color02"],
      }

      -- Apply each color definition to global_colors
      for key, value in pairs(color_definitions) do
        global_colors[key] = value
      end
    end,

    -- This function is found in the documentation
    on_highlights = function(highlights)
      local highlight_definitions = {
        -- nvim-spectre or grug-far.nvim highlight colors
        DiffChange = { bg = colors["gnohj_color03"], fg = "black" },
        DiffDelete = { bg = colors["gnohj_color11"], fg = "black" },
        DiffAdd = { bg = colors["gnohj_color02"], fg = "black" },
        TelescopeResultsDiffDelete = { bg = colors["gnohj_color01"], fg = "black" },

        -- horizontal line that goes across where cursor is
        CursorLine = { bg = colors["gnohj_color13"] },

        -- Set cursor color, these will be called by the "guicursor" option in
        -- the options.lua file, which will be used by neovide
        Cursor = { bg = colors["gnohj_color24"] },
        lCursor = { bg = colors["gnohj_color24"] },
        CursorIM = { bg = colors["gnohj_color24"] },

        -- I do the line below to change the color of bold text
        ["@markup.strong"] = { fg = colors["gnohj_color24"], bold = true },

        -- Inline code in markdown
        ["@markup.raw.markdown_inline"] = { fg = colors["gnohj_color02"] },
        -- Background color of markdown folds
        -- Folded = { bg = colors["gnohj_color04"] },
        -- Set this to NONE when handling transparency in the terminal and not
        -- through yabai
        Folded = { bg = "NONE" },

        -- Change the spell underline color
        SpellBad = { sp = colors["gnohj_color11"], undercurl = true, bold = true, italic = true },
        SpellCap = { sp = colors["gnohj_color12"], undercurl = true, bold = true, italic = true },
        SpellLocal = { sp = colors["gnohj_color12"], undercurl = true, bold = true, italic = true },
        SpellRare = { sp = colors["gnohj_color04"], undercurl = true, bold = true, italic = true },

        MiniDiffSignAdd = { fg = colors["gnohj_color05"], bold = true },
        MiniDiffSignChange = { fg = colors["gnohj_color02"], bold = true },

        -- Codeblocks for the render-markdown plugin
        RenderMarkdownCode = { bg = colors["gnohj_color07"] },

        -- This is the plugin that shows you where you are at the top
        TreesitterContext = { sp = colors["gnohj_color10"] },
        MiniFilesNormal = { sp = colors["gnohj_color10"] },
        MiniFilesBorder = { sp = colors["gnohj_color10"] },
        MiniFilesTitle = { sp = colors["gnohj_color10"] },
        MiniFilesTitleFocused = { sp = colors["gnohj_color10"] },

        -- Set LazyGit transparent
        -- NormalFloat = { bg = colors["gnohj_color10"] },
        NormalFloat = { bg = "NONE" },

        FloatBorder = { bg = colors["gnohj_color10"] },
        FloatTitle = { bg = colors["gnohj_color10"] },
        NotifyBackground = { bg = colors["gnohj_color10"] },
        NeoTreeNormalNC = { bg = colors["gnohj_color10"] },
        NeoTreeNormal = { bg = colors["gnohj_color10"] },
        NvimTreeWinSeparator = { fg = colors["gnohj_color10"], bg = colors["gnohj_color10"] },
        NvimTreeNormalNC = { bg = colors["gnohj_color10"] },
        NvimTreeNormal = { bg = colors["gnohj_color10"] },
        TroubleNormal = { bg = colors["gnohj_color10"] },

        NoiceCmdlinePopupBorder = { fg = colors["gnohj_color10"] },
        NoiceCmdlinePopupTitle = { fg = colors["gnohj_color10"] },
        NoiceCmdlinePopupBorderFilter = { fg = colors["gnohj_color10"] },
        NoiceCmdlineIconFilter = { fg = colors["gnohj_color10"] },
        NoiceCmdlinePopupTitleFilter = { fg = colors["gnohj_color10"] },
        NoiceCmdlineIcon = { fg = colors["gnohj_color10"] },
        NoiceCmdlineIconCmdline = { fg = colors["gnohj_color03"] },
        NoiceCmdlinePopupBorderCmdline = { fg = colors["gnohj_color02"] },
        NoiceCmdlinePopupTitleCmdline = { fg = colors["gnohj_color03"] },
        NoiceCmdlineIconSearch = { fg = colors["gnohj_color04"] },
        NoiceCmdlinePopupBorderSearch = { fg = colors["gnohj_color03"] },
        NoiceCmdlinePopupTitleSearch = { fg = colors["gnohj_color04"] },
        NoiceCmdlineIconLua = { fg = colors["gnohj_color05"] },
        NoiceCmdlinePopupBorderLua = { fg = colors["gnohj_color01"] },
        NoiceCmdlinePopupTitleLua = { fg = colors["gnohj_color05"] },
        NoiceCmdlineIconHelp = { fg = colors["gnohj_color12"] },
        NoiceCmdlinePopupBorderHelp = { fg = colors["gnohj_color08"] },
        NoiceCmdlinePopupTitleHelp = { fg = colors["gnohj_color12"] },
        NoiceCmdlineIconInput = { fg = colors["gnohj_color10"] },
        NoiceCmdlinePopupBorderInput = { fg = colors["gnohj_color10"] },
        NoiceCmdlinePopupTitleInput = { fg = colors["gnohj_color10"] },
        NoiceCmdlineIconCalculator = { fg = colors["gnohj_color10"] },
        NoiceCmdlinePopupBorderCalculator = { fg = colors["gnohj_color10"] },
        NoiceCmdlinePopupTitleCalculator = { fg = colors["gnohj_color10"] },
        NoiceCompletionItemKindDefault = { fg = colors["gnohj_color10"] },

        NoiceMini = { bg = colors["gnohj_color10"] },
        -- Winbar is liked to the StatusLine color, so to set winbar
        -- transparent, I set the bg to NONE
        StatusLine = { bg = "NONE" },
        -- StatusLine = { bg = colors["gnohj_color10"] },

        DiagnosticInfo = { fg = colors["gnohj_color03"] },
        DiagnosticHint = { fg = colors["gnohj_color02"] },
        DiagnosticWarn = { fg = colors["gnohj_color12"] },
        DiagnosticOk = { fg = colors["gnohj_color04"] },
        DiagnosticError = { fg = colors["gnohj_color11"] },
        RenderMarkdownQuote = { fg = colors["gnohj_color12"] },

        -- visual mode selection
        Visual = { bg = colors["gnohj_color16"], fg = colors["gnohj_color10"] },
        PreProc = { fg = colors["gnohj_color06"] },
        ["@operator"] = { fg = colors["gnohj_color02"] },

        KubectlHeader = { fg = colors["gnohj_color04"] },
        KubectlWarning = { fg = colors["gnohj_color03"] },
        KubectlError = { fg = colors["gnohj_color01"] },
        KubectlInfo = { fg = colors["gnohj_color02"] },
        KubectlDebug = { fg = colors["gnohj_color05"] },
        KubectlSuccess = { fg = colors["gnohj_color02"] },
        KubectlPending = { fg = colors["gnohj_color03"] },
        KubectlDeprecated = { fg = colors["gnohj_color08"] },
        KubectlExperimental = { fg = colors["gnohj_color09"] },
        KubectlNote = { fg = colors["gnohj_color03"] },
        KubectlGray = { fg = colors["gnohj_color10"] },

        -- Colorcolumn that helps me with markdown guidelines
        ColorColumn = { bg = colors["gnohj_color13"] },

        FzfLuaFzfPrompt = { fg = colors["gnohj_color04"], bg = colors["gnohj_color10"] },
        FzfLuaCursorLine = { fg = colors["gnohj_color02"], bg = colors["gnohj_color10"] },
        FzfLuaTitle = { fg = colors["gnohj_color03"], bg = colors["gnohj_color10"] },
        FzfLuaSearch = { fg = colors["gnohj_color14"], bg = colors["gnohj_color10"] },
        FzfLuaBorder = { fg = colors["gnohj_color02"], bg = colors["gnohj_color10"] },
        FzfLuaNormal = { fg = colors["gnohj_color14"], bg = colors["gnohj_color10"] },
      }

      -- Apply all highlight definitions at once
      for group, props in pairs(highlight_definitions) do
        highlights[group] = props
      end
    end,
  },
}
