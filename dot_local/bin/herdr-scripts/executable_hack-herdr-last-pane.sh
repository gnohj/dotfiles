#!/usr/bin/env bash
# hack-herdr-last-pane.sh — jump to the previous pane IN THE CURRENT TAB, bound to
# ctrl+b. Replaces herdr's native last_pane, which is GLOBAL — it leaks across
# workspaces and tabs. The herdr-focus-tracker daemon subscribes to the socket's
# pane.focused stream, keeps per-tab pane MRU, and writes the jump target here, so this
# stays isolated to panes within the tab you're on (essentially a within-tab pane
# toggle). Focuses by pane id via `agent focus` (herdr's `pane focus` is direction-only,
# with no focus-by-id). Notifies when there's no prior pane to jump back to (e.g. a
# single-pane tab).
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/hack-herdr-last-pane"

target=""
[ -f "$state" ] && target=$(cat "$state" 2>/dev/null)

if [ -n "$target" ]; then
  "$herdr" agent focus "$target" >/dev/null 2>&1
else
  "$herdr" notification show "No last pane" --body "nothing to jump back to in this tab" >/dev/null 2>&1
fi
