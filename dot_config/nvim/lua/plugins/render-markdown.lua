local colors = require("config.colors")

return {
  "MeanderingProgrammer/render-markdown.nvim",
  enabled = true,
  -- Moved highlight creation out of opts as suggested by plugin maintainer
  -- There was no issue, but it was creating unnecessary noise when ran
  -- :checkhealth render-markdown
  -- https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/138#issuecomment-2295422741
  init = function()
    local colorInline_bg = colors["gnohj_color02"]
    local color_fg = colors["gnohj_color26"]
    local color_sign = "#ebfafa"
    -- set in ~/.config/colorscheme/colorscheme-vars.sh
    -- set in ~/.config/nvim/init.lua
    if vim.g.md_heading_bg == "transparent" then
      local color1_bg = colors["gnohj_color04"]
      local color2_bg = colors["gnohj_color02"]
      local color3_bg = colors["gnohj_color03"]
      local color4_bg = colors["gnohj_color01"]
      local color5_bg = colors["gnohj_color05"]
      local color6_bg = colors["gnohj_color08"]
      local color_fg1 = colors["gnohj_color18"]
      local color_fg2 = colors["gnohj_color19"]
      local color_fg3 = colors["gnohj_color20"]
      local color_fg4 = colors["gnohj_color21"]
      local color_fg5 = colors["gnohj_color22"]
      local color_fg6 = colors["gnohj_color23"]

      -- Heading colors (when not hovered over), extends through the entire line
      vim.cmd(
        string.format(
          [[highlight Headline1Bg guibg=%s guifg=%s ]],
          color_fg1,
          color1_bg
        )
      )
      vim.cmd(
        string.format(
          [[highlight Headline2Bg guibg=%s guifg=%s ]],
          color_fg2,
          color2_bg
        )
      )
      vim.cmd(
        string.format(
          [[highlight Headline3Bg guibg=%s guifg=%s ]],
          color_fg3,
          color3_bg
        )
      )
      vim.cmd(
        string.format(
          [[highlight Headline4Bg guibg=%s guifg=%s ]],
          color_fg4,
          color4_bg
        )
      )
      vim.cmd(
        string.format(
          [[highlight Headline5Bg guibg=%s guifg=%s ]],
          color_fg5,
          color5_bg
        )
      )
      vim.cmd(
        string.format(
          [[highlight Headline6Bg guibg=%s guifg=%s ]],
          color_fg6,
          color6_bg
        )
      )
      vim.cmd(
        string.format(
          [[highlight RenderMarkdownCodeInline guifg=%s guibg=%s]],
          colorInline_bg,
          color_fg
        )
      )
      vim.cmd(
        string.format(
          [[highlight RenderMarkdownCodeInline guifg=%s]],
          colorInline_bg
        )
      )
    else
      local color1_bg = colors["gnohj_color18"]
      local color2_bg = colors["gnohj_color19"]
      local color3_bg = colors["gnohj_color20"]
      local color4_bg = colors["gnohj_color21"]
      local color5_bg = colors["gnohj_color22"]
      local color6_bg = colors["gnohj_color23"]
      vim.cmd(
        string.format(
          [[highlight Headline1Bg guifg=%s guibg=%s]],
          color_fg,
          color1_bg
        )
      )
      vim.cmd(
        string.format(
          [[highlight Headline2Bg guifg=%s guibg=%s]],
          color_fg,
          color2_bg
        )
      )
      vim.cmd(
        string.format(
          [[highlight Headline3Bg guifg=%s guibg=%s]],
          color_fg,
          color3_bg
        )
      )
      vim.cmd(
        string.format(
          [[highlight Headline4Bg guifg=%s guibg=%s]],
          color_fg,
          color4_bg
        )
      )
      vim.cmd(
        string.format(
          [[highlight Headline5Bg guifg=%s guibg=%s]],
          color_fg,
          color5_bg
        )
      )
      vim.cmd(
        string.format(
          [[highlight Headline6Bg guifg=%s guibg=%s]],
          color_fg,
          color6_bg
        )
      )
    end
  end,
  opts = function()
    return {
      bullet = {
        enabled = true,
        right_pad = 1,
      },
      checkbox = {
        enabled = true,
        unchecked = {
          icon = "   󰄱 ",
          highlight = "RenderMarkdownUnchecked",
          scope_highlight = nil,
        },
        checked = {
          icon = "   󰱒 ",
          highlight = "RenderMarkdownChecked",
          scope_highlight = nil,
        },
      },
      html = {
        enabled = true,
        comment = {
          conceal = false,
        },
      },
      link = {
        image = "󰥶 ",
        custom = {
          youtu = { pattern = "youtu%.be", icon = "󰗃 " },
        },
        highlight = "RenderMarkdownLink", -- This should not have spell check
      },
      heading = {
        sign = false,
        width = "block",
        icons = { "󰎤 ", "󰎧 ", "󰎪 ", "󰎭 ", "󰎱 ", "󰎳 " },
        backgrounds = {
          "Headline1Bg",
          "Headline2Bg",
          "Headline3Bg",
          "Headline4Bg",
          "Headline5Bg",
          "Headline6Bg",
        },
        foregrounds = {
          "Headline1Fg",
          "Headline2Fg",
          "Headline3Fg",
          "Headline4Fg",
          "Headline5Fg",
          "Headline6Fg",
        },
      },
      code = {
        -- if I'm not using yabai, I cannot make the color of the codeblocks
        -- transparent, so just disabling all rendering 😢
        -- style = "none",
      },
    }
  end,
}
