#!/usr/bin/env bash
#shellcheck disable=SC2034,SC2154

# Evergarden Winter colorscheme adaptation - https://github.com/everviolet/nvim/blob/mega/lua/evergarden/colors.lua
# Needs to conform to - https://github.com/folke/tokyonight.nvim/blob/main/extras/lua/tokyonight_night.lua
# Do not get rid of existing background colors that are commented out - gnohj_color10

# Hex colors should be lowercase for compatibility
# Applicable terminal file:
# ~/.config/ghostty/ghostty-theme
# Applicable tmux file:
# ~/.config/tmux/set_tmux_colors.sh
# Applicable neovim plugins:
# - colorscheme - evergarden.lua, etc.
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
gnohj_color04=#b2caed
gnohj_color02=#cbe3b3
gnohj_color03=#b3e6db
gnohj_color01=#d2bdf3
gnohj_color05=#f5d098
gnohj_color08=#4a585c
gnohj_color06=#f7a182
#-------------------------------------------------------------------------------
#--           Terminal / Tmux / Nvim
#-------------------------------------------------------------------------------
# Background

# Darker black
# gnohj_color10=#00040b

# Subtle -blue gray
gnohj_color10=#0f1419

# warmer dark gray
# gnohj_color10=#161318

# lighter / neutral
# gnohj_color10=#1a1b26

# evergarden winter original
# gnohj_color10=#1e2528

# Terminal - Cursor color
gnohj_color24=#b3e3ca
# Terminal red
gnohj_color11=#f57f82
# Terminal white / Text
gnohj_color14=#f8f9e8
# Nvim Green (fallback)
gnohj_color40=#cbe3b3
# Nvim yellow (fallback)
gnohj_color41=#f5d098
#-------------------------------------------------------------------------------
#--                  Nvim
#-------------------------------------------------------------------------------
# Nvim - Lualine across
gnohj_color17=#374145
# Nvim - Markdown codeblock
gnohj_color07=#191e21
# Nvim - line across cursor
gnohj_color13=#4a5f7a
# Nvim - Comments / Nvim Ghost Text
gnohj_color09=#96b4aa
# Nvim - Underline spellcap
gnohj_color12=#dbe6af
# Nvim - Selected text (bg visual)
gnohj_color16=#374145
# Nvim - Diffview colors
gnohj_color27=#f8f9e8
gnohj_color28=#171c1f
gnohj_color29=#cbe3b3
gnohj_color30=#2a3d2a
gnohj_color31=#f57f82
gnohj_color32=#3d2a2a
gnohj_color33=#f7a182
gnohj_color34=#191e21
gnohj_color35=#afd9e6
gnohj_color36=#b3e3ca
gnohj_color37=#f5d098
gnohj_color38=#f3c0e5
#-------------------------------------------------------------------------------
#--               Evergarden Structure Variants
#-- Based on original evergarden colors and surface variants
#-------------------------------------------------------------------------------
# Evergarden blue variants (from original #B2CAED)
# darker blue variant
gnohj_color39=#8ba4c7
# lighter blue variant
gnohj_color42=#c5d4f0
# medium blue variant
gnohj_color43=#9fb7d4
# very light blue
gnohj_color44=#d8e3f3
# ultra light blue
gnohj_color45=#e6eef7
# dark blue-gray
gnohj_color46=#7a90a5
# Evergarden nature variants
# snow variant (from #AFD9E6)
gnohj_color47=#afd9e6
# skye variant (from #B3E6DB)
gnohj_color48=#b3e6db
# aqua variant (from #B3E3CA)
gnohj_color49=#b3e3ca
# lime variant (from #DBE6AF)
gnohj_color50=#dbe6af
# pink variant (from #F3C0E5)
gnohj_color51=#f3c0e5
# cherry variant (from #F6CEE5)
gnohj_color52=#f6cee5
# Additional functional colors
# base variant - darkest
gnohj_color53=#1c2225
# surface variant
gnohj_color54=#2b3337
# overlay variant
gnohj_color55=#374145
# muted variant
gnohj_color56=#4a585c
# subtle variant
gnohj_color57=#58686d
# text variant - lightest
gnohj_color58=#f8f9e8
#-------------------------------------------------------------------------------
#--               Nvim Lighter markdown headings
#-- # This is based off of Terminal Palette
#-- 4 colors to the right for these ligher headings
#-- https://www.color-hex.com/color/b2caed
#-------------------------------------------------------------------------------
# Nvim - Markdown heading 1 - color04
gnohj_color18=#8ba4c7
# Nvim - Markdown heading 2 - color02
gnohj_color19=#a1c48a
# Nvim - Markdown heading 3 - color03
gnohj_color20=#8ac7b5
# Nvim - Markdown heading 4 - color01
gnohj_color21=#b394d4
# Nvim - Markdown heading 5 - color05
gnohj_color22=#d4b571
# Nvim - Markdown heading 6 - color08
gnohj_color23=#3a454a
# Nvim - Markdown heading foreground
# usually set to color10 which is the terminal background
gnohj_color26=#1e2528
