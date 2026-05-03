#!/usr/bin/env bash
# Smart-switch binding for rctrl - '.
# Reads the latest tmux session that emitted an idle banner (tracked by
# notify-idle.sh in /tmp/notify-idle.latest), switches the tmux client to
# that session, then clears all displayed banners.

set -uo pipefail
export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"

STATE_FILE="/tmp/notify-idle.latest"
ENTRY=$(cat "$STATE_FILE" 2>/dev/null)

# No-op when there's no recent notification to act on. Prevents repeated
# presses from blowing away active notifications when there's nothing to
# switch to — wait for a real banner first.
[ -z "$ENTRY" ] && exit 0

# State file format:
#   "<session_name>"           — bare session name (claude-idle banners)
#   "<session_name>|<path>"    — session may not exist yet, create at path
#                                (jira-worktree banners)
SESSION="${ENTRY%%|*}"
WORKTREE_PATH=""
case "$ENTRY" in *\|*) WORKTREE_PATH="${ENTRY#*|}" ;; esac

# If a path was provided and the session doesn't exist yet, create it
# detached at that path. This is the "deferred creation" the worktree
# wrapper relies on — it skips pre-creation to avoid a session-created
# hook fire on the user's tmux while they're not switching.
if [ -n "$WORKTREE_PATH" ] && ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -c "$WORKTREE_PATH" 2>/dev/null || true
fi

tmux switch-client -t "$SESSION" 2>/dev/null \
  || tmux attach-session -t "$SESSION" 2>/dev/null \
  || true
rm -f "$STATE_FILE"

# Clear banners + lingering alerter processes
pkill alerter 2>/dev/null
killall NotificationCenter usernotificationsd 2>/dev/null
exit 0
