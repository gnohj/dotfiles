#!/usr/bin/env bash
# herdr-next-priority-agent.sh — jump/cycle the ATTENTION QUEUE: blocked agents first, then
# done ones. Bound to ctrl+;. herdr's native next_agent walks ALL agents (working/idle too);
# this narrows to just the two states that actually want you and cycles them on repeat.
#
# Was blocked-only until herdr 0.7.5. The old constraint — "done" being a sidebar-only label
# for (Idle, seen=false), with `seen` not exposed — no longer holds: `done` is now a first-class
# value of the AgentStatus enum that `agent list` itself returns (verified against `herdr api
# schema`: AgentInfo.agent_status -> enum [idle, working, blocked, done, unknown], and observed
# live on a background agent). So the queue can finally be what its keybinding always claimed.
#
# Ordering is blocked-before-done deliberately: blocked is someone waiting on YOU, done is
# merely finished. Note `done` self-clears to `idle` once the pane is seen, so the queue
# drains as you walk it rather than needing a dismiss step.
#
# Reads `herdr agent list` (JSON), cycles to the queued agent AFTER the focused one, and —
# instead of silently jumping to itself or doing nothing — NOTIFIES when you're already on the
# only one needing attention, or when none do. Pure CLI → server-side, remote-safe.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"
[ "$(uname)" = Linux ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

herdr="${HERDR_BIN_PATH:-herdr}"
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }

result=$("$herdr" agent list 2>/dev/null | jq -r '
  (.result.agents // .result // []) as $a
  | ([ $a[] | select(.agent_status == "blocked") ] + [ $a[] | select(.agent_status == "done") ]) as $q
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
  NONE) exec "$herdr" notification show "No agents need attention" --body "nothing blocked or done right now" >/dev/null 2>&1 ;;
  SELF) exec "$herdr" notification show "Only agent needing attention" --body "you're already on the one that wants you" >/dev/null 2>&1 ;;
  "")   exit 0 ;;
  *)    exec "$herdr" agent focus "$result" >/dev/null 2>&1 ;;
esac
