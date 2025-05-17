if vim.g.vscode then
  return {}
end

local transparent = true

return {
  "folke/tokyonight.nvim",
  lazy = true,
  priority = 1000,
  opts = {
    style = "storm",
    transparent = true,
    styles = {
      sidebars = true and "transparent" or "dark",
      floats = true and "transparent" or "dark",
    },
    on_colors = function(colors)
      local bg = "#011628"
      local bg_dark = "#011423"
      local bg_highlight = "#143652"
      local bg_search = "#0A64AC"
      local bg_visual = "#275378"
      local fg = "#c0caf5"
      local fg_dark = "#a9b1d6"
      local fg_gutter = "#3b4261"
      local border = "#547998"

      colors.bg = bg
      colors.bg_dark = transparent and colors.none or bg_dark
      colors.bg_float = transparent and colors.none or bg_dark
      colors.bg_highlight = bg_highlight
      colors.bg_popup = bg_dark
      colors.bg_search = bg_search
      colors.bg_sidebar = transparent and colors.none or bg_dark
      colors.bg_statusline = transparent and colors.none or bg_dark
      colors.bg_visual = bg_visual
      colors.border = border
      colors.fg = fg
      colors.fg_dark = fg_dark
      colors.fg_float = fg
      colors.fg_gutter = fg_gutter
      colors.fg_sidebar = fg_dark
    end,
    on_highlights = function(hl, colors)
      -- Diffview
      hl.DiffChange = { fg = "#F6F6F5", bg = "#202624" }
      hl.DiffAdd = { fg = "#87E58E", bg = "#22372C" }
      hl.DiffDelete = { fg = "#E95678", bg = "#342231" }
      hl.DiffText = { fg = "#FFBFA9", bg = "#202624", bold = true }

      hl.DiffviewFolderSign = { fg = "#A7DFEF" }
      hl.DiffviewNonText = { fg = colors.comment }
      hl.diffAdded = { fg = "#97EDA2", bold = true }
      hl.diffChanged = { fg = "#F6F6B6", bold = true }
      hl.diffRemoved = { fg = "#EC6A88", bold = true }

      -- Noice
      -- Default/generic elements
      hl.NoiceCmdlinePopupBorder = { fg = colors.border }
      hl.NoiceCmdlinePopupTitle = { fg = colors.blue }
      hl.NoiceCmdlineIcon = { fg = colors.blue }

      -- Filter-specific elements
      hl.NoiceCmdlinePopupBorderFilter = { fg = colors.teal }
      hl.NoiceCmdlineIconFilter = { fg = colors.teal }
      hl.NoiceCmdlinePopupTitleFilter = { fg = colors.teal }

      -- Command line elements
      hl.NoiceCmdlineIconCmdline = { fg = colors.magenta }
      hl.NoiceCmdlinePopupBorderCmdline = { fg = colors.magenta }
      hl.NoiceCmdlinePopupTitleCmdline = { fg = colors.magenta }

      -- Search elements
      hl.NoiceCmdlineIconSearch = { fg = colors.green }
      hl.NoiceCmdlinePopupBorderSearch = { fg = colors.green }
      hl.NoiceCmdlinePopupTitleSearch = { fg = colors.green }

      -- Lua elements
      hl.NoiceCmdlineIconLua = { fg = colors.yellow }
      hl.NoiceCmdlinePopupBorderLua = { fg = colors.yellow }
      hl.NoiceCmdlinePopupTitleLua = { fg = colors.yellow }

      -- Help elements
      hl.NoiceCmdlineIconHelp = { fg = colors.orange }
      hl.NoiceCmdlinePopupBorderHelp = { fg = colors.orange }
      hl.NoiceCmdlinePopupTitleHelp = { fg = colors.orange }

      -- Input elements
      hl.NoiceCmdlineIconInput = { fg = colors.blue }
      hl.NoiceCmdlinePopupBorderInput = { fg = colors.blue }
      hl.NoiceCmdlinePopupTitleInput = { fg = colors.blue }

      -- Calculator elements
      hl.NoiceCmdlineIconCalculator = { fg = colors.purple }
      hl.NoiceCmdlinePopupBorderCalculator = { fg = colors.purple }
      hl.NoiceCmdlinePopupTitleCalculator = { fg = colors.purple }

      -- Completion and mini elements
      hl.NoiceCompletionItemKindDefault = { fg = colors.blue }
      hl.NoiceMini = { bg = colors.bg_highlight, fg = colors.fg }
    end,
  },
}
