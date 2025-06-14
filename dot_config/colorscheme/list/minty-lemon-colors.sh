#!/usr/bin/env bash
#shellcheck disable=SC2034,SC2154

# Applicable terminal file:
# ~/.config/ghostty/ghostty-theme

# Applicable tmux file:
# ~/.config/tmux/set_tmux_colors.sh

# Applicable neovim plugins:
# - colorscheme - tokyonight.lua, etc.
# - highlights.lua
# - lualine.lua
# - render-markdown.lua
# - package-info.lua

#-------------------------------------------------------------------------------
#--                  Wallpaper
#-------------------------------------------------------------------------------
wallpaper="$HOME/Pictures/wallpapers/sunset-city.jpg"

#-------------------------------------------------------------------------------
#--           Terminal Palette Colors
# color04 - ghostty blue / nvim purple
# color02 - ghostty green / nvim green (disabled)
# color03 - ghostty aqua / nvim cyan
# color01 - ghostty purple
# color05 - ghostty yellow / nvim yellow (disabled)
# color08 - ghostty secondary black
# color06 - nvim orange
#-------------------------------------------------------------------------------

gnohj_color04=#37f499

gnohj_color02=#04d1f9

gnohj_color03=#81f8bf

gnohj_color01=#4fe0fc

gnohj_color05=#04F9F8

gnohj_color08=#4ffced

gnohj_color06=#9deefd

#-------------------------------------------------------------------------------
#--           Terminal / Tmux / Nvim
#-------------------------------------------------------------------------------
# Background
gnohj_color10=#0D1116

# Terminal - Cursor color
gnohj_color24=#06743f

# Terminal red
gnohj_color11=#026072

# Terminal white / Text
gnohj_color14=#ebfafa
# gnohj_color14=#ebfafa
# foreground = #CBE0F0

#-------------------------------------------------------------------------------
#--                  Nvim
#-------------------------------------------------------------------------------
# Nvim - Lualine across
gnohj_color17=#141b22

# Nvim - Markdown codeblock
gnohj_color07=#1c242f

# Nvim - line across cursor
gnohj_color13=#314154

# Nvim - Comments / Nvim Ghost Text
gnohj_color09=#a5afc2

# Nvim - Underline spellcap
gnohj_color12=#089954

# Nvim - Selected text (bg visual)
gnohj_color16=#ccfce5

# Nvim - Diffview colors
gnohj_color27=#F6F6F5
gnohj_color28=#0D1721
gnohj_color29=#87E58E
gnohj_color30=#0F2817
gnohj_color31=#026072
gnohj_color32=#0D1721
gnohj_color33=#81F8E5
gnohj_color34=#0D1721
gnohj_color35=#A7DFEF
gnohj_color36=#81F8BF
gnohj_color37=#CCFCE5
gnohj_color38=#4FE0FC
#-------------------------------------------------------------------------------
#--               Nvim Lighter markdown headings
#-- # This is based off of Terminal Palette
#-- 4 colors to the right for these ligher headings
#-- https://www.color-hex.com/color/987afb
#-------------------------------------------------------------------------------
# Nvim - Markdown heading 1 - color04
gnohj_color18=#20925b
# Nvim - Markdown heading 2 - color02
gnohj_color19=#027d95
# Nvim -Markdown heading 3 - color03
gnohj_color20=#4d9472
# Nvim -Markdown heading 4 - color01
gnohj_color21=#2f8696
# Nvim -Markdown heading 5 - color05
gnohj_color22=#029494
# Nvim - Markdown heading 6 - color08
gnohj_color23=#1f645e
# Nvim - Markdown heading foreground
# usually set to color10 which is the terminal background
gnohj_color26=#0D1116
