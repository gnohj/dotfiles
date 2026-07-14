#!/usr/bin/env bash
# herdr-next-blocked.sh — focus the next agent that is BLOCKED (waiting on input:
# permission prompts, questions, tool approvals, etc.), cycling through them.
#
# WHY: herdr's native next_agent cycles ALL agents in sidebar order (blocked,
# working, idle, done) — a browse-the-queue key, not a jump-to-attention key. Even
# with ui.agent_panel_sort = "priority" it still stops on every agent. This re-scans
# the live agent list on every press and focuses ONLY blocked agents, so a re-blocked
# agent reappears immediately — the herdr analog of the tmux-dash split-view `i` jump.
#
# Bound via a `type = "shell"` keybinding in dot_config/herdr/config.toml. Uses
# terminal_id as the focus target (herdr agent focus accepts terminal ids).
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
command -v "$herdr" >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

list=$("$herdr" agent list 2>/dev/null) || exit 0

# Blocked agents' terminal ids in a stable order (workspace, then terminal) so the
# cycle is deterministic press-to-press.
blocked=$(printf '%s' "$list" | jq -r '
  [.result.agents[] | select(.agent_status == "blocked")]
  | sort_by(.workspace_id, .terminal_id)
  | .[].terminal_id' 2>/dev/null)

if [ -z "$blocked" ]; then
  "$herdr" notification show "No blocked agents" --body "all clear" --sound none >/dev/null 2>&1
  exit 0
fi

# The currently focused agent's terminal id (may or may not be blocked).
current=$(printf '%s' "$list" \
  | jq -r 'first(.result.agents[] | select(.focused) | .terminal_id) // empty' 2>/dev/null)

# Next blocked terminal after the focused one, wrapping around. If the focused agent
# isn't in the blocked set (e.g. you're in a working pane), jump to the first blocked.
target=$(printf '%s\n' "$blocked" | awk -v cur="$current" '
  { ids[NR] = $0 }
  END {
    if (NR == 0) exit
    idx = 0
    for (i = 1; i <= NR; i++) if (ids[i] == cur) { idx = i; break }
    if (idx == 0) { print ids[1]; exit }
    print ids[(idx % NR) + 1]
  }')

[ -n "$target" ] || exit 0
"$herdr" agent focus "$target" >/dev/null 2>&1
