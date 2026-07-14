#!/bin/bash
# Toggle the yazi-dedicated kitty quake (quick-access terminal). A SECOND,
# independent quake from the general one (cmd+rctrl+s) — kept separate by
# `--instance-group yazi`, so the two never share a window. Plain kitty with no
# tmux/herdr in front, so yazi image previews render here. Runs yazi directly;
# when yazi quits (`q`) the window closes and the next keypress relaunches it.
#
# Foreground, NOT --detach: kitty's --detach silently fails on this machine (it
# exits 0 but the daemonized window dies before initializing). Running
# foreground lets skhd hold the kitten as a live child, which persists. skhd
# hands us a minimal launchd PATH, so set one that resolves yazi (nix) + kitty.
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

# Open yazi at $HOME by default. Without this it inherits kitty's launch cwd
# (skhd/launchd hands us `/`), which is a useless starting point. Applies on each
# fresh launch — i.e. after you `q` out of yazi and re-toggle; a hidden-then-shown
# quake keeps wherever you'd navigated.
exec /Applications/kitty.app/Contents/MacOS/kitten quick-access-terminal \
  --instance-group yazi \
  --config "$HOME/.config/kitty/quick-access-terminal-yazi.conf" \
  yazi "$HOME"
