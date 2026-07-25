#!/usr/bin/env bash
# Which multiplexer gets new windows/tabs: herdr | tmux | none.
set -uo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/share/mise/shims:$PATH"
[ "$(uname)" = Linux ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
herdr="${HERDR_BIN_PATH:-herdr}"

# herdr wins when both are set — a herdr pane can sit atop a tmux session.
if [ -n "${HERDR_SOCKET_PATH:-}" ]; then echo herdr; exit 0; fi
if [ -n "${TMUX:-}" ]; then echo tmux; exit 0; fi

# No pane env still means a live server: nohup'd reclaims and systemd units have none.
if command -v "$herdr" >/dev/null 2>&1 &&
  "$herdr" status server 2>/dev/null | grep -q '^status: running'; then
  echo herdr
  exit 0
fi

if command -v tmux >/dev/null 2>&1 && tmux ls >/dev/null 2>&1; then
  echo tmux
  exit 0
fi

echo none
