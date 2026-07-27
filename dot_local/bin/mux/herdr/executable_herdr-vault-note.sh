#!/usr/bin/env bash
# herdr-vault-note.sh — open the focused workspace's vault note in nvim (prefix+O, tmux-dash's `o`).
# Resolution goes through `vault-note`, the same resolver behind the sidebar's 󰎞 badge.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"

herdr="${HERDR_BIN_PATH:-herdr}"

# Focused pane first (a popup is an overlay, not a pane), $PWD as fallback — same pattern as herdr-scrollback.sh.
cwd=$("$herdr" pane list 2>/dev/null |
  jq -r 'first(.result.panes[] | select(.focused == true) | .foreground_cwd // .cwd) // empty')
[ -n "$cwd" ] || cwd="$PWD"

note=$(vault-note "$cwd" 2>/dev/null) || note=""

if [ -z "$note" ]; then
  # Toast, not a popup: no note is the ordinary case on any branch without a ticket.
  "$herdr" notification show "No vault note" \
    --body "no second-brain note for this branch — capture one with /sb-ticket-capture" \
    >/dev/null 2>&1
  exit 0
fi

exec nvim "$note"
