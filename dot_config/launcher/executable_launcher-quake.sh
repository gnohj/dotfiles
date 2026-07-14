#!/usr/bin/env bash
# Herdr / standalone entry point for the launcher.
#
# Same menu, registry, and actions as launcher.sh (the tmux-popup entry) — this
# adds NO launcher logic of its own. It only flips LAUNCHER_MODE=herdr, which
# routes window-opening / pane-context actions to herdr's socket API instead of
# tmux. Meant to run inline with no tmux around it: the ghostty quake terminal or
# any plain shell.
#
# Entry-point map:
#   launcher.sh (alias `launcher`)                             (LAUNCHER_MODE=tmux)
#   this file  (alias `ql`)          → launcher.sh             (LAUNCHER_MODE=herdr)
exec env LAUNCHER_MODE=herdr "$HOME/.config/launcher/launcher.sh" "$@"
