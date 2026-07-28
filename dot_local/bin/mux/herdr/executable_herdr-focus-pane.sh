#!/usr/bin/env bash
# Focus a herdr pane by id via the socket's pane.focus — no CLI can (`pane focus` is direction-only; `agent focus` takes only panes hosting a live agent).
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"
case "${OSTYPE:-}" in linux*) PATH="/home/linuxbrew/.linuxbrew/bin:$PATH" ;; esac
herdr="${HERDR_BIN_PATH:-herdr}"
sock="${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock}"

pane="${1:?herdr-focus-pane: missing <pane_id>}"

# nc not python3 (~32ms interpreter start per keypress); no -N since macOS nc lacks it and the server closes anyway.
focus_via_socket() {
  [ -S "$sock" ] || return 1
  command -v nc >/dev/null 2>&1 || return 1
  # pane_id is interpolated into JSON unescaped, so restrict it to the real id charset (wJ:p1).
  case "$pane" in ''|*[!A-Za-z0-9_:-]*) return 1 ;; esac
  local req resp
  req="{\"id\":\"focus-pane\",\"method\":\"pane.focus\",\"params\":{\"pane_id\":\"$pane\"}}"
  resp=$(printf '%s\n' "$req" | nc -U -w 5 "$sock" 2>/dev/null)
  case "$resp" in *'"result"'*) return 0 ;; *) return 1 ;; esac
}

focus_via_socket && exit 0

# Fallback: at least land on the right workspace/tab.
command -v jq >/dev/null 2>&1 || exit 1
info="$("$herdr" pane get "$pane" 2>/dev/null)" || exit 1
ws="$(printf '%s' "$info" | jq -r '.result.pane.workspace_id // empty' 2>/dev/null)"
tab="$(printf '%s' "$info" | jq -r '.result.pane.tab_id // empty' 2>/dev/null)"
[ -n "$ws" ] || exit 1

"$herdr" workspace focus "$ws" >/dev/null 2>&1 || true
[ -n "$tab" ] && "$herdr" tab focus "$tab" >/dev/null 2>&1 || true
exit 0
