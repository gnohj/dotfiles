#!/usr/bin/env bash
# Smart-switch binding for rctrl - '.
# Reads the latest tmux session that emitted an idle banner (tracked by
# notify-idle.sh in /tmp/notify-idle.latest), switches the tmux client to
# that session, then clears all displayed banners.

set -uo pipefail
export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"

STATE_FILE="/tmp/notify-idle.latest"
SESSION=$(cat "$STATE_FILE" 2>/dev/null)

# No-op when there's no recent notification to act on. Prevents repeated
# presses from blowing away active notifications when there's nothing to
# switch to — wait for a real banner first.
[ -z "$SESSION" ] && exit 0

tmux switch-client -t "$SESSION" 2>/dev/null \
  || tmux attach-session -t "$SESSION" 2>/dev/null \
  || true
rm -f "$STATE_FILE"

# Clear banners + lingering alerter processes
pkill alerter 2>/dev/null
killall NotificationCenter usernotificationsd 2>/dev/null
exit 0
