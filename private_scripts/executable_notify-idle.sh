#!/usr/bin/env bash
# Agent idle notifier. Emits a macOS banner when an AI agent finishes a turn.
# Wired into Claude Code via the `Stop` hook in ~/.claude/settings.json. The
# agent name (used in the banner title) is detected by walking up the process
# tree — opencode is also recognized for future re-enablement.
#
# Why --sender com.apple.facetime: macOS Sequoia silently drops notifications
# from CLI tools whose bundle ID isn't registered with the legacy
# NSUserNotificationCenter. Spoofing FaceTime (which has legacy registration)
# is the alerter maintainer's documented workaround for issue #64. Tradeoffs:
# clicking the banner opens FaceTime (no click-to-attach), and --timeout is
# broken with --sender (issue #66) — but FaceTime's banner style auto-dismisses,
# so we don't need it.

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

# Detect the host terminal. Inside tmux we MUST use `#{client_termtype}` —
# tmux's server inherits TERM from the first client that started it and
# keeps that value forever, so $TERM in long-lived shells reflects the
# original launching terminal, not whichever terminal is currently attached.
# Outside tmux, $TERM is set live by the terminal so it's fine.
if [ -n "$SESSION" ]; then
  TERM_ID=$(tmux display-message -p -t "$SESSION" '#{client_termtype}' 2>/dev/null)
fi
TERM_ID="${TERM_ID:-${TERM:-}}"

case "$TERM_ID" in
  *ghostty*)           APP_NAME="Ghostty";  APP_ICON="/Applications/Ghostty.app/Contents/Resources/Ghostty.icns" ;;
  *kitty*)             APP_NAME="kitty";    APP_ICON="/Applications/kitty.app/Contents/Resources/kitty.icns" ;;
  *wezterm*|*WezTerm*) APP_NAME="WezTerm";  APP_ICON="/Applications/WezTerm.app/Contents/Resources/terminal.icns" ;;
  *iTerm*)             APP_NAME="iTerm";    APP_ICON="/Applications/iTerm.app/Contents/Resources/AppIcon.icns" ;;
  *)                   APP_NAME="Ghostty";  APP_ICON="/Applications/Ghostty.app/Contents/Resources/Ghostty.icns" ;;
esac

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

if ! command -v alerter >/dev/null 2>&1; then
  osascript -e "display notification \"$MSG\" with title \"$TITLE\" sound name \"Tink\"" >/dev/null 2>&1 || true
  exit 0
fi

# Fire and detach. alerter's --timeout is broken with --sender (issue #66),
# so we kill the process ourselves after $TIMEOUT_SECONDS via a shell sleep.
# We capture alerter's stdout in case @CONTENTCLICKED fires on click — even
# with --sender (which is supposed to launch the spoofed app instead),
# alerter sometimes still emits the click event. If it does, focus Ghostty
# and switch tmux back to the session that ran Claude.
(
  RESULT_FILE=$(mktemp -t claude-idle-alerter)
  alerter \
    --sender com.apple.facetime \
    --group "agent-idle-$SESSION" \
    --app-icon "$APP_ICON" \
    --title "$TITLE" \
    --message "$MSG" \
    >"$RESULT_FILE" 2>/dev/null &
  ALERTER_PID=$!
  ( sleep $TIMEOUT_SECONDS && kill "$ALERTER_PID" 2>/dev/null ) &
  wait "$ALERTER_PID" 2>/dev/null

  result=$(cat "$RESULT_FILE" 2>/dev/null)
  rm -f "$RESULT_FILE"

  if [ "$result" = "@CONTENTCLICKED" ]; then
    osascript -e "tell application \"$APP_NAME\" to activate" >/dev/null 2>&1 || true
    tmux switch-client -t "$SESSION" 2>/dev/null \
      || tmux attach-session -t "$SESSION" 2>/dev/null \
      || true
  fi
) </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true
