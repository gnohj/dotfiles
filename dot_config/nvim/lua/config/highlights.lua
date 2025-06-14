-- Require the colors.lua module and access the colors directly without
-- additional file reads
local colors = require("config.colors")
local color1_bg = colors["gnohj_color04"]
local color2_bg = colors["gnohj_color02"]
local color3_bg = colors["gnohj_color03"]
local color4_bg = colors["gnohj_color01"]
local color5_bg = colors["gnohj_color05"]
local color6_bg = colors["gnohj_color08"]
-- local color_fg = colors["gnohj_color26"]
local color_fg = colors["gnohj_color13"]

if vim.g.md_heading_bg == "transparent" then
  vim.cmd(
    string.format([[highlight @markup.heading.1.markdown cterm=bold gui=bold guibg=%s guifg=%s]], color_fg, color1_bg)
  )
  vim.cmd(
    string.format([[highlight @markup.heading.2.markdown cterm=bold gui=bold guibg=%s guifg=%s]], color_fg, color2_bg)
  )
  vim.cmd(
    string.format([[highlight @markup.heading.3.markdown cterm=bold gui=bold guibg=%s guifg=%s]], color_fg, color3_bg)
  )
  vim.cmd(
    string.format([[highlight @markup.heading.4.markdown cterm=bold gui=bold guibg=%s guifg=%s]], color_fg, color4_bg)
  )
  vim.cmd(
    string.format([[highlight @markup.heading.5.markdown cterm=bold gui=bold guibg=%s guifg=%s]], color_fg, color5_bg)
  )
  vim.cmd(
    string.format([[highlight @markup.heading.6.markdown cterm=bold gui=bold guibg=%s guifg=%s]], color_fg, color6_bg)
  )
else
  color_fg = colors["gnohj_color26"]
  vim.cmd(
    string.format([[highlight @markup.heading.1.markdown cterm=bold gui=bold guifg=%s guibg=%s]], color_fg, color1_bg)
  )
  vim.cmd(
    string.format([[highlight @markup.heading.2.markdown cterm=bold gui=bold guifg=%s guibg=%s]], color_fg, color2_bg)
  )
  vim.cmd(
    string.format([[highlight @markup.heading.3.markdown cterm=bold gui=bold guifg=%s guibg=%s]], color_fg, color3_bg)
  )
  vim.cmd(
    string.format([[highlight @markup.heading.4.markdown cterm=bold gui=bold guifg=%s guibg=%s]], color_fg, color4_bg)
  )
  vim.cmd(
    string.format([[highlight @markup.heading.5.markdown cterm=bold gui=bold guifg=%s guibg=%s]], color_fg, color5_bg)
  )
  vim.cmd(
    string.format([[highlight @markup.heading.6.markdown cterm=bold gui=bold guifg=%s guibg=%s]], color_fg, color6_bg)
  )
end
