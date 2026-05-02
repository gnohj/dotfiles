#!/usr/bin/env bash
# Agent dashboard launcher — opens (or focuses) a Ghostty window running
# `recon view` as a sidebar. The dashboard window itself is *not* a tmux
# client; it just runs recon directly. When the user selects an agent in
# the recon TUI, a wrapper-tmux shim (~/.local/bin/dashboard-shims/tmux)
# rewrites recon's `tmux switch-client / attach-session` calls so they
# target the *primary* tmux client (the user's main work window) rather
# than the sidebar.
#
# How the new Ghostty window picks up recon (instead of zsh):
# Ghostty's `command =` is set to dashboard-wrapper.sh. That wrapper checks
# /tmp/agent-dashboard-launching — if the marker is fresh, it exec's recon;
# otherwise it exec's /bin/zsh --login. We touch the marker just before
# `open -na Ghostty` so the next Ghostty window becomes the dashboard.
#
# Bound to rctrl + shift - d in skhdrc.

set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"

PRIMARY_FILE="/tmp/agent-dashboard-primary-client"
PRIMARY_WID_FILE="/tmp/agent-dashboard-primary-window"
WID_FILE="/tmp/agent-dashboard.wid"
MARKER="/tmp/agent-dashboard-launching"
DASH_WORKSPACE="T"
DASH_WIDTH_PX=280

# Already running? Look up the saved window-id; if aerospace still tracks
# it, jump to its workspace.
if [ -r "$WID_FILE" ]; then
  saved_wid=$(cat "$WID_FILE" 2>/dev/null)
  if [ -n "$saved_wid" ] && \
     aerospace list-windows --all --format '%{window-id}' 2>/dev/null \
       | grep -qx "$saved_wid"; then
    aerospace workspace "$DASH_WORKSPACE"
    exit 0
  fi
  rm -f "$WID_FILE"
fi

# Capture the primary tmux client tty so the wrapper-tmux shim can redirect
# recon's session-switch calls to it.
PRIMARY=$(tmux list-clients -F '#{client_activity} #{client_tty}' 2>/dev/null \
  | sort -rn | head -n1 | awk '{print $2}')
[ -n "$PRIMARY" ] && echo "$PRIMARY" > "$PRIMARY_FILE"

# Capture the currently-focused aerospace window-id as the primary window so
# the shim can `aerospace focus` it on agent-select. We grab this *before*
# opening Ghostty — at this moment the user's main work window has focus.
PRIMARY_WID=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null | head -n1)
[ -n "$PRIMARY_WID" ] && echo "$PRIMARY_WID" > "$PRIMARY_WID_FILE"

# Drop the marker so dashboard-wrapper.sh runs recon in the next Ghostty
# window instead of zsh.
touch "$MARKER"

# Snapshot existing aerospace window-ids so we can identify the new one.
WINDOWS_BEFORE=$(aerospace list-windows --all --format '%{window-id}' 2>/dev/null | sort)

open -na "Ghostty"
sleep 1.0

WINDOWS_AFTER=$(aerospace list-windows --all --format '%{window-id}' 2>/dev/null | sort)
NEW_WID=$(comm -13 <(echo "$WINDOWS_BEFORE") <(echo "$WINDOWS_AFTER") | head -n1)
if [ -z "$NEW_WID" ]; then
  exit 1
fi

echo "$NEW_WID" > "$WID_FILE"

# Move to leftmost slot in the workspace, then resize to the sidebar width.
# Note: `aerospace move left` returns exit 0 even when the window is already
# at the edge (no `--fail-if-noop` flag exists), so we can't loop on its
# exit code — looping is infinite. Instead we look up the window's index
# in the workspace's left-to-right ordering and move left exactly that many
# times to reach position 0.
aerospace focus --window-id "$NEW_WID" 2>/dev/null
WIN_INDEX=$(aerospace list-windows --workspace "$DASH_WORKSPACE" --format '%{window-id}' 2>/dev/null \
  | grep -n "^${NEW_WID}\$" | head -n1 | cut -d: -f1)
if [ -n "$WIN_INDEX" ] && [ "$WIN_INDEX" -gt 1 ]; then
  for _ in $(seq 1 "$((WIN_INDEX - 1))"); do
    aerospace move left 2>/dev/null
  done
fi
sleep 0.15
aerospace resize --window-id "$NEW_WID" width "$DASH_WIDTH_PX" || true
