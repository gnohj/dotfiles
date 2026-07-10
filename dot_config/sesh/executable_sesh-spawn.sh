#!/usr/bin/env bash
# The @sesh_spawn protocol in ONE place. Every sesh entry point calls
# `sesh-spawn.sh stamp` immediately before `sesh connect`; the tmux
# session-created handler calls `sesh-spawn.sh fresh` to gate the fast-nvim path
# to real sesh launches (a manual `tmux new-session` never stamps).
#
# This owns the option name (@sesh_spawn) and the freshness window, so they
# aren't scattered across the 4 entry points + the handler. Change them here.
#
# Usage:
#   sesh-spawn.sh stamp   # record "a sesh spawn is happening now"
#   sesh-spawn.sh fresh   # exit 0 if a stamp landed within the window, else 1

export PATH="/opt/homebrew/bin:$PATH"

# 5s leaves margin for a slow sesh resolve (zoxide lookup + new-session) under
# load; at 3s the gate could expire mid-spawn and the fast path silently skipped.
FRESH_WINDOW_SECONDS=5
GATE_LOG="$HOME/.logs/sesh/spawn-gate.log"

_log_reject() {
  mkdir -p "${GATE_LOG%/*}" 2>/dev/null
  echo "$(date '+%Y-%m-%d %H:%M:%S') gate rejected: $1" >> "$GATE_LOG" 2>/dev/null
}

case "${1:-}" in
  stamp)
    tmux set-option -g @sesh_spawn "$(date +%s)" 2>/dev/null
    ;;
  fresh)
    stamp=$(tmux show-options -gv @sesh_spawn 2>/dev/null)
    case "$stamp" in ''|*[!0-9]*) _log_reject "no stamp (manual tmux session?)"; exit 1 ;; esac
    age=$(( $(date +%s) - stamp ))
    { [ "$age" -ge 0 ] && [ "$age" -le "$FRESH_WINDOW_SECONDS" ]; } || { _log_reject "stale stamp: age=${age}s > ${FRESH_WINDOW_SECONDS}s"; exit 1; }
    ;;
  *)
    echo "usage: sesh-spawn.sh {stamp|fresh}" >&2
    exit 2
    ;;
esac
