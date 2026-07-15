#!/bin/bash
# Yazi-dedicated kitty quake, a SECOND independent quake (kept separate via
# `--instance-group yazi`). Plain kitty, no tmux/herdr, so image previews render.
# Foreground, NOT --detach: --detach silently dies on this machine before init.
# skhd hands us a minimal launchd PATH, so set one resolving yazi (nix) + kitty.
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

# Open yazi at $HOME; otherwise it inherits skhd/launchd's cwd (`/`). Applies on
# each fresh launch (after you `q` out and re-toggle).
exec /Applications/kitty.app/Contents/MacOS/kitten quick-access-terminal \
  --instance-group yazi \
  --config "$HOME/.config/kitty/quick-access-terminal-yazi.conf" \
  yazi "$HOME"
