#!/usr/bin/env bash
# herdr-last-workspace.sh — toggle to the most-recently-used workspace, the
# workspace-level counterpart of herdr's built-in last_pane action (and of tmux's
# `bind Space switch-client -l`).
#
# WHY THIS EXISTS: herdr has no native last_workspace / alternate_workspace action
# as of 0.7.3. The feature request (ogulcancelik/herdr#1327) was auto-closed by the
# repo bot for being filed as an Issue rather than a Discussion and was never
# re-filed, so nothing is planned upstream. This reproduces it with a
# `type = "shell"` keybinding (see dot_config/herdr/config.toml).
#
# HOW: herdr has no workspace-focus event stream (`herdr wait` only waits on pane
# output / agent-status), so a global MRU watcher would need a polling daemon.
# Instead we track "the workspace we last jumped away from" in a state file, updated
# on every press. Because this key is the primary switcher, that yields a clean A<->B
# toggle. If you switch away by other means (prefix+w, previous_workspace) the stored
# id may be stale; the fallback below keeps the press sane (jumps to the other
# workspace) rather than no-opping.
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
command -v "$herdr" >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr"
state_file="$state_dir/last-workspace"
mkdir -p "$state_dir"

list=$("$herdr" workspace list 2>/dev/null) || exit 0

current=$(printf '%s' "$list" \
  | jq -r '.result.workspaces[] | select(.focused) | .workspace_id' 2>/dev/null)
[ -n "$current" ] || exit 0

prev=""
[ -f "$state_file" ] && prev=$(cat "$state_file" 2>/dev/null)

target=""
if [ -n "$prev" ] && [ "$prev" != "$current" ] \
  && printf '%s' "$list" | jq -e --arg w "$prev" \
      '.result.workspaces[] | select(.workspace_id == $w)' >/dev/null 2>&1; then
  target="$prev"
else
  # No usable history (first press, or stored id went stale): jump to the other
  # workspace, highest number first, so a two-workspace setup still toggles cleanly.
  target=$(printf '%s' "$list" | jq -r --arg c "$current" \
    '[.result.workspaces[] | select(.workspace_id != $c)] | sort_by(.number) | last | .workspace_id // empty' 2>/dev/null)
fi

[ -n "$target" ] || exit 0   # only one workspace: nothing to toggle

"$herdr" workspace focus "$target" >/dev/null 2>&1 && printf '%s' "$current" >"$state_file"
