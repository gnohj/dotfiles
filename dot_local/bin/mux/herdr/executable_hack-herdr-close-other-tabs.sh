#!/usr/bin/env bash
# hack-herdr-close-other-tabs.sh — close every tab but the first in the CURRENT
# workspace, bound to prefix+0 (ctrl+0). HACK: herdr has no "close other tabs"
# action; `herdr tab --help` exposes only `close <tab_id>`, so this reads the tab
# list once and closes the siblings by id. Mirrors the tmux `bind 0 kill-window
# -a -t :=1` sweep, which is what ctrl+0 hits in the tmux world.
# Scoped to the focused workspace so the gh-dash review tabs go without touching
# the other open workspaces. Keeps the LOWEST-numbered tab rather than hardcoding
# number 1, so it still works after tab 1 has been closed (where tmux's `:=1`
# would just error out).
set -uo pipefail

# A type=shell keybinding runs with a MINIMAL PATH, so `env bash` finds macOS's bash 3.2
# (no mapfile) and /usr/bin/jq rather than the nix ones - hence the portable read loop below.
. "$HOME/.local/bin/mux/shared/mux-env.sh"
[ "$(uname)" = Linux ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
herdr="${HERDR_BIN_PATH:-herdr}"

# One-line breadcrumb, overwritten each run: a keybind that silently no-ops is otherwise
# indistinguishable from one that never fired (herdr logs neither).
trace="${XDG_STATE_HOME:-$HOME/.local/state}/herdr/close-other-tabs.last"
mkdir -p "$(dirname "$trace")" 2>/dev/null
note() { printf '%s %s\n' "$(date '+%F %T')" "$*" >"$trace"; }
note "invoked herdr=$herdr jq=$(command -v jq || echo MISSING)"

tabs=$("$herdr" tab list 2>/dev/null)
if [ -z "$tabs" ]; then
  note "aborted: 'tab list' returned nothing (herdr not on PATH?)"
  exit 0
fi

workspace=$(jq -r '.result.tabs[] | select(.focused) | .workspace_id' <<<"$tabs" 2>/dev/null | head -1)
if [ -z "$workspace" ] || [ "$workspace" = "null" ]; then
  note "aborted: no focused workspace in 'tab list'"
  "$herdr" notification show "Close other tabs" --body "no focused workspace" >/dev/null 2>&1
  exit 0
fi

keep=$(jq -r --arg w "$workspace" '[.result.tabs[] | select(.workspace_id == $w)] | sort_by(.number) | .[0].tab_id' <<<"$tabs" 2>/dev/null)

doomed=()
while IFS= read -r tab_id; do
  [ -n "$tab_id" ] && doomed+=("$tab_id")
done < <(jq -r --arg w "$workspace" --arg keep "$keep" '.result.tabs[] | select(.workspace_id == $w and .tab_id != $keep) | .tab_id' <<<"$tabs" 2>/dev/null)

if [ "${#doomed[@]}" -eq 0 ]; then
  note "nothing to close: workspace=$workspace keep=$keep"
  "$herdr" notification show "Close other tabs" --body "only one tab here" >/dev/null 2>&1
  exit 0
fi

note "closing ${#doomed[@]} in $workspace, keeping $keep: ${doomed[*]}"
for tab in "${doomed[@]}"; do
  "$herdr" tab close "$tab" >/dev/null 2>&1
done

"$herdr" tab focus "$keep" >/dev/null 2>&1
