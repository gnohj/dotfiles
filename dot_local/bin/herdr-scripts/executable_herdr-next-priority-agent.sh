#!/usr/bin/env bash
# herdr-next-priority-agent.sh — jump/cycle to the next BLOCKED agent (one needing input).
# Bound to ctrl+;. herdr's native next_agent walks ALL agents (working/idle too); this
# narrows to just the blocked ones and cycles through them on repeat.
#
# BLOCKED-ONLY on purpose: herdr has no "done" CLI status. Source (src/ui/sidebar.rs) shows
# "done" is a sidebar-only label = (Idle, seen=false), and the `seen` flag is NOT exposed by
# `herdr agent list` / `api snapshot`. So the only attention state a script can target is the
# real enum value "blocked". (For done/idle coverage, use native next_agent on prefix+a.)
#
# Reads `herdr agent list` (JSON), cycles to the blocked agent AFTER the focused one, and —
# instead of silently jumping to itself or doing nothing — NOTIFIES when you're already on the
# only blocked agent, or when none are blocked. Pure CLI → server-side, remote-safe.
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }

result=$("$herdr" agent list 2>/dev/null | jq -r '
  (.result.agents // .result // []) as $a
  | [ $a[] | select(.agent_status == "blocked") ] as $q
  | ($q | length) as $n
  | ([ $a[] | select(.focused == true) | .pane_id ][0] // "") as $cur
  | if $n == 0 then "NONE"
    else
      (([ $q | to_entries[] | select(.value.focused == true) | .key ][0]) // -1) as $i
      | ($q[ (($i + 1) % $n) ].pane_id) as $t
      | (if $t == $cur then "SELF" else $t end)
    end
')

case "$result" in
  NONE) exec "$herdr" notification show "No blocked agents" --body "nothing needs input right now" >/dev/null 2>&1 ;;
  SELF) exec "$herdr" notification show "Only blocked agent" --body "you're already on the one that needs input" >/dev/null 2>&1 ;;
  "")   exit 0 ;;
  *)    exec "$herdr" agent focus "$result" >/dev/null 2>&1 ;;
esac
