#!/usr/bin/env bash
# mux-window.sh — open a command in a new multiplexer window/tab, tmux OR herdr.
#
# The shell-side counterpart of nvim's config/mux.lua. gh-dash keybindings (and
# any other shell caller) used to shell out to `tmux new-window` directly, so
# under herdr — where panes have no backing tmux server ($TMUX unset) — those
# windows silently failed and the review workflow only ever showed the single
# gh-dash tab. This detects the live multiplexer and dispatches so the same
# binding opens a real tab under both tmux (the Mac, off-herdr) and herdr.
#
#   mux-window.sh [OPTIONS] <name> <cwd> <command>
#
# Options:
#   --print-pane        print the new pane id to stdout (for HUNK_PANE capture)
#   --env KEY=VALUE     set an env var in the new window (repeatable)
#   --popup             prefer a modal popup (tmux display-popup); herdr has no
#                       popup CLI, so it falls back to a normal focused tab
#   --popup-size WxH    popup size, tmux only (default 80%x90%)
#
# tmux vs herdr command model (same rationale as config/mux.lua): tmux runs the
# command AS the window process, so the window closes on exit. herdr spawns a
# persistent shell and `pane run` types into it, so we append "; exit" to close
# the pane/tab when the command finishes — matching tmux's close-on-exit.
set -uo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/share/mise/shims:$PATH"
herdr="${HERDR_BIN_PATH:-herdr}"

print_pane=""
popup=""
popup_size="80%x90%"
envs=()

while [ $# -gt 0 ]; do
  case "$1" in
    --print-pane) print_pane=1; shift ;;
    --popup)      popup=1; shift ;;
    --popup-size) popup_size="$2"; shift 2 ;;
    --env)        envs+=("$2"); shift 2 ;;
    --)           shift; break ;;
    -*)           echo "mux-window: unknown option $1" >&2; exit 2 ;;
    *)            break ;;
  esac
done

name="${1:?mux-window: missing <name>}"
cwd="${2:?mux-window: missing <cwd>}"
command="${3:?mux-window: missing <command>}"
cwd="${cwd/#\~/$HOME}"

mux_kind() {
  if [ -n "${HERDR_SOCKET_PATH:-}" ]; then echo herdr
  elif [ -n "${TMUX:-}" ]; then echo tmux
  else echo none; fi
}

open_herdr() {
  command -v jq >/dev/null 2>&1 || { echo "mux-window: jq required for herdr" >&2; exit 1; }
  local args=(tab create --cwd "$cwd" --label "$name" --focus)
  local e
  for e in "${envs[@]:-}"; do [ -n "$e" ] && args+=(--env "$e"); done
  local out pane tab_id num
  out="$("$herdr" "${args[@]}" 2>/dev/null)"
  pane="$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id // empty' 2>/dev/null)"
  [ -n "$pane" ] || { echo "mux-window: herdr tab create failed" >&2; exit 1; }
  # Prefix the tab label with its number ("2.🐙 #19156"). A custom label replaces
  # herdr's default number badge, so re-add "<number>." to match the numbered
  # sesh-layout tabs — every programmatically created tab carries its number.
  tab_id="$(printf '%s' "$out" | jq -r '.result.tab.tab_id // empty' 2>/dev/null)"
  num="$(printf '%s' "$out" | jq -r '.result.tab.number // empty' 2>/dev/null)"
  [ -n "$tab_id" ] && [ -n "$num" ] && "$herdr" tab rename "$tab_id" "$num.$name" >/dev/null 2>&1
  "$herdr" pane run "$pane" "$command; exit" >/dev/null 2>&1
  [ -n "$print_pane" ] && printf '%s\n' "$pane"
  return 0
}

open_tmux() {
  # Modal popup: only meaningful without pane capture.
  if [ -n "$popup" ] && [ -z "$print_pane" ]; then
    local pw="${popup_size%x*}" ph="${popup_size#*x}"
    tmux display-popup -d "$cwd" -w "$pw" -h "$ph" -E "$command"
    return 0
  fi
  local args=(new-window -n "$name" -c "$cwd")
  [ -n "$print_pane" ] && args+=(-P -F '#{pane_id}')
  local e
  for e in "${envs[@]:-}"; do [ -n "$e" ] && args+=(-e "$e"); done
  args+=("$command")
  tmux "${args[@]}"
}

case "$(mux_kind)" in
  herdr) open_herdr ;;
  tmux)  open_tmux ;;
  none)  echo "mux-window: no tmux or herdr session detected" >&2; exit 1 ;;
esac
