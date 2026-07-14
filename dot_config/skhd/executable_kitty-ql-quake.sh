#!/bin/bash
# ql quake — runs the launcher (`ql` = ~/.config/launcher/launcher-quake.sh,
# LAUNCHER_MODE=herdr) in a kitty quick-access window. Toggled from skhd
# (cmd+rctrl+s). Own --instance-group so it's independent of the yazi/plain quakes.
#
# The launcher is run via an interactive login shell (zsh -l -i -c) so it inherits
# the exact PATH / herdr-socket / worktree env you'd have typing `ql` in a
# terminal — the launcher needs fzf, the herdr client, jq, git, etc. on PATH.
#
# Foreground, NOT --detach: kitty's --detach silently fails on this machine (exits
# 0 but the daemonized window dies before initializing). Running foreground lets
# skhd hold the kitten as a live child, which persists.
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

exec /Applications/kitty.app/Contents/MacOS/kitten quick-access-terminal \
  --instance-group ql \
  --config "$HOME/.config/kitty/quick-access-terminal-ql.conf" \
  /bin/zsh -l -i -c "$HOME/.config/launcher/launcher-quake.sh"
