#!/usr/bin/env bash
#shellcheck disable=SC2034,SC2154

# Evergarden Winter colorscheme adaptation (Muted - 25% less saturated)- https://github.com/everviolet/nvim/blob/mega/lua/evergarden/colors.lua
# Needs to conform to nvim - https://github.com/folke/tokyonight.nvim/blob/main/extras/lua/tokyonight_storm.lua
# Needs to conform to ghostty - https://github.com/folke/tokyonight.nvim/blob/main/extras/ghostty/tokyonight_storm
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
wallpaper="$HOME/Pictures/wallpapers/space-roygbiv.jpg"
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
gnohj_color04=#a3b8c6
gnohj_color02=#b7ce97
gnohj_color03=#a7cfbd
gnohj_color01=#c0aed2
gnohj_color05=#dab183
gnohj_color08=#505e62
gnohj_color06=#dc988e
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
gnohj_color24=#a7cfaf
# Terminal red
gnohj_color11=#da858e
# Terminal white / Text
gnohj_color14=#e9e9e2
# Nvim green (fallback)
gnohj_color40=#b7ce97
# Nvim yellow (fallback)
gnohj_color41=#dab183
#-------------------------------------------------------------------------------
#--                  Nvim
#-------------------------------------------------------------------------------
# Nvim - Lualine across
gnohj_color17=#40474b
# Nvim - Markdown codeblock
gnohj_color07=#222427
# Nvim - line across cursor
gnohj_color13=#536571
# Nvim - Comments / Nvim Ghost Text
gnohj_color09=#9fb7a4
# Nvim - Underline spellcap
gnohj_color12=#ccd19d
# Nvim - Selected text (bg visual)
gnohj_color16=#40474b
# Nvim - Diffview colors
gnohj_color27=#e9e9e2
gnohj_color28=#202325
gnohj_color29=#b7ce97
gnohj_color30=#334330
gnohj_color31=#da858e
gnohj_color32=#433030
gnohj_color33=#dc988e
gnohj_color34=#222427
gnohj_color35=#b8c7cb
gnohj_color36=#a7cfaf
gnohj_color37=#dab183
gnohj_color38=#d9b8ca
#-------------------------------------------------------------------------------
#--               Evergarden blue Structure Variants (muted)
#-- Based on original evergarden blue (#B2CAED) and snow (#AFD9E6)
#-------------------------------------------------------------------------------
# blue variants (from evergarden blue #B2CAED muted)
# darker blue variant
gnohj_color39=#8fa6b9
# lighter blue variant
gnohj_color42=#b8c9d3
# medium blue variant
gnohj_color43=#9cb4c1
# very light blue
gnohj_color44=#c5d1db
# ultra light blue
gnohj_color45=#d0dbe3
# dark blue-gray
gnohj_color46=#7a90a0
# snow/skye variants (from evergarden snow #AFD9E6 and skye #B3E6DB muted)
# snow variant
gnohj_color47=#9bc4ce
# skye variant
gnohj_color48=#a6d1c8
# darker snow
gnohj_color49=#88b8c2
# Additional evergarden functional colors (muted)
# lime variant (from #DBE6AF muted)
gnohj_color50=#c4d2a3
# aqua variant (from #B3E3CA muted)
gnohj_color51=#9bc7af
# purple variant (from #D2BDF3 muted)
gnohj_color52=#bfa8c8
# darker surface (from surface colors)
gnohj_color53=#3d4a4e
#-------------------------------------------------------------------------------
#--               Nvim Lighter markdown headings
#-- # This is based off of Terminal Palette
#-- 4 colors to the right for these ligher headings
#-- https://www.color-hex.com/color/a3b8c6
#-------------------------------------------------------------------------------
# Nvim - Markdown heading 1 - color04
gnohj_color18=#88a1b2
# Nvim - Markdown heading 2 - color02
gnohj_color19=#aabc90
# Nvim - Markdown heading 3 - color03
gnohj_color20=#93b4a6
# Nvim - Markdown heading 4 - color01
gnohj_color21=#b99ac2
# Nvim - Markdown heading 5 - color05
gnohj_color22=#bc9f7a
# Nvim - Markdown heading 6 - color08
gnohj_color23=#424b50
# Nvim - Markdown heading foreground
gnohj_color26=#1e2528
