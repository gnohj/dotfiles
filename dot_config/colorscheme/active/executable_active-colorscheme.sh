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
wallpaper="$HOME/Pictures/wallpapers/moon-2.png"

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

gnohj_color04=#987afb

gnohj_color02=#37f499

gnohj_color03=#04d1f9

gnohj_color01=#949ae5

gnohj_color05=#19dfcf

gnohj_color08=#5fa9f4

gnohj_color06=#04d1f9

#-------------------------------------------------------------------------------
#--           Terminal / Tmux / Nvim
#-------------------------------------------------------------------------------
# Background
gnohj_color10=#021c31

# Terminal - Cursor color
gnohj_color24=#47FF9C

# Terminal red
gnohj_color11=#f16c75

# Terminal white / Text
gnohj_color14=#c0caf5
# gnohj_color14=#ebfafa
# foreground = #CBE0F0

#-------------------------------------------------------------------------------
#--                  Nvim
#-------------------------------------------------------------------------------
# Nvim - Lualine across
gnohj_color17=#2C3A54

# Nvim - Markdown codeblock
gnohj_color07=#1c242f

# Nvim - line across cursor
gnohj_color13=#4A5F7A

# Nvim - Comments / Nvim Ghost Text
gnohj_color09=#6272A4

# Nvim - Underline spellcap
gnohj_color12=#f1fc79

# Nvim - Selected text (bg visual)
gnohj_color16=#275378

# Nvim - Diffview colors
gnohj_color27=#F6F6F5
gnohj_color28=#202624
gnohj_color29=#87E58E
gnohj_color30=#22372C
gnohj_color31=#E95678
gnohj_color32=#342231
gnohj_color33=#FFBFA9
gnohj_color34=#202624
gnohj_color35=#A7DFEF
gnohj_color36=#97EDA2
gnohj_color37=#F6F6B6
gnohj_color38=#EC6A88

#-------------------------------------------------------------------------------
#--               Nvim Lighter markdown headings
#-- # This is based off of Terminal Palette
#-- 4 colors to the right for these ligher headings
#-- https://www.color-hex.com/color/987afb
#-------------------------------------------------------------------------------
# Nvim - Markdown heading 1 - color04
gnohj_color18=#5b4996
# Nvim - Markdown heading 2 - color02
gnohj_color19=#21925b
# Nvim -Markdown heading 3 - color03
gnohj_color20=#027d95
# Nvim -Markdown heading 4 - color01
gnohj_color21=#585c89
# Nvim -Markdown heading 5 - color05
gnohj_color22=#0f857c
# Nvim - Markdown heading 6 - color08
gnohj_color23=#396592
# Nvim - Markdown heading foreground
# usually set to color10 which is the terminal background
gnohj_color26=#0D1116
