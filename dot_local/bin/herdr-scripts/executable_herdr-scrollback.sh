#!/usr/bin/env bash
# herdr scrollback viewer (port of tmux/lib/scrollback-view.sh): ansi capture in an isolated baleia nvim. No args = prefix+e (bottom), --jump = prefix+u (last prompt). Reads a COPY because herdr's scroll position is read-only with no scrollback-search API.
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
init="$HOME/.config/herdr/lib/scrollback-nvim-init.lua"
LINES_BACK="${HERDR_SCROLLBACK_LINES:-10000}"

JUMP=0
[ "${1:-}" = "--jump" ] && JUMP=1

# Focused pane first (a popup is an overlay, not a pane), HERDR_PANE_ID as fallback. No "exclude self" filter: when HERDR_PANE_ID is the invoking pane, excluding it drops the very pane we want.
PANE=$("$herdr" pane list 2>/dev/null |
  jq -r '.result.panes[] | select(.focused == true) | .pane_id' | head -1)
[ -n "$PANE" ] || PANE="${HERDR_PANE_ID:-}"
if [ -z "$PANE" ]; then
  echo "herdr-scrollback: no focused pane to read" >&2
  sleep 1
  exit 0
fi

FILE=$(mktemp -t herdr-scrollview-XXXXXX)
# No exec below, so this trap still runs and the dump does not outlive the popup.
trap 'rm -f "$FILE"' EXIT

# Strip the trailing CR herdr emits on nearly every line (a few lack it, so nvim picks fileformat=unix and would show a literal ^M on each), then drop trailing blank rows so G lands on real content.
"$herdr" pane read "$PANE" --source recent-unwrapped --lines "$LINES_BACK" --format ansi 2>/dev/null |
  awk '{ sub(/\r$/, ""); l[NR]=$0 } END { n=NR; while (n>0 && l[n] ~ /^[[:space:]]*$/) n--; for (i=1;i<=n;i++) print l[i] }' >"$FILE"

if [ "$JUMP" = "1" ]; then
  nvim -u "$init" "$FILE" -c 'lua HerdrScrollbackView({ jump = true })'
else
  nvim -u "$init" "$FILE" -c 'lua HerdrScrollbackView()'
fi
