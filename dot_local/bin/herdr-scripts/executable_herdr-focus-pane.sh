#!/usr/bin/env bash
# Focus a herdr pane by id — `pane focus` is direction-only, so go via `agent focus`.
set -uo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/share/mise/shims:$PATH"
[ "$(uname)" = Linux ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
herdr="${HERDR_BIN_PATH:-herdr}"

pane="${1:?herdr-focus-pane: missing <pane_id>}"

"$herdr" agent focus "$pane" >/dev/null 2>&1 && exit 0

# Fallback lands on the right tab if agent focus ever stops taking bare pane ids.
command -v jq >/dev/null 2>&1 || exit 1
info="$("$herdr" pane get "$pane" 2>/dev/null)" || exit 1
ws="$(printf '%s' "$info" | jq -r '.result.pane.workspace_id // empty' 2>/dev/null)"
tab="$(printf '%s' "$info" | jq -r '.result.pane.tab_id // empty' 2>/dev/null)"
[ -n "$ws" ] || exit 1

"$herdr" workspace focus "$ws" >/dev/null 2>&1 || true
[ -n "$tab" ] && "$herdr" tab focus "$tab" >/dev/null 2>&1 || true
exit 0
