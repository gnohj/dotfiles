#!/bin/bash
# Toggle the rbw (Bitwarden) vault-lock indicator.
# `rbw unlocked` exits 0 when the vault is unlocked, non-zero when it is locked
# or the agent isn't running — same signal the old tmux status line used. Show
# the lock glyph only when locked so the bar stays quiet during normal use.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.rbw_lock}"

if rbw unlocked >/dev/null 2>&1; then
  sketchybar --set "$NAME" drawing=off
else
  sketchybar --set "$NAME" drawing=on icon.color="$RED"
fi
