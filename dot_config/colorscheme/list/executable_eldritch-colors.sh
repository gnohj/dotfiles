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
wallpaper="$HOME/Pictures/wallpapers/usa.jpg"

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

gnohj_color04=#a48cf2

gnohj_color02=#37f499

gnohj_color03=#04d1f9

gnohj_color01=#f265b5

gnohj_color05=#f1fc79

gnohj_color08=#f16c75

gnohj_color06=#f7c67f

#-------------------------------------------------------------------------------
#--           Terminal / Tmux / Nvim
#-------------------------------------------------------------------------------
# Background
gnohj_color10=#212337

# Terminal - Cursor color
gnohj_color24=#F712FF

# Terminal red
gnohj_color11=#f16c75

# Terminal white / Text
gnohj_color14=#ebfafa
# gnohj_color14=#ebfafa
# foreground = #CBE0F0

#-------------------------------------------------------------------------------
#--                  Nvim
#-------------------------------------------------------------------------------
# Nvim - Lualine across
gnohj_color17=#282b43

# Nvim - Markdown codeblock
gnohj_color07=#314154

# Nvim - line across cursor
gnohj_color13=#314154

# Nvim - Comments / Nvim Ghost Text
gnohj_color09=#a5afc2

# Nvim - Underline spellcap
gnohj_color12=#f1fc79

# Nvim - Selected text (bg visual)
gnohj_color16=#d99ffd

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
gnohj_color18=#625491
# Nvim - Markdown heading 2 - color02
gnohj_color19=#21925b
# Nvim -Markdown heading 3 - color03
gnohj_color20=#027d95
# Nvim -Markdown heading 4 - color01
gnohj_color21=#913c6d
# Nvim -Markdown heading 5 - color05
gnohj_color22=#909748
# Nvim - Markdown heading 6 - color08
gnohj_color23=#904146
# Nvim - Markdown heading foreground
# usually set to color10 which is the terminal background
gnohj_color26=#212337
