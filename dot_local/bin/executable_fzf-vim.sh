#!/usr/bin/env bash
# fzf-vim.sh — wraps fzf with vim-like normal/insert mode
# Usage: some-command | fzf-vim.sh [fzf extra args...]
# Outputs the selected line to stdout
# Caller args are passed through; modal binds are appended last (take priority)

set -euo pipefail

# Buffer stdin so the loop can re-feed fzf on mode switch
INPUT=$(cat)

extra_args=("$@")
mode="${FZF_VIM_MODE:-normal}"

# Optional status header, pinned to the top (--header-first). Two opt-in forms;
# every other picker sets neither and keeps --no-header (unchanged):
#   FZF_VIM_HEADER_CMD  a command, re-run LIVE: via transform-header on start +
#                       every focus change, AND on an idle timer (fzf --listen +
#                       a background poster) — so a status badge (e.g. the active
#                       mux) stays fresh even when the persistent quake sits idle
#                       with no interaction. Interval: FZF_VIM_HEADER_POLL (def 5s).
#   FZF_VIM_HEADER      a static string.
# transform-header/focus/--listen need fzf >= 0.38 (nix ships current on both OSes).
_poster_pid=""
_port_file=""
if [ -n "${FZF_VIM_HEADER_CMD:-}" ]; then
  _port_file=$(mktemp -t fzf-vim-port.XXXXXX)
  header_args=(--header-first --listen
    --bind "start:transform-header($FZF_VIM_HEADER_CMD)+execute-silent(printf '%s' \"\$FZF_PORT\" >|$_port_file)"
    --bind "focus:transform-header($FZF_VIM_HEADER_CMD)")
  # Idle poster: refresh the header on a timer via fzf's --listen HTTP API, even
  # with zero interaction. Re-reads the port each tick so it follows the current
  # fzf across mode switches. Best-effort — silently absent without curl.
  if command -v curl >/dev/null 2>&1; then
    (
      set +e # best-effort: a dead port during a mode-switch must not kill the loop
      interval="${FZF_VIM_HEADER_POLL:-5}"
      while :; do
        sleep "$interval"
        port=$(cat "$_port_file" 2>/dev/null)
        [ -n "$port" ] && curl -sS -XPOST "localhost:$port" \
          -d "transform-header($FZF_VIM_HEADER_CMD)" >/dev/null 2>&1
      done
    ) &
    _poster_pid=$!
  fi
elif [ -n "${FZF_VIM_HEADER:-}" ]; then
  header_args=(--header "$FZF_VIM_HEADER" --header-first)
else
  header_args=(--no-header)
fi

# Reset cursor + tear down the idle poster / its port file on exit.
trap '
  printf "\e[0 q" >/dev/tty 2>/dev/null
  [ -n "$_poster_pid" ] && kill "$_poster_pid" 2>/dev/null
  [ -n "$_port_file" ] && rm -f "$_port_file"
' EXIT

# Clear screen before first fzf to prevent bleed from previous picker
printf '\e[2J\e[H' >/dev/tty 2>/dev/null || true

while true; do
  fzf_out=""
  fzf_rc=0

  if [[ "$mode" == "normal" ]]; then
    printf '\e[2 q' >/dev/tty
    fzf_out=$(printf "%s\n" "$INPUT" | fzf \
      "${extra_args[@]}" \
      --reverse --no-clear --no-multi \
      --disabled \
      --bind 'change:clear-query' \
      "${header_args[@]}" \
      --border-label ' NORMAL  j/k  G/g  i→insert  esc→quit ' \
      --expect=enter,i,esc,ctrl-c \
      --bind 'j:down,k:up' \
      --bind 'G:last,g:first' \
      --bind 'd:half-page-down,u:half-page-up' \
      --bind 'enter:accept,i:accept' \
      --bind 'esc:abort') || fzf_rc=$?
  else
    # Optional: callers can supply a richer corpus via FZF_VIM_INSERT_INPUT
    # so insert mode searches a larger set (e.g. flattened submenu leaves)
    # while normal mode shows only the curated top-level list.
    insert_input="${FZF_VIM_INSERT_INPUT:-$INPUT}"
    printf '\e[5 q' >/dev/tty
    fzf_out=$(printf "%s\n" "$insert_input" | fzf \
      "${extra_args[@]}" \
      --reverse --no-clear --no-multi \
      "${header_args[@]}" \
      --tiebreak=index \
      --border-label ' INSERT  type to filter  esc→normal ' \
      --expect=enter,esc,ctrl-c \
      --bind 'enter:accept' \
      --bind 'esc:abort') || fzf_rc=$?
  fi

  if [[ $fzf_rc -ne 0 && -z "$fzf_out" ]]; then
    key="esc"
    sel=""
  else
    key=$(printf "%s\n" "$fzf_out" | head -n1)
    sel=$(printf "%s\n" "$fzf_out" | sed -n '2p')
  fi

  # Ctrl+C is a hard quit from EITHER mode. fzf runs the terminal in raw mode, so
  # ^C is delivered as a keystroke (no SIGINT is generated) — we capture it via
  # --expect and exit 130 so callers can tell it apart from esc (exit 1 = go
  # back / redraw). Esc stays soft (normal→quit-with-1, insert→back-to-normal).
  if [[ "$key" == "ctrl-c" ]]; then
    exit 130
  fi

  # Mode transitions
  if [[ "$mode" == "normal" && "$key" == "i" ]]; then
    mode="insert"
    continue
  fi
  if [[ "$mode" == "insert" && "$key" == "esc" ]]; then
    mode="normal"
    continue
  fi
  if [[ "$mode" == "normal" && "$key" == "esc" ]]; then
    exit 1
  fi

  # Selection
  if [[ "$key" == "enter" && -n "$sel" ]]; then
    printf "%s" "$sel"
    exit 0
  fi

  # Fallback
  if [[ "$mode" == "insert" ]]; then
    mode="normal"
    continue
  fi
  exit 1
done
