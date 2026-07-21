#!/bin/bash
# tmux-dash-next-input.sh — jump to the next agent needing you, no dashboard UI.
# Two-tier priority: Input (needs-you) agents first, then Done (unreviewed) last.
# Bound to ctrl+; (ghostty/kitty expand it to `C-a ,` → tmux `bind ,`), run
# server-side so it works local + VPS. Uses `tmux-dash json`, the documented API,
# so it stays in step with the dashboard.
#
# The bind passes the invoking client as $TD_CLIENT (`#{client_name}`) so the
# final switch-client pins the right client — a backgrounded `run-shell -b` loses
# its invocation context and would otherwise guess.

export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/bin:/bin:$PATH"

td="$HOME/.local/bin/tmux-dash"
[ -x "$td" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# `-L <name>` (or empty) for the focused terminal's server so the jump follows you
# across servers. Unquoted so an empty result expands to nothing.
sock=$("$td" focused-socket 2>/dev/null)

# Target pane by priority: top Input agent, else top Done — in the dashboard's row
# order. pane_target is already a valid `session:window.pane` tmux target. Retry a
# few times: `json` prefers the daemon's ≤full_ms snapshot, so a press landing mid
# refresh (right as an agent flips to Done/Input) can briefly read stale — a short
# re-query rides that out instead of silently missing.
target=""
for _ in 1 2 3; do
  target=$("$td" $sock json 2>/dev/null | jq -r '
    first(
      (.sessions[] | select(.status == "Input") | .pane_target),
      (.sessions[] | select(.status == "Done")  | .pane_target)
    ) // empty')
  [ -n "$target" ] && break
  sleep 0.15
done

# No agent waiting: flash a confirmation. This makes a keypress that *fired but
# found nothing* distinguishable from one that *never reached tmux* (a keyboard-
# layer miss shows nothing at all) — so "it did nothing" is diagnosable.
if [ -z "$target" ]; then
  tmux $sock display-message "✓ no agent needs you" 2>/dev/null
  exit 0
fi

# Focus the exact agent pane deterministically: switch-client alone often lands on
# the window's previously-active (sibling) pane, so select-window + select-pane
# first (both persist server-side), THEN switch-client — pinned to the invoking
# client when the bind supplied it.
sess=${target%%:*}
win=${target#*:}; win=${win%%.*}
tmux $sock select-window -t "${sess}:${win}" 2>/dev/null
tmux $sock select-pane   -t "$target"        2>/dev/null
if [ -n "$TD_CLIENT" ]; then
  tmux $sock switch-client -c "$TD_CLIENT" -t "$sess" 2>/dev/null
else
  tmux $sock switch-client -t "$sess" 2>/dev/null
fi
