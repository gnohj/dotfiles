#!/usr/bin/env bash
#shellcheck disable=SC2034,SC2154

# Jellybeans colorscheme adaptation - https://github.com/WTFox/jellybeans.nvim/blob/main/lua/jellybeans/palettes/jellybeans.lua
# Needs to conform to - https://github.com/folke/tokyonight.nvim/blob/main/extras/lua/tokyonight_night.lua

# Hex colors should be lowercase for compatibility
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
gnohj_color10=#151515
# Terminal - Cursor color
gnohj_color24=#99ad6a
# Terminal red
gnohj_color11=#d74545
# Terminal white / Text
gnohj_color14=#e8e8d3
# Nvim Green (fallback)
gnohj_color40=#70b950
# Nvim yellow (fallback)
gnohj_color41=#fad07a
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
#--               Jellybeans Structure Variants
#-- Based on original jellybeans colors and functional variants
#-------------------------------------------------------------------------------
# Jellybeans surface variants
# cod_grey - darker background
gnohj_color39=#101010
# mine_shaft - medium background
gnohj_color42=#1f1f1f
# grey_three - lighter background
gnohj_color43=#333333
# tundora - muted background
gnohj_color44=#404040
# scorpion - medium gray
gnohj_color45=#606060
# boulder - lighter gray
gnohj_color46=#777777
# Jellybeans accent variants
# highland - darker green
gnohj_color47=#799d6a
# costa_del_sol - dark green
gnohj_color48=#556633
# hoki - steel blue
gnohj_color49=#668799
# morning_glory - light blue
gnohj_color50=#8fbfdc
# ship_cove - periwinkle
gnohj_color51=#8197bf
# biloba_flower - light purple
gnohj_color52=#c6b6ee
# Additional functional colors
# temptress - dark red
gnohj_color53=#40000a
# old_brick - brick red
gnohj_color54=#902020
# cocoa_brown - dark brown
gnohj_color55=#302028
# gravel - dark gray
gnohj_color56=#403c41
# regent_grey - medium gray
gnohj_color57=#9098a0
# alto - light gray
gnohj_color58=#dddddd
#-------------------------------------------------------------------------------
#--               Nvim Lighter markdown headings
#-- # This is based off of Terminal Palette
#-- 4 colors to the right for these ligher headings
#-- https://www.color-hex.com/color/8197bf
#-------------------------------------------------------------------------------
# Nvim - Markdown heading 1 - color04
gnohj_color18=#5a6b8a
# Nvim - Markdown heading 2 - color02
gnohj_color19=#4d7d35
# Nvim - Markdown heading 3 - color03
gnohj_color20=#6299b5
# Nvim - Markdown heading 4 - color01
gnohj_color21=#9a94c4
# Nvim - Markdown heading 5 - color05
gnohj_color22=#c7a85a
# Nvim - Markdown heading 6 - color08
gnohj_color23=#2d2d2d
# Nvim - Markdown heading foreground
# usually set to color10 which is the terminal background
gnohj_color26=#151515
