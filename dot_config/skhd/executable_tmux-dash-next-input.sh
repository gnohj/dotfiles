#!/bin/bash
# tmux-dash-next-input.sh — jump to the next agent needing you, no dashboard UI.
# Two-tier priority: Input (needs-you) agents first, then Done (unreviewed) last.
# Bound to rctrl-i via mux-passthrough.sh (gated to a frontmost terminal).
# Uses `tmux-dash json`, the documented API, so it stays in step with the dashboard.

export PATH="/opt/homebrew/bin:$PATH"

td="$HOME/.local/bin/tmux-dash"
[ -x "$td" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# `-L <name>` (or empty) for the focused terminal's server so the jump follows you
# across servers. Unquoted so an empty result expands to nothing.
sock=$("$td" focused-socket 2>/dev/null)

# Target pane by priority: top Input agent, else top Done — in the dashboard's row
# order. pane_target is already a valid `session:window.pane` tmux target.
target=$("$td" $sock json 2>/dev/null | jq -r '
  first(
    (.sessions[] | select(.status == "Input") | .pane_target),
    (.sessions[] | select(.status == "Done")  | .pane_target)
  ) // empty')

[ -n "$target" ] || exit 0

# Focus the exact agent pane deterministically: switch-client alone often lands on
# the window's previously-active (sibling) pane, so select-window + select-pane
# first (both persist server-side), THEN switch-client.
sess=${target%%:*}
win=${target#*:}; win=${win%%.*}
tmux $sock select-window -t "${sess}:${win}" 2>/dev/null
tmux $sock select-pane   -t "$target"        2>/dev/null
tmux $sock switch-client -t "$sess"          2>/dev/null
