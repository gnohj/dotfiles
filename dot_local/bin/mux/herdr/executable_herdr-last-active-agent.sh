#!/usr/bin/env bash
# herdr-last-active-agent.sh — jump/cycle to the MOST RECENTLY ACTIVE agent. Bound to ctrl+'.
# The recency counterpart of herdr-next-priority-agent.sh (ctrl+;, the blocked->done attention
# queue): that one asks "who wants me?", this one asks "what was I just doing?".
#
# Why this exists rather than a "last done" jump: herdr's `done` self-clears to `idle` the
# moment the pane is seen, so a status-based jump can only ever reach agents you have NOT
# looked at — exactly the set ctrl+; already drains. Ranking by activity TIME instead keeps
# working after the state has decayed, so this still returns you to whatever just finished
# once you have glanced at it.
#
# Recency comes from ~/.local/state/herdr/agent-activity.json (pane_id -> epoch), written by
# herdr-agent-activity.py — the same pass that feeds the sidebar's $act token. The token is a
# FORMATTED string ("8m ago") and so useless for sorting; this reads the raw epochs. Both
# halves run wherever the herdr SERVER runs, so the pair is --remote-safe like the $git poller.
#
# Cycles with the same idiom as herdr-next-priority-agent.sh: find the focused agent's slot in
# the recency order and advance one, so repeat presses walk back through the list instead of
# re-jumping to the same pane. NOTIFIES rather than silently no-op'ing when there is nothing
# to jump to. Pure CLI + a state file → server-side, remote-safe.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"
[ "$(uname)" = Linux ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

herdr="${HERDR_BIN_PATH:-herdr}"
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/herdr/agent-activity.json"
[ -r "$STATE" ] || exec "$herdr" notification show "No activity data" \
  --body "herdr-agent-activity.py has not written a pass yet" >/dev/null 2>&1

# Only agents herdr still reports are candidates, so a closed pane lingering in the state
# file can never be jumped to.
result=$("$herdr" agent list 2>/dev/null | jq -r --slurpfile s "$STATE" '
  (($s[0].panes) // {}) as $ts
  | (.result.agents // .result // []) as $a
  | [ $a[] | select($ts[.pane_id] != null) ]
    | sort_by(-$ts[.pane_id]) as $q
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
  NONE) exec "$herdr" notification show "No agent activity" --body "no agent has a recorded last-activity time" >/dev/null 2>&1 ;;
  SELF) exec "$herdr" notification show "Only active agent" --body "you're already on the most recently active one" >/dev/null 2>&1 ;;
  "")   exit 0 ;;
  *)    exec "$herdr" agent focus "$result" >/dev/null 2>&1 ;;
esac
