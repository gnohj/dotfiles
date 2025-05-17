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
    end,
  },
}
