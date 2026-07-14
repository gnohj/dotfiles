#!/bin/bash
# General kitty quake (quick-access terminal). Toggled from skhd (cmd+rctrl+s).
# Plain kitty with no tmux/herdr in front, so yazi image previews render here.
#
# Foreground, NOT --detach: kitty's --detach silently fails on this machine — it
# exits 0 but the daemonized window dies before it initializes (empty
# --detached-log, no persistent process). Running foreground lets skhd hold the
# kitten as a live child, which persists correctly. skhd handles long-running
# command children fine; a second press spawns a new kitten that toggles this
# instance and exits.
exec /Applications/kitty.app/Contents/MacOS/kitten quick-access-terminal
