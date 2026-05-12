#!/usr/bin/env bash
# Agent idle notifier. Emits a macOS banner when an AI agent finishes a turn.
# Wired into Claude Code via the `Stop` hook in ~/.claude/settings.json. The
# agent name (used in the banner title) is detected by walking up the process
# tree — opencode is also recognized for future re-enablement.
#
# Uses terminal-notifier (own bundle id, registered with NSUserNotification)
# rather than alerter+facetime spoof. Click opens Terminal.app and attaches
# to the tmux session. `rctrl - '` remains the primary attach path; banner
# click is the secondary "I just want to grab this from anywhere" path.
#
# The notification thumbnail (-contentImage) reflects the terminal hosting
# the tmux session (Ghostty / kitty / Terminal.app / etc). icns assets are
# converted to png on first use via `sips` and cached under
# ~/.cache/notify-idle/ for reuse.

set -uo pipefail
export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"

# Log every invocation with caller info so we can spot rogue triggers.
LOG_DIR="$HOME/.logs"
mkdir -p "$LOG_DIR"
{
  echo "---- $(date '+%F %T') pid=$$ ppid=$PPID"
  echo "  parent: $(ps -o command= -p $PPID 2>/dev/null | head -c 200)"
  echo "  cwd: $PWD"
} >> "$LOG_DIR/notify-idle.log" 2>&1

SESSION="${TMUX:+$(tmux display-message -p '#S' 2>/dev/null)}"
BRANCH="$(git -C "$PWD" branch --show-current 2>/dev/null)"

# Only notify when both tmux session and git branch exist — otherwise the
# notification is noise (Claude was run outside the normal tmux+git workflow).
if [ -z "$SESSION" ] || [ -z "$BRANCH" ]; then
  exit 0
fi

# Track the most recent session to fire a banner so the smart-switch binding
# (rctrl - ') can read it and tmux switch-client back to that session.
echo "$SESSION" > /tmp/notify-idle.latest 2>/dev/null || true

# Detect host terminal. Inside tmux we MUST use `#{client_termtype}` —
# tmux's server inherits TERM from the first client that started it and
# keeps that value forever, so $TERM in long-lived shells reflects the
# original launching terminal, not whichever terminal is currently attached.
TERM_ID=""
if [ -n "$SESSION" ]; then
  TERM_ID=$(tmux display-message -p -t "$SESSION" '#{client_termtype}' 2>/dev/null)
fi
TERM_ID="${TERM_ID:-${TERM:-}}"

# Resolve content-image PNG via the shared helper. Cache lives in
# ~/.cache/notify-idle/. Some apps (kitty) ship a usable PNG directly;
# others (Ghostty, Terminal.app, iTerm) only ship .icns and the helper
# converts + caches via sips on first use.
ICON_PNG=$(resolve-term-icon "$TERM_ID" 2>/dev/null || true)

# Detect which agent fired the hook by walking up the process tree. Claude
# Code spawns the hook as a direct child (PPID = claude), but opencode
# plugins spawn through a zx shell (PPID = bash, grandparent = opencode), so
# we walk up to 5 levels looking for a known agent binary.
AGENT="Agent"
_pid=$PPID
for _ in 1 2 3 4 5; do
  [ -z "$_pid" ] && break
  case "$_pid" in 0|1) break ;; esac
  _name=$(ps -o comm= -p "$_pid" 2>/dev/null | xargs basename 2>/dev/null)
  case "$_name" in
    claude)   AGENT="Claude";   break ;;
    opencode) AGENT="Opencode"; break ;;
  esac
  _pid=$(ps -o ppid= -p "$_pid" 2>/dev/null | tr -d ' ')
done

TITLE="$AGENT"
MSG="$SESSION"
TIMEOUT_SECONDS=12

# Click handler dispatches to whichever terminal is currently running
# (ghostty → kitty → Terminal.app fallback). Helper lives in ~/Scripts/
# and is deployed by chezmoi from private_Scripts/executable_open-tmux-attach.sh.
EXECUTE_CMD="$HOME/Scripts/open-tmux-attach.sh '$SESSION'"

# Fire the banner via the unified mac-notify helper. mac-notify owns
# the terminal-notifier vs osascript fallback, so this script doesn't
# need to branch on tool availability.
notify_args=(
  -t "$TITLE"
  -m "$MSG"
  -g "agent-idle-$SESSION"
  -T "$TIMEOUT_SECONDS"
  -e "$EXECUTE_CMD"
)
if [ -n "$ICON_PNG" ] && [ -f "$ICON_PNG" ]; then
  notify_args+=( -i "$ICON_PNG" )
fi
mac-notify "${notify_args[@]}"
