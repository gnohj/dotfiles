if vim.g.vscode then
  return {}
end

return {
  "MeanderingProgrammer/render-markdown.nvim",
  enabled = true,
  opts = function()
    -- Heading colors (when not hovered over), extends through the entire line
    vim.cmd(string.format([[highlight Headline1Bg guifg=%s guibg=%s]], "#f38ba8", "#4d3649"))
    vim.cmd(string.format([[highlight Headline2Bg guifg=%s guibg=%s]], "#f9b387", "#4d3d43"))
    vim.cmd(string.format([[highlight Headline3Bg guifg=%s guibg=%s]], "#f9e2af", "#4c474b"))
    vim.cmd(string.format([[highlight Headline4Bg guifg=%s guibg=%s]], "#a6e3a1", "#3c4948"))
    vim.cmd(string.format([[highlight Headline5Bg guifg=%s guibg=%s]], "#74c7ec", "#314358"))
    vim.cmd(string.format([[highlight Headline6Bg guifg=%s guibg=%s]], "#b4befe", "#3c405b"))
    vim.cmd(string.format([[highlight Headline7Bg guifg=%s guibg=%s]], "#cba6f7", "#403b5a"))

    return {
      bullet = {
        enabled = true,
        right_pad = 1,
      },
      checkbox = {
        -- Turn on / off checkbox state rendering
        enabled = true,
        -- Determines how icons fill the available space:
        --  inline:  underlying text is concealed resulting in a left aligned icon
        --  overlay: result is left padded with spaces to hide any additional text
        unchecked = {
          -- Replaces '[ ]' of 'task_list_marker_unchecked'
          icon = "   󰄱 ",
          -- Highlight for the unchecked icon
          highlight = "RenderMarkdownUnchecked",
          -- Highlight for item associated with unchecked checkbox
          scope_highlight = nil,
        },
        checked = {
          -- Replaces '[x]' of 'task_list_marker_checked'
          icon = "   󰱒 ",
          -- Highlight for the checked icon
          highlight = "RenderMarkdownChecked",
          -- Highlight for item associated with checked checkbox
          scope_highlight = nil,
        },
      },
      html = {
        -- Turn on / off all HTML rendering
        enabled = true,
        comment = {
          -- Turn on / off HTML comment concealing
          conceal = false,
        },
      },
      link = {
        image = "󰥶 ",
        custom = {
          youtu = { pattern = "youtu%.be", icon = "󰗃 " },
        },
      },
      -- heading = {
      --   sign = false,
      --   icons = { "󰎤 ", "󰎧 ", "󰎪 ", "󰎭 ", "󰎱 ", "󰎳 " },
      --   -- backgrounds = {
      --   --   "Headline1Bg",
      --   --   "Headline2Bg",
      --   --   "Headline3Bg",
      --   --   "Headline4Bg",
      --   --   "Headline5Bg",
      --   --   "Headline6Bg",
      --   -- },
      --   -- foregrounds = {
      --   --   "Headline1Fg",
      --   --   "Headline2Fg",
      --   --   "Headline3Fg",
      --   --   "Headline4Fg",
      --   --   "Headline5Fg",
      --   --   "Headline6Fg",
      --   -- },
      -- },
      -- code = {
      --   -- if I'm not using yabai, I cannot make the color of the codeblocks
      --   -- transparent, so just disabling all rendering 😢
      --   style = "none",
      -- },
    }
  end,
}
