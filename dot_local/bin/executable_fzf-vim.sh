#!/usr/bin/env bash
# fzf-vim.sh — wraps fzf with vim-like normal/insert mode
# Usage: some-command | fzf-vim.sh [fzf extra args...]
# Outputs the selected line to stdout
# Caller args are passed through; modal binds are appended last (take priority)

set -euo pipefail

# Buffer stdin so the loop can re-feed fzf on mode switch; builtin slurp, no $(cat) fork.
IFS= read -r -d '' INPUT || true

extra_args=("$@")
mode="${FZF_VIM_MODE:-normal}"

# Optional status header, pinned to the top (--header-first). Two opt-in forms;
# every other picker sets neither and keeps --no-header (unchanged):
#   FZF_VIM_HEADER_CMD  command the idle poster re-runs (FZF_VIM_HEADER_POLL, def 5s).
#   FZF_VIM_HEADER      static string; set WITH _CMD to skip the start-up re-exec.
# Never bind either to `focus` — anything fzf runs itself blocks its render loop.
# transform-header/--listen need fzf >= 0.38 (nix ships current on both OSes).
_poster_pid=""
_port_file=""
if [ -n "${FZF_VIM_HEADER_CMD:-}" ]; then
  # $$ gives the same uniqueness as a mktemp fork; EXIT trap removes it.
  _port_file="${TMPDIR:-/tmp}/fzf-vim-port.$$"
  # Only pay for transform-header when the caller could not supply an initial string.
  if [ -n "${FZF_VIM_HEADER:-}" ]; then
    header_args=(--header "$FZF_VIM_HEADER" --header-first --listen
      --bind "start:execute-silent(printf '%s' \"\$FZF_PORT\" >|$_port_file)")
  else
    header_args=(--header-first --listen
      --bind "start:transform-header($FZF_VIM_HEADER_CMD)+execute-silent(printf '%s' \"\$FZF_PORT\" >|$_port_file)")
  fi
  # Poster renders the badge itself; fzf running it would stutter its render loop.
  if command -v curl >/dev/null 2>&1; then
    (
      set +e # best-effort: a dead port during a mode-switch must not kill the loop
      interval="${FZF_VIM_HEADER_POLL:-5}"
      while :; do
        sleep "$interval"
        port=$(cat "$_port_file" 2>/dev/null)
        [ -n "$port" ] || continue
        # Single line: `change-header:` consumes the rest of the payload verbatim.
        hdr=$(eval "$FZF_VIM_HEADER_CMD" 2>/dev/null | head -1)
        [ -n "$hdr" ] && curl -sS -XPOST "localhost:$port" \
          -d "change-header:$hdr" >/dev/null 2>&1
      done
      # >/dev/null is load-bearing: a child holding our stdout blocks the caller's $(...).
    ) >/dev/null 2>&1 &
    _poster_pid=$!
  fi
elif [ -n "${FZF_VIM_HEADER:-}" ]; then
  header_args=(--header "$FZF_VIM_HEADER" --header-first)
else
  header_args=(--no-header)
fi

# Reset cursor + tear down poster/port file; children first or the `sleep` is orphaned.
trap '
  printf "\e[0 q" >/dev/tty 2>/dev/null
  [ -n "$_poster_pid" ] && { pkill -P "$_poster_pid" 2>/dev/null; kill "$_poster_pid" 2>/dev/null; }
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

  # Parameter expansion, not $(printf|head)/$(printf|sed): four processes on the Enter path.
  if [[ $fzf_rc -ne 0 && -z "$fzf_out" ]]; then
    key="esc"
    sel=""
  else
    key="${fzf_out%%$'\n'*}"
    if [[ "$fzf_out" == *$'\n'* ]]; then
      sel="${fzf_out#*$'\n'}"
      sel="${sel%%$'\n'*}"
    else
      sel=""
    fi
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
