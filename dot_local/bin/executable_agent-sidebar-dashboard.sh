#!/usr/bin/env bash
# Agent dashboard launcher — opens (or focuses) a sidebar window running
# the agent-sidebar TUI. Terminal-agnostic: detects the primary terminal
# (Ghostty / kitty) from the focused aerospace window and uses that
# terminal's preferred spawn mechanism so the dashboard window matches the
# user's primary terminal app.
#
# Spawn mechanisms:
#   - Ghostty: drops a marker file, then `open -na Ghostty`. Ghostty's
#     `command =` config points at dashboard-wrapper.sh, which sees the
#     fresh marker and exec's agent-sidebar instead of zsh. (Required
#     because Ghostty drops CLI args from `open -na` when an instance is
#     already running.)
#   - kitty: `open -na kitty --args --title=AgentDash --command=...`. Kitty
#     respects CLI args on every invocation, so no wrapper is needed.
#   - Fallback: prefer kitty if available; else Ghostty.
#
# Bound to rctrl + shift - d in skhdrc.

set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"

PRIMARY_FILE="/tmp/agent-dashboard-primary-client"
PRIMARY_WID_FILE="/tmp/agent-dashboard-primary-window"
WID_FILE="/tmp/agent-dashboard.wid"
MARKER="/tmp/agent-dashboard-launching"
DASH_WORKSPACE="T"
DASH_WIDTH_PX=190

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

# Detect the primary terminal app from the currently-focused window so we
# can spawn a matching dashboard window. Falls back to kitty (cleaner CLI)
# if the focused app isn't a known terminal.
PRIMARY_APP=$(aerospace list-windows --focused --format '%{app-bundle-id}' 2>/dev/null | head -n1)
# Use the wrapper, not the bare script — it sets PATH so `uv` resolves
# even though the spawning terminal inherits a minimal PATH from launchd.
SIDEBAR_BIN="$HOME/.local/bin/agent-sidebar-launch"

case "$PRIMARY_APP" in
  net.kovidgoyal.kitty)
    SPAWN_TERM=kitty
    ;;
  com.mitchellh.ghostty)
    SPAWN_TERM=ghostty
    ;;
  *)
    # Unknown terminal — prefer kitty if available (clean CLI), else Ghostty.
    if [ -d "/Applications/kitty.app" ]; then
      SPAWN_TERM=kitty
    else
      SPAWN_TERM=ghostty
    fi
    ;;
esac

# Snapshot existing aerospace window-ids so we can identify the new one.
WINDOWS_BEFORE=$(aerospace list-windows --all --format '%{window-id}' 2>/dev/null | sort)

case "$SPAWN_TERM" in
  ghostty)
    # Drop the marker so dashboard-wrapper.sh runs agent-sidebar in the
    # next Ghostty window instead of zsh.
    touch "$MARKER"
    open -na "Ghostty"
    ;;
  kitty)
    # Kitty respects CLI args on every invocation, no wrapper needed.
    # Use `-e <cmd>` (not `--command=` which doesn't reach the spawn path
    # via `open -na`).
    open -na kitty --args --title=AgentDash -e "$SIDEBAR_BIN"
    ;;
esac
sleep 1.0

WINDOWS_AFTER=$(aerospace list-windows --all --format '%{window-id}' 2>/dev/null | sort)
NEW_WID=$(comm -13 <(echo "$WINDOWS_BEFORE") <(echo "$WINDOWS_AFTER") | head -n1)
if [ -z "$NEW_WID" ]; then
  exit 1
fi

echo "$NEW_WID" > "$WID_FILE"

# Explicitly move the new window to T (rather than relying on the
# on-window-detected rule, which fires asynchronously and races us).
# Sleep gives aerospace a beat to register the workspace move so the
# subsequent index lookup actually finds the window.
aerospace move-node-to-workspace --window-id "$NEW_WID" "$DASH_WORKSPACE" 2>/dev/null
sleep 0.2

# Move to leftmost slot. aerospace's `list-windows` order is NOT visual
# left-to-right (looks more like focus/insertion order), so we can't index
# off it. Instead we count windows in the workspace and do (N-1) moves —
# `move left` is a safe no-op when already leftmost, so over-moving is
# fine. Using --window-id avoids the focus dance, which is unreliable for
# newly-spawned windows.
WIN_COUNT=$(aerospace list-windows --workspace "$DASH_WORKSPACE" --format '%{window-id}' 2>/dev/null | wc -l | tr -d ' ')
if [ -n "$WIN_COUNT" ] && [ "$WIN_COUNT" -gt 1 ]; then
  for _ in $(seq 1 "$((WIN_COUNT - 1))"); do
    aerospace move --window-id "$NEW_WID" left 2>/dev/null
  done
fi
sleep 0.15
aerospace resize --window-id "$NEW_WID" width "$DASH_WIDTH_PX" || true
