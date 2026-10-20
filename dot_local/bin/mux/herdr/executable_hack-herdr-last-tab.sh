#!/usr/bin/env bash
# hack-herdr-last-tab.sh — jump to the previous tab in the current workspace (MRU
# toggle), bound to ctrl+space. The real MRU is maintained by the herdr-focus-tracker
# daemon, which subscribes to the socket's tab.focused event stream and writes the
# jump target here. That's why this now catches number-key nav (ctrl+1/2/3), the
# picker, and the mouse — not just ctrl+space presses, which the old press-based
# version was blind to. Notifies when there's no prior tab to jump back to.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"

herdr="${HERDR_BIN_PATH:-herdr}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/hack-herdr-last-tab"

target="" seen=""
[ -f "$state" ] && { read -r target; read -r seen; } <"$state" 2>/dev/null

# A fast second press can beat the tracker's write; it is then one switch behind and $seen is where we came from.
if [ -n "$seen" ]; then
  behind=$("$herdr" tab list 2>/dev/null | jq -r --arg seen "$seen" '.result.tabs as $t | ($t[] | select(.focused)) as $cur
    | select($cur.tab_id != $seen and any($t[]; .tab_id == $seen and .workspace_id == $cur.workspace_id)) | $seen')
  [ -n "$behind" ] && target="$behind"
fi

if [ -n "$target" ]; then
  "$herdr" tab focus "$target" >/dev/null 2>&1
else
  "$herdr" notification show "No last tab" --body "no history to jump back to" >/dev/null 2>&1
fi
