#!/bin/bash

LOG_DIR="$HOME/.logs/skhd"
mkdir -p "$LOG_DIR"
exec 2>"$LOG_DIR/sesh-switcher-debug.log"
set -x
date >>"$LOG_DIR/sesh-switcher-called.log"

export PATH="/opt/homebrew/bin:$PATH"

# Nix packages (fzf, fd, tmux) are in PATH via nix-daemon.sh

export TERM="xterm-256color"

echo "About to run tmux command" >>"$LOG_DIR/sesh-switcher-called.log"

# Target the tmux server you're currently looking at (personal/work/default), not
# always the default socket, so sesh follows you across servers. tmux-dash prints
# `-L <name>` (or empty) for the focused server; sesh inside the popup then inherits
# $TMUX and lists/connects on that server. (The tmux status-line click path opens
# the same popup directly, so it doesn't need this out-of-tmux socket detection.)
TD_SOCK="$("$HOME/.local/bin/tmux-dash" focused-socket 2>/dev/null)"

# The picker UI lives in the shared body script so the hotkey and the status-line
# click stay identical; here we just place the popup on the focused server.
tmux $TD_SOCK display-popup -E -w 28% -h 40% -b none "$HOME/.config/tmux/sesh-popup.sh"

echo "Finished running tmux command" >>"$LOG_DIR/sesh-switcher-called.log"
