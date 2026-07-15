#!/bin/bash
# ql quake: runs the launcher in a kitty quick-access window (skhd cmd+rctrl+s),
# via interactive login shell (zsh -l -i -c) so it inherits PATH/herdr-socket/env.
# Foreground, NOT --detach: --detach silently dies on this machine before init.
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

exec /Applications/kitty.app/Contents/MacOS/kitten quick-access-terminal \
  --instance-group ql \
  --config "$HOME/.config/kitty/quick-access-terminal-ql.conf" \
  /bin/zsh -l -i -c "$HOME/.config/launcher/launcher-quake.sh"
