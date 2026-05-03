#!/usr/bin/env bash
# Click handler for terminal-notifier banners (notify-idle.sh).
#
# Behavior:
#   1. `tmux switch-client -t <session>` — swap the attached tmux client
#      to the target session. No new terminal window.
#   2. Walk the tmux client's process tree up until we find its parent
#      terminal process (ghostty/kitty/Terminal). That PID is the SPECIFIC
#      terminal window hosting tmux — both ghostty and kitty fork a process
#      per window on macOS, so the PID uniquely identifies the window.
#   3. Use System Events to raise that exact process's window — avoids
#      focusing the wrong terminal window when multiple are open
#      (e.g. agent sidebar in another ghostty window).
#
# Cold-start fallback: when no tmux client is attached anywhere, spawn a
# fresh terminal window and attach in it.
#
# Requires Accessibility permission for the calling process — without it,
# System Events can't enumerate windows and the per-PID raise silently
# falls through to a plain `activate`.
#
# Usage:
#   open-tmux-attach.sh <session-name>

set -uo pipefail
export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"

SESSION="${1:-}"
if [ -z "$SESSION" ]; then
  echo "usage: $(basename "$0") <session-name>" >&2
  exit 1
fi

# Walk the process tree from the tmux client up until we hit a known
# terminal binary. Returns "<pid>|<comm>" or empty.
find_hosting_terminal() {
  local pid comm
  pid=$(tmux list-clients -F '#{client_pid}' 2>/dev/null | head -1)
  [ -z "$pid" ] && return 1

  while [ -n "$pid" ] && [ "$pid" != "1" ] && [ "$pid" != "0" ]; do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null)
    comm=$(basename "$comm" 2>/dev/null)
    case "$comm" in
      ghostty|kitty|Terminal)
        echo "$pid|$comm"
        return 0
        ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
  return 1
}

# Raise the specific window owned by $1 (terminal PID). Bring its app
# forward so the window is visible.
raise_window_pid() {
  local target_pid="$1"
  osascript <<EOF >/dev/null 2>&1 || true
tell application "System Events"
  try
    tell (first process whose unix id is $target_pid)
      set frontmost to true
      try
        perform action "AXRaise" of window 1
      end try
    end tell
  end try
end tell
EOF
}

# Try the in-place switch. With -c omitted, tmux switches the most recently
# attached client — fine when there's a single tmux client.
if tmux switch-client -t "$SESSION" 2>/dev/null; then
  if hosting=$(find_hosting_terminal); then
    raise_window_pid "${hosting%%|*}"
  fi
  exit 0
fi

# Cold-start fallback: no tmux client attached anywhere. Spawn a window.
ATTACH_CMD="tmux attach -t '$SESSION'"

if pgrep -x ghostty >/dev/null 2>&1 && [ -x "/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then
  /Applications/Ghostty.app/Contents/MacOS/ghostty -e "$ATTACH_CMD" >/dev/null 2>&1 &
elif pgrep -x kitty >/dev/null 2>&1 && [ -x "/Applications/kitty.app/Contents/MacOS/kitty" ]; then
  /Applications/kitty.app/Contents/MacOS/kitty bash -lc "$ATTACH_CMD" >/dev/null 2>&1 &
else
  osascript \
    -e "tell application \"Terminal\" to do script \"$ATTACH_CMD\"" \
    -e "tell application \"Terminal\" to activate" \
    >/dev/null 2>&1
fi
