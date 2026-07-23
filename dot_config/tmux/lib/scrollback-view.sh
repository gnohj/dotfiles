#!/usr/bin/env bash
# prefix+e scrollback viewer: trim trailing blank rows from the ansi capture, then open it in an isolated baleia nvim (colors, transparent, chromeless, yank via tmux).
set -euo pipefail

src="/tmp/tmux-scrollback.txt"
trimmed="/tmp/tmux-scrollback-trim.txt"
init="$HOME/.config/tmux/lib/scrollback-nvim-init.lua"

# Drop trailing whitespace-only rows (empty screen below the prompt); awk for BSD+GNU portability.
awk '{ l[NR]=$0 } END { n=NR; while (n>0 && l[n] ~ /^[[:space:]]*$/) n--; for (i=1;i<=n;i++) print l[i] }' "$src" >"$trimmed"

exec nvim -u "$init" "$trimmed" -c 'lua ScrollbackView()'
