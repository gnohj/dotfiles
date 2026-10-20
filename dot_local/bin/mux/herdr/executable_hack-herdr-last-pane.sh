#!/usr/bin/env bash
# hack-herdr-last-pane.sh — jump to the previous pane IN THE CURRENT TAB, bound to
# ctrl+b. Replaces herdr's native last_pane, which is GLOBAL — it leaks across
# workspaces and tabs. The herdr-focus-tracker daemon subscribes to the socket's
# pane.focused stream, keeps per-tab pane MRU, and writes the jump target here, so this
# stays isolated to panes within the tab you're on (essentially a within-tab pane
# toggle). Focuses by pane id through herdr-focus-pane.sh (socket pane.focus): `agent focus`
# takes only panes hosting a live agent, so it silently failed on nvim/fish panes. Notifies
# when there's no prior pane to jump back to (e.g. a single-pane tab).
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"

herdr="${HERDR_BIN_PATH:-herdr}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/hack-herdr-last-pane"

target="" seen=""
[ -f "$state" ] && { read -r target; read -r seen; } <"$state" 2>/dev/null

# A fast second press can beat the tracker's write; it is then one switch behind and $seen is where we came from.
if [ -n "$seen" ]; then
  behind=$("$herdr" pane list 2>/dev/null | jq -r --arg seen "$seen" '.result.panes as $p | ($p[] | select(.focused)) as $cur
    | select($cur.pane_id != $seen and any($p[]; .pane_id == $seen and .tab_id == $cur.tab_id)) | $seen')
  [ -n "$behind" ] && target="$behind"
fi

if [ -n "$target" ]; then
  "$HOME/.local/bin/mux/herdr/herdr-focus-pane.sh" "$target" >/dev/null 2>&1
else
  "$herdr" notification show "No last pane" --body "nothing to jump back to in this tab" >/dev/null 2>&1
fi
