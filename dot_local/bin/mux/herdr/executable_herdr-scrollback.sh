#!/usr/bin/env bash
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
init="${HERDR_SCROLLBACK_INIT:-$HOME/.config/herdr/lib/scrollback-nvim-init.lua}"
LINES_BACK="${HERDR_SCROLLBACK_LINES:-10000}"

JUMP=0
[ "${1:-}" = "--jump" ] && JUMP=1

PANES=$("$herdr" pane list 2>/dev/null)
PANE="${HERDR_SCROLLBACK_SOURCE_PANE:-${HERDR_ACTIVE_PANE_ID:-}}"
if [ -z "$PANE" ]; then
  PANE=$(printf '%s' "$PANES" | jq -r '.result.panes[] | select(.focused == true) | .pane_id' | head -1)
fi
[ -n "$PANE" ] || PANE="${HERDR_PANE_ID:-}"
if [ -z "$PANE" ]; then
  echo "herdr-scrollback: no focused pane to read" >&2
  sleep 1
  exit 0
fi

FILE=$(mktemp -t herdr-scrollview-XXXXXX)
# Do not exec: EXIT must remove the private history dump.
trap 'rm -f "$FILE"' EXIT

# Alternate-screen history needs transcripts; fallback strips CR and trailing blanks.
AGENT=$(printf '%s' "$PANES" | jq -r --arg p "$PANE" '.result.panes[] | select(.pane_id == $p) | [.agent // "", (.agent_session.kind // ""), (.agent_session.value // ""), (.foreground_cwd // .cwd // "")] | @tsv')
IFS=$'\t' read -r agent kind session cwd <<<"$AGENT"
case "$agent" in claude | pi) transcript=1 ;; *) transcript=0 ;; esac
if [ "$transcript" = 0 ] || ! "$HOME/.local/bin/mux/herdr/herdr-agent-transcript.py" "$agent" "$kind" "$session" "$cwd" >"$FILE" 2>/dev/null; then
  transcript=0
  "$herdr" pane read "$PANE" --source recent-unwrapped --lines "$LINES_BACK" --format ansi 2>/dev/null |
    awk '{ sub(/\r$/, ""); l[NR]=$0 } END { n=NR; while (n>0 && l[n] ~ /^[[:space:]]*$/) n--; for (i=1;i<=n;i++) print l[i] }' >"$FILE"
fi

if [ -n "${HERDR_SCROLLBACK_VIEWPORT_FILE:-}" ]; then
  if [ "$transcript" = 0 ]; then
    : >"$FILE"
  else
    printf '\n' >>"$FILE"
  fi
  while IFS= read -r row || [ -n "$row" ]; do
    printf '%s\n' "$row"
  done <"$HERDR_SCROLLBACK_VIEWPORT_FILE" >>"$FILE"
fi

if [ "$JUMP" = "1" ]; then
  nvim -u "$init" "$FILE" -c 'lua HerdrScrollbackView({ jump = true })'
else
  nvim -u "$init" "$FILE" -c 'lua HerdrScrollbackView()'
fi
