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
wallpaper="$HOME/Pictures/wallpapers/astronaut.jpg"

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

gnohj_color04=#04d1f9

gnohj_color02=#487ef0

gnohj_color03=#90b1f6

gnohj_color01=#FFFFFF

gnohj_color05=#f34d4f

gnohj_color08=#FACF11

gnohj_color06=#97956F

#-------------------------------------------------------------------------------
#--           Terminal / Tmux / Nvim
#-------------------------------------------------------------------------------
# Background
gnohj_color10=#00040b

# Terminal - Cursor color
gnohj_color24=#e93f92

# Terminal red
gnohj_color11=#f34d4f

# Terminal white / Text
gnohj_color14=#FFFFFF
# gnohj_color14=#FFFFFF
# foreground = #CBE0F0

#-------------------------------------------------------------------------------
#--                  Nvim
#-------------------------------------------------------------------------------
# Nvim - Lualine across
gnohj_color17=#000b1f

# Nvim - Markdown codeblock
gnohj_color07=#001232

# Nvim - line across cursor
gnohj_color13=#001946

# Nvim - Comments / Nvim Ghost Text
gnohj_color09=#999999

# Nvim - Underline spellcap
gnohj_color12=#FACF11

# Nvim - Selected text (bg visual)
gnohj_color16=#00ffff

# Nvim - Diffview colors
gnohj_color27=#F6F6F5
gnohj_color28=#00040b
gnohj_color29=#487EF0
gnohj_color30=#000B1F
gnohj_color31=#F34D4F
gnohj_color32=#00040b
gnohj_color33=#90B1F6
gnohj_color34=#00040b
gnohj_color35=#04D1F9
gnohj_color36=#487EF0
gnohj_color37=#FACF11
gnohj_color38=#E93F92

#-------------------------------------------------------------------------------
#--               Nvim Lighter markdown headings
#-- # This is based off of Terminal Palette
#-- 4 colors to the right for these ligher headings
#-- https://www.color-hex.com/color/987afb
#-------------------------------------------------------------------------------
# Nvim - Markdown heading 1 - color04
gnohj_color18=#027C94
# Nvim - Markdown heading 2 - color02
gnohj_color19=#2b4b90
# Nvim -Markdown heading 3 - color03
gnohj_color20=#566a93
# Nvim -Markdown heading 4 - color01
gnohj_color21=#999999
# Nvim -Markdown heading 5 - color05
gnohj_color22=#912e2f
# Nvim - Markdown heading 6 - color08
gnohj_color23=#645206
# Nvim - Markdown heading foreground
# usually set to color10 which is the terminal background
gnohj_color26=#00040b
