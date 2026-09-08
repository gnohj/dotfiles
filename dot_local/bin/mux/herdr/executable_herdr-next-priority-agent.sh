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

herdr="${HERDR_BIN_PATH:-herdr}"
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }

# Every workspace's active pane reports focused==true, so anchor on the focused workspace's.
fws=$("$herdr" workspace list 2>/dev/null | jq -r '[ .result.workspaces[] | select(.focused == true) | .workspace_id ][0] // ""')

result=$("$herdr" agent list 2>/dev/null | jq -r --arg fws "$fws" '
  (.result.agents // .result // []) as $a
  | ([ $a[] | select(.agent_status == "blocked") ] + [ $a[] | select(.agent_status == "done") ]) as $q
  | ($q | length) as $n
  | ([ $a[] | select(.focused == true and .workspace_id == $fws) | .pane_id ][0] // "") as $cur
  | if $n == 0 then "NONE"
    else
      (([ $q | to_entries[] | select(.value.pane_id == $cur) | .key ][0]) // -1) as $i
      | ($q[ (($i + 1) % $n) ]) as $t
      | (if $t.pane_id == $cur then "SELF" else $t.pane_id end)
    end
')

case "$result" in
  NONE) exec "$herdr" notification show "No agents need attention" --body "nothing blocked or done right now" >/dev/null 2>&1 ;;
  SELF) exec "$herdr" notification show "Only agent needing attention" --body "you're already on the one that wants you" >/dev/null 2>&1 ;;
  "")   exit 0 ;;
  *)    # agent focus never switches the view to the target's tab; the socket's pane.focus does.
        exec "$HOME/.local/bin/mux/herdr/herdr-focus-pane.sh" "$result" >/dev/null 2>&1 ;;
esac
