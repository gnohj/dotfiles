#!/usr/bin/env bash
# herdr-next-priority-agent.sh — jump to the next agent that needs you, in priority
# order (blocked/needs-input first, then done), cycling through them on repeat. herdr's
# native next_agent walks ALL agents (including working/idle); this narrows to the ones
# actually demanding attention. Bound to ctrl+; (mirrors the tmux-dash-next-input jump).
#
# Reads `herdr agent list` (JSON), builds the priority queue (blocked then done), and
# focuses the entry AFTER the currently-focused one (cyclic) — or the first entry if
# focus isn't on a priority agent. herdr's status enum is idle|working|blocked|done
# (per `agent wait --status`); "blocked" is the needs-input state. Pure CLI, so it runs
# server-side and is remote-safe.
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }

target=$("$herdr" agent list 2>/dev/null | jq -r '
  (.result.agents // .result // []) as $a
  | ([ $a[] | select(.agent_status == "blocked") ]
     + [ $a[] | select(.agent_status == "done") ]) as $q
  | ($q | length) as $n
  | if $n == 0 then empty
    else
      (([ $q | to_entries[] | select(.value.focused == true) | .key ] | first) // -1) as $i
      | $q[ (($i + 1) % $n) ].pane_id
    end
')

[ -n "$target" ] || exit 0
exec "$herdr" agent focus "$target" >/dev/null 2>&1
