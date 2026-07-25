#!/usr/bin/env bash
# Run an interactive script modally: a tmux popup, or inline under herdr.
set -uo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/share/mise/shims:$PATH"
[ "$(uname)" = Linux ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

width="70%"
height="30%"

while [ $# -gt 0 ]; do
  case "$1" in
    --width) width="$2"; shift 2 ;;
    --height) height="$2"; shift 2 ;;
    --) shift; break ;;
    -*) echo "mux-popup: unknown option $1" >&2; exit 2 ;;
    *) break ;;
  esac
done

script="${1:?mux-popup: missing <script-path>}"
[ -x "$script" ] || chmod +x "$script" 2>/dev/null || true

# Exit status is the inner script's, so a cancel is distinguishable from a failure.
case "$("$HOME/.local/bin/mux-kind.sh")" in
  tmux)
    tmux display-popup -E -w "$width" -h "$height" "$script"
    ;;
  *)
    # herdr has no popup CLI; in herdr mode these captures already run in the quake.
    clear 2>/dev/null || true
    "$script"
    ;;
esac
