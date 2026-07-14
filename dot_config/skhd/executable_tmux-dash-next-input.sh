#!/bin/bash
# tmux-dash-next-input.sh — jump straight to the next agent that needs you, with
# NO dashboard UI. Two-tier priority: agents waiting for Input (needs-you) come
# first, then Done (finished, unreviewed) as a last tier. This extends tmux-dash's
# built-in `i` key (which is Input-only) so one keypress keeps cycling the blocked
# agents, then sweeps up finished ones once nothing is left blocked — without ever
# drawing the popup.
#
# Bound to rctrl-i via mux-passthrough.sh, which gates it to a frontmost terminal
# so a stray press in Chrome/Slack doesn't silently reshuffle your tmux client.
#
# `tmux-dash json` is the documented script API and the same source of truth the
# dashboard renders from, so this stays in step with its Input/Done detection.

export PATH="/opt/homebrew/bin:$PATH"

td="$HOME/.local/bin/tmux-dash"
[ -x "$td" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# `-L <name>` (or empty) for whichever server the focused terminal shows, so the
# jump follows you across personal/work/herdr servers — same inference the
# dashboard popup uses. Unquoted so an empty result expands to nothing.
sock=$("$td" focused-socket 2>/dev/null)

# Target pane, by priority: every Input (needs-you) agent in the dashboard's own
# row order, THEN every Done (finished, unreviewed) agent. first() over the two
# concatenated streams yields the top Input, or — when nothing needs input — the
# top Done. Repeated presses advance as agents change state (a handled Input
# leaves the tier; a reviewed Done flips to Idle). pane_target is already a valid
# `session:window.pane` tmux target (the TUI switches to it verbatim), untouched.
target=$("$td" $sock json 2>/dev/null | jq -r '
  first(
    (.sessions[] | select(.status == "Input") | .pane_target),
    (.sessions[] | select(.status == "Done")  | .pane_target)
  ) // empty')

[ -n "$target" ] || exit 0

# Focus the EXACT agent pane, deterministically. switch-client -t "sess:win.pane"
# switches the session but frequently leaves the client on the window's previously
# active pane — so you land on a sibling (often non-agent) pane. select-pane only
# sets the active pane WITHIN its window and does NOT change the current window,
# so both are needed: make the window current, focus the pane in it (both persist
# server-side even before the client attaches), THEN switch the client.
sess=${target%%:*}
win=${target#*:}; win=${win%%.*}
tmux $sock select-window -t "${sess}:${win}" 2>/dev/null
tmux $sock select-pane   -t "$target"        2>/dev/null
tmux $sock switch-client -t "$sess"          2>/dev/null
