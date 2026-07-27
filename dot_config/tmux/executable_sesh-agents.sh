#!/usr/bin/env bash
# Row source for the sesh picker (rows are "<icon> <name>"); `--kill <row>` is ctrl-d's handler.

export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
[ "$(uname)" = Linux ] && PATH="$HOME/.nix-profile/bin:/home/linuxbrew/.linuxbrew/bin:$PATH"

if [[ "${1:-}" == "--kill" ]]; then
  row="${2:-}"
  # Drop the leading sesh icon glyph (fzf has already stripped the ANSI).
  name="${row#* }"
  [[ -n "$name" ]] && tmux kill-session -t "$name" 2>/dev/null
  exit 0
fi

sesh list "$@" --icons 2>/dev/null
