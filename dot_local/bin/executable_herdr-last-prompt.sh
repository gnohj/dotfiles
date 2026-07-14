#!/usr/bin/env bash
# prefix+u — jump to the last user prompt ("❯ ") in a Claude Code (agent) pane, the
# herdr analog of the tmux `bind u` copy-mode search in agentic.conf.
#
# WHY A CAPTURE INSTEAD OF A SEARCH: herdr has no copy-mode and no scroll-to / search
# API (only a read-only pane.scroll_changed event), so - unlike tmux - we cannot scroll
# the LIVE pane to a match. Instead we capture the agent pane's rendered scrollback
# (herdr agent read) and open it read-only in an nvim overlay positioned at the last
# "❯ ". n steps to earlier prompts, N to later, q closes. Runs as a type="pane" overlay
# (like the ctrl+g lazygit / ctrl+y yazi launchers).
#
# WHICH PANE: this script runs INSIDE the freshly-opened overlay pane, so HERDR_PANE_ID
# is the overlay itself. The agent whose scrollback we want is the other agent pane in
# this same tab (HERDR_TAB_ID) - typically the single Claude pane you were looking at.
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
self="${HERDR_PANE_ID:-}"
tab="${HERDR_TAB_ID:-}"

if ! command -v "$herdr" >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Agent pane in this tab (a detected agent has agent_status), excluding this overlay.
target=$("$herdr" agent list 2>/dev/null \
  | jq -r --arg t "$tab" --arg self "$self" \
      'first(.result.agents[] | select(.tab_id == $t and .pane_id != $self) | .terminal_id) // empty')
# Fallback: the most recent agent anywhere, in case the tab lookup came up empty.
[ -z "$target" ] && target=$("$herdr" agent list 2>/dev/null \
  | jq -r 'first(.result.agents[] | .terminal_id) // empty')

if [ -z "$target" ]; then
  printf '\n  no agent pane found in this tab to search.\n  (press q to close)\n'
  read -r -n1 _
  exit 0
fi

tmp=$(mktemp -t herdr-prompt.XXXXXX)
trap 'rm -f "$tmp"' EXIT

"$herdr" agent read "$target" --source recent --lines 100000 2>/dev/null \
  | jq -r '.result.read.text // empty' >"$tmp"

# Open at the last "❯ " above the final line (the final "❯" is the current empty prompt,
# so step up one first - mirrors the tmux binding's cursor-up before search-backward).
# The `?` search sets a BACKWARD direction, so n = earlier prompt, N = later prompt.
nvim -R "$tmp" \
  -c 'setlocal nowrap nonumber norelativenumber signcolumn=no' \
  -c 'set hlsearch' \
  -c 'nnoremap <buffer><silent> q :qa!<CR>' \
  -c 'silent! normal! Gk' \
  -c 'silent! ?❯ ' \
  -c 'silent! normal! zz'
