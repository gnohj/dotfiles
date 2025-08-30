#!/usr/bin/env bash
#shellcheck disable=SC2034,SC2154

# Original gnohj colorscheme - Vibrant neon theme
# Needs to conform to nvim - https://github.com/folke/tokyonight.nvim/blob/main/extras/lua/tokyonight_storm.lua
# Needs to conform to ghostty - https://github.com/folke/tokyonight.nvim/blob/main/extras/ghostty/tokyonight_storm
# Do not get rid of existing background colors that are commented out - gnohj_color10

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
gnohj_color24=#47ff9c
# Terminal red
gnohj_color11=#f16c75
# Terminal white / Text
gnohj_color14=#c0caf5
# Nvim Green
gnohj_color40=#9ece6a
# Nvim yellow
gnohj_color41=#e0af68
#-------------------------------------------------------------------------------
#--                  Nvim
#-------------------------------------------------------------------------------
# Nvim - Lualine across
gnohj_color17=#2c3a54
# Nvim - Markdown codeblock
gnohj_color07=#1c242f
# Nvim - line across cursor
gnohj_color13=#4a5f7a
# Nvim - Comments / Nvim Ghost Text
gnohj_color09=#6272a4
# Nvim - Underline spellcap
gnohj_color12=#f1fc79
# Nvim - Selected text (bg visual)
gnohj_color16=#275378
# Nvim - Diffview colors
gnohj_color27=#f6f6f5
gnohj_color28=#202624
gnohj_color29=#87e58e
gnohj_color30=#22372c
gnohj_color31=#e95678
gnohj_color32=#342231
gnohj_color33=#ffbfa9
gnohj_color34=#202624
gnohj_color35=#a7dfef
gnohj_color36=#97eda2
gnohj_color37=#f6f6b6
gnohj_color38=#ec6a88
#-------------------------------------------------------------------------------
#--               Neon Structure Variants
#-- Based on original neon/vibrant color philosophy
#-------------------------------------------------------------------------------
# Neon blue variants
# electric purple
gnohj_color39=#8a6fff
# bright electric blue
gnohj_color42=#00bfff
# cyan electric
gnohj_color43=#00ffff
# light neon blue
gnohj_color44=#87ceeb
# ultra bright blue
gnohj_color45=#40e0d0
# dark electric blue
gnohj_color46=#4169e1
# Neon accent variants
# electric green
gnohj_color47=#00ff7f
# neon lime
gnohj_color48=#32cd32
# electric pink
gnohj_color49=#ff1493
# bright magenta
gnohj_color50=#ff00ff
# electric orange
gnohj_color51=#ff4500
# neon yellow
gnohj_color52=#ffff00
# Additional functional colors
# deep dark blue
gnohj_color53=#191970
# medium electric blue
gnohj_color54=#0066cc
# bright violet
gnohj_color55=#9370db
# dark slate
gnohj_color56=#2f4f4f
# steel blue
gnohj_color57=#4682b4
# light cyan
gnohj_color58=#e0ffff

#-------------------------------------------------------------------------------
#--               Gitmux High Contrast Colors
#-------------------------------------------------------------------------------
# Brighter/more vibrant versions for better visibility
gnohj_color59=#4a8091
gnohj_color60=#6fa856
gnohj_color61=#7a6dff
gnohj_color62=#8a6d9e
gnohj_color63=#3e9e99

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
# Nvim - Markdown heading 3 - color03
gnohj_color20=#027d95
# Nvim - Markdown heading 4 - color01
gnohj_color21=#585c89
# Nvim - Markdown heading 5 - color05
gnohj_color22=#0f857c
# Nvim - Markdown heading 6 - color08
gnohj_color23=#396592
# Nvim - Markdown heading foreground
# usually set to color10 which is the terminal background
gnohj_color26=#0d1116
