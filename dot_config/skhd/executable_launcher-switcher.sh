#!/bin/bash

# Omarchy-style launcher popup, placed on the tmux server you're currently
# looking at (default / personal / work / herdr) — not always the default
# socket. Mirrors sesh-switcher.sh so rctrl-i follows you across servers,
# including into the `-L herdr` wrapper where the herdr client runs. Without
# this, `tmux display-popup` targets the default socket and the popup never
# appears over herdr.

export PATH="/opt/homebrew/bin:$PATH"
export TERM="xterm-256color"

# tmux-dash prints `-L <name>` (or empty) for the focused server.
TD_SOCK="$("$HOME/.local/bin/tmux-dash" focused-socket 2>/dev/null)"

tmux $TD_SOCK display-popup -E -w 55% -h 55% "$HOME/.config/launcher/launcher.sh"
