#!/usr/bin/env bash
# hack-herdr-last-workspace.sh — jump to the most-recently-used previous workspace
# (MRU toggle), bound to ctrl+enter. The real MRU is maintained by the
# herdr-focus-tracker daemon, which subscribes to the socket's workspace.focused
# event stream and writes the jump target here — so this catches every workspace
# switch (prefix+s, the ctrl+t picker, the mouse, ctrl+enter itself), not just
# ctrl+enter presses. Notifies when there's no prior workspace to jump back to.
# herdr can't distinguish left/right ctrl, so "rctrl+enter" collapses to ctrl+enter.
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/hack-herdr-last-workspace"

target=""
[ -f "$state" ] && target=$(cat "$state" 2>/dev/null)

if [ -n "$target" ]; then
  "$herdr" workspace focus "$target" >/dev/null 2>&1
else
  "$herdr" notification show "No last workspace" --body "no history to jump back to" >/dev/null 2>&1
fi
