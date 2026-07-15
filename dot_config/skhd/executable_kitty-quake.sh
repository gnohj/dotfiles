#!/bin/bash
# General kitty quake (quick-access terminal), skhd cmd+rctrl+s. Plain kitty with
# no tmux/herdr in front, so yazi image previews render here.
# Foreground, NOT --detach: --detach silently dies on this machine before init.
exec /Applications/kitty.app/Contents/MacOS/kitten quick-access-terminal
