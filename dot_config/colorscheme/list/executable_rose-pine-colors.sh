#!/usr/bin/env bash
#shellcheck disable=SC2034,SC2154

# Rose Pine colorscheme adaptation - https://github.com/rose-pine/rose-pine-theme
# Needs to conform to - https://github.com/folke/tokyonight.nvim/blob/main/extras/lua/tokyonight_night.lua

# Hex colors should be lowercase for compatibility
# Applicable terminal file:
# ~/.config/ghostty/ghostty-theme
# Applicable tmux file:
# ~/.config/tmux/set_tmux_colors.sh
# Applicable neovim plugins:
# - colorscheme - rose-pine.lua, etc.
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
gnohj_color04=#c4a7e7
gnohj_color02=#9ccfd8
gnohj_color03=#31748f
gnohj_color01=#eb6f92
gnohj_color05=#f6c177
gnohj_color08=#524f67
gnohj_color06=#ebbcba
#-------------------------------------------------------------------------------
#--           Terminal / Tmux / Nvim
#-------------------------------------------------------------------------------
# Background
gnohj_color10=#191724
# Terminal - Cursor color
gnohj_color24=#9ccfd8
# Terminal red
gnohj_color11=#eb6f92
# Terminal white / Text
gnohj_color14=#e0def4
# Nvim Green (fallback)
gnohj_color40=#9ccfd8
# Nvim yellow (fallback)
gnohj_color41=#f6c177
#-------------------------------------------------------------------------------
#--                  Nvim
#-------------------------------------------------------------------------------
# Nvim - Lualine across
gnohj_color17=#26233a
# Nvim - Markdown codeblock
gnohj_color07=#1f1d2e
# Nvim - line across cursor
gnohj_color13=#403d52
# Nvim - Comments / Nvim Ghost Text
gnohj_color09=#6e6a86
# Nvim - Underline spellcap
gnohj_color12=#f6c177
# Nvim - Selected text (bg visual)
gnohj_color16=#403d52
# Nvim - Diffview colors
gnohj_color27=#e0def4
gnohj_color28=#21202e
gnohj_color29=#9ccfd8
gnohj_color30=#2d3f2f
gnohj_color31=#eb6f92
gnohj_color32=#524267
gnohj_color33=#ebbcba
gnohj_color34=#1f1d2e
gnohj_color35=#31748f
gnohj_color36=#9ccfd8
gnohj_color37=#f6c177
gnohj_color38=#eb6f92
#-------------------------------------------------------------------------------
#--               Rose Pine Structure Variants
#-- Based on original rose pine colors and surface variants
#-------------------------------------------------------------------------------
# Rose Pine surface variants
# surface - darker background
gnohj_color39=#1f1d2e
# overlay - medium background
gnohj_color42=#26233a
# overlay2 - lighter background
gnohj_color43=#403d52
# muted - muted text
gnohj_color44=#524f67
# subtle - subtle text
gnohj_color45=#6e6a86
# text - secondary text
gnohj_color46=#908caa
# Rose Pine highlight variants
# love - primary accent
gnohj_color47=#eb6f92
# gold - secondary accent
gnohj_color48=#f6c177
# rose - tertiary accent
gnohj_color49=#ebbcba
# foam - quaternary accent
gnohj_color50=#9ccfd8
# pine - pine accent
gnohj_color51=#31748f
# iris - iris accent
gnohj_color52=#c4a7e7
# Additional functional colors
# base variant - darkest
gnohj_color53=#16141a
# surface variant
gnohj_color54=#21202e
# overlay variant
gnohj_color55=#2a273f
# muted variant
gnohj_color56=#56526e
# subtle variant
gnohj_color57=#797593
# text variant - lightest
gnohj_color58=#e0def4
#-------------------------------------------------------------------------------
#--               Nvim Lighter markdown headings
#-- # This is based off of Terminal Palette
#-- 4 colors to the right for these ligher headings
#-- https://www.color-hex.com/color/c4a7e7
#-------------------------------------------------------------------------------
# Nvim - Markdown heading 1 - color04
gnohj_color18=#9d7fc7
# Nvim - Markdown heading 2 - color02
gnohj_color19=#7ba7b0
# Nvim - Markdown heading 3 - color03
gnohj_color20=#255a6f
# Nvim - Markdown heading 4 - color01
gnohj_color21=#c54772
# Nvim - Markdown heading 5 - color05
gnohj_color22=#d49957
# Nvim - Markdown heading 6 - color08
gnohj_color23=#423f57
# Nvim - Markdown heading foreground
# usually set to color10 which is the terminal background
gnohj_color26=#191724
