#!/usr/bin/env bash
# herdr-new-workspace.sh — glyph-aware replacement for herdr's native new_workspace.
# herdr's built-in create labels a workspace with the bare basename (no 🌳/🌿/📁
# glyph — that convention lives only in herdr-sesh-layout.sh), so a workspace spun
# up from the keybind reads differently than one from the ctrl+t picker. This
# resolves the focused pane's cwd from herdr's socket API and opens it THROUGH the
# layout script, so the glyph + dev layout match the picker path. Bound to prefix+n.
#
# Pure herdr CLI → runs server-side, works local and over --remote. The cwd comes
# from `api snapshot` (single call: focused_pane_id + that pane's cwd) rather than
# $PWD, since type="shell" bindings run detached and don't inherit the pane's dir.
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }

cwd=$("$herdr" api snapshot 2>/dev/null | jq -r '
  .result.snapshot as $s
  | ($s.panes[] | select(.pane_id == $s.focused_pane_id))
  | (.foreground_cwd // .cwd) // empty')
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$HOME"

exec "$HOME/.local/bin/herdr-scripts/herdr-sesh-layout.sh" "$cwd"
