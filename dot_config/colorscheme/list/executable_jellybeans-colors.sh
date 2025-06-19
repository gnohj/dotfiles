#!/usr/bin/env bash
#shellcheck disable=SC2034,SC2154
# Jellybeans colorscheme adaptation - https://github.com/WTFox/jellybeans.nvim/blob/main/lua/jellybeans/palettes/jellybeans.lua
# Applicable terminal file:
# ~/.config/ghostty/ghostty-theme
# Applicable tmux file:
# ~/.config/tmux/set_tmux_colors.sh
# Applicable neovim plugins:
# - colorscheme - jellybeans.lua, etc.
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
# color02 - ghostty green / nvim green
# color03 - ghostty aqua / nvim cyan
# color01 - ghostty purple
# color05 - ghostty yellow / nvim yellow
# color08 - ghostty secondary black
# color06 - nvim orange
#-------------------------------------------------------------------------------
gnohj_color04=#8197bf
gnohj_color02=#70b950
gnohj_color03=#8fbfdc
gnohj_color01=#c6b6ee
gnohj_color05=#fad07a
gnohj_color08=#404040
gnohj_color06=#e6a75a
#-------------------------------------------------------------------------------
#--           Terminal / Tmux / Nvim
#-------------------------------------------------------------------------------
# Background
gnohj_color10=#021c31
# Terminal - Cursor color
gnohj_color24=#99ad6a
# Terminal red
gnohj_color11=#d74545
# Terminal white / Text
gnohj_color14=#e8e8d3
#-------------------------------------------------------------------------------
#--                  Nvim
#-------------------------------------------------------------------------------
# Nvim - Lualine across
gnohj_color17=#333333
# Nvim - Markdown codeblock
gnohj_color07=#1c1c1c
# Nvim - line across cursor
gnohj_color13=#555555
# Nvim - Comments / Nvim Ghost Text
gnohj_color09=#888888
# Nvim - Underline spellcap
gnohj_color12=#dad085
# Nvim - Selected text (bg visual)
gnohj_color16=#404040
# Nvim - Diffview colors
gnohj_color27=#e8e8d3
gnohj_color28=#1f1f1f
gnohj_color29=#99ad6a
gnohj_color30=#2a3d2a
gnohj_color31=#d74545
gnohj_color32=#3d2a2a
gnohj_color33=#d98870
gnohj_color34=#1f1f1f
gnohj_color35=#8fbfdc
gnohj_color36=#70b950
gnohj_color37=#fad07a
gnohj_color38=#cc88a3
#-------------------------------------------------------------------------------
#--               Nvim Lighter markdown headings
#-- # This is based off of Terminal Palette
#-- 4 colors to the right for these ligher headings
#-------------------------------------------------------------------------------
# Nvim - Markdown heading 1 - color04 (darker ship_cove)
gnohj_color18=#5a6b8a
# Nvim - Markdown heading 2 - color02 (darker mantis)
gnohj_color19=#4d7d35
# Nvim - Markdown heading 3 - color03 (darker morning_glory)
gnohj_color20=#6299b5
# Nvim - Markdown heading 4 - color01 (darker biloba_flower)
gnohj_color21=#9a94c4
# Nvim - Markdown heading 5 - color05 (darker goldenrod)
gnohj_color22=#c7a85a
# Nvim - Markdown heading 6 - color08 (darker tundora)
gnohj_color23=#2d2d2d
# Nvim - Markdown heading foreground
gnohj_color26=#151515
