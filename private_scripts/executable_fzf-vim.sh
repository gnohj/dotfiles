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

trap 'printf "\e[0 q" >/dev/tty 2>/dev/null' EXIT

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
      --no-header \
      --border-label ' NORMAL  j/k  G/g  i→insert  esc→quit ' \
      --expect=enter,i,esc \
      --bind 'j:down,k:up' \
      --bind 'G:last,g:first' \
      --bind 'd:half-page-down,u:half-page-up' \
      --bind 'enter:accept,i:accept' \
      --bind 'esc:abort') || fzf_rc=$?
  else
    printf '\e[5 q' >/dev/tty
    fzf_out=$(printf "%s\n" "$INPUT" | fzf \
      "${extra_args[@]}" \
      --reverse --no-clear --no-multi \
      --no-header \
      --border-label ' INSERT  type to filter  esc→normal ' \
      --expect=enter,esc \
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
