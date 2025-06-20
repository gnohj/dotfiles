#!/usr/bin/env bash
#shellcheck disable=SC2034,SC2154

# Tokyo Night colorscheme adaptation - https://github.com/folke/tokyonight.nvim
# Needs to conform to - https://github.com/folke/tokyonight.nvim/blob/main/extras/lua/tokyonight_night.lua

# Hex colors should be lowercase for compatibility
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
# color02 - ghostty green / nvim green
# color03 - ghostty aqua / nvim cyan
# color01 - ghostty purple
# color05 - ghostty yellow / nvim yellow
# color08 - ghostty secondary black
# color06 - nvim orange
#-------------------------------------------------------------------------------
gnohj_color04=#7aa2f7
gnohj_color02=#9ece6a
gnohj_color03=#7dcfff
gnohj_color01=#bb9af7
gnohj_color05=#e0af68
gnohj_color08=#565f89
gnohj_color06=#ff9e64
#-------------------------------------------------------------------------------
#--           Terminal / Tmux / Nvim
#-------------------------------------------------------------------------------
# Background
gnohj_color10=#1a1b26
# Terminal - Cursor color
gnohj_color24=#73daca
# Terminal red
gnohj_color11=#f7768e
# Terminal white / Text
gnohj_color14=#c0caf5
# Nvim Green (fallback)
gnohj_color40=#9ece6a
# Nvim yellow (fallback)
gnohj_color41=#e0af68
#-------------------------------------------------------------------------------
#--                  Nvim
#-------------------------------------------------------------------------------
# Nvim - Lualine across
gnohj_color17=#292e42
# Nvim - Markdown codeblock
gnohj_color07=#16161e
# Nvim - line across cursor
gnohj_color13=#3b4261
# Nvim - Comments / Nvim Ghost Text
gnohj_color09=#565f89
# Nvim - Underline spellcap
gnohj_color12=#e0af68
# Nvim - Selected text (bg visual)
gnohj_color16=#283457
# Nvim - Diffview colors
gnohj_color27=#c0caf5
gnohj_color28=#16161e
gnohj_color29=#9ece6a
gnohj_color30=#20303b
gnohj_color31=#f7768e
gnohj_color32=#37222c
gnohj_color33=#ff9e64
gnohj_color34=#16161e
gnohj_color35=#7dcfff
gnohj_color36=#73daca
gnohj_color37=#e0af68
gnohj_color38=#bb9af7
#-------------------------------------------------------------------------------
#--               Tokyo Night Blue Structure Variants
#-- Based on original tokyo night blue variants and functional colors
#-------------------------------------------------------------------------------
# Blue variants (from tokyo night blue structure)
# blue0 - darker blue
gnohj_color39=#3d59a1
# blue1 - bright blue
gnohj_color42=#2ac3de
# blue2 - cyan-blue / info
gnohj_color43=#0db9d7
# blue5 - light blue
gnohj_color44=#89ddff
# blue6 - very light blue
gnohj_color45=#b4f9f8
# blue7 - dark blue-gray
gnohj_color46=#394b70
# Additional tokyo night functional colors
# dark3 - medium gray
gnohj_color47=#545c7e
# dark5 - lighter gray
gnohj_color48=#737aa2
# fg_dark - darker foreground
gnohj_color49=#a9b1d6
# green2 - teal-green
gnohj_color50=#41a6b5
# teal/hint - teal color
gnohj_color51=#1abc9c
# magenta2 - bright magenta
gnohj_color52=#ff007c
# terminal_black - terminal black
gnohj_color53=#414868
# Status and additional colors
# red1/error - darker red
gnohj_color54=#db4b4b
# purple - different purple shade
gnohj_color55=#9d7cd8
# black/border - true black
gnohj_color56=#15161e
# border_highlight - highlight border
gnohj_color57=#27a1b9
# bg_dark1 - darkest background
gnohj_color58=#0c0e14
#-------------------------------------------------------------------------------
#--               Nvim Lighter markdown headings
#-- # This is based off of Terminal Palette
#-- 4 colors to the right for these ligher headings
#-- https://www.color-hex.com/color/7aa2f7
#-------------------------------------------------------------------------------
# Nvim - Markdown heading 1 - color04
gnohj_color18=#5a7fc7
# Nvim - Markdown heading 2 - color02
gnohj_color19=#7dae50
# Nvim - Markdown heading 3 - color03
gnohj_color20=#5dadcf
# Nvim - Markdown heading 4 - color01
gnohj_color21=#9b7ac7
# Nvim - Markdown heading 5 - color05
gnohj_color22=#c09050
# Nvim - Markdown heading 6 - color08
gnohj_color23=#454c6b
# Nvim - Markdown heading foreground
# usually set to color10 which is the terminal background
gnohj_color26=#1a1b26
