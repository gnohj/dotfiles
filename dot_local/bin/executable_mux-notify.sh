#!/usr/bin/env bash
# Transient message wherever you're looking: herdr toast, or the tmux status line.
set -uo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/share/mise/shims:$PATH"
[ "$(uname)" = Linux ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

title="notice"
duration=5000

while [ $# -gt 0 ]; do
  case "$1" in
    --title) title="$2"; shift 2 ;;
    --duration) duration="$2"; shift 2 ;;
    --) shift; break ;;
    -*) echo "mux-notify: unknown option $1" >&2; exit 2 ;;
    *) break ;;
  esac
done

msg="${1:?mux-notify: missing <message>}"

case "$("$HOME/.local/bin/mux-kind.sh")" in
  # herdr has no status line, so --duration is tmux-only.
  herdr)
    "${HERDR_BIN_PATH:-herdr}" notification show "$title" --body "$msg" >/dev/null 2>&1 ||
      printf '%s\n' "$msg" >&2
    ;;
  tmux)
    tmux display-message -d "$duration" "$msg" 2>/dev/null ||
      printf '%s\n' "$msg" >&2
    ;;
  *)
    printf '%s\n' "$msg" >&2
    ;;
esac
