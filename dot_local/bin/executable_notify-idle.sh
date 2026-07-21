#!/usr/bin/env bash

# Agent-idle notifier + rctrl-' marker (Claude `Stop` hook). uname-branched: Mac fires the banner locally; Linux writes the marker then reverse-SSHes the banner to the Mac (Track A). Marker written FIRST so rctrl-' works even when the banner can't be delivered.

set -uo pipefail
export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

# Log every invocation with caller info so we can spot rogue triggers.
LOG_DIR="$HOME/.logs"
mkdir -p "$LOG_DIR"
{
  echo "---- $(date '+%F %T') pid=$$ ppid=$PPID"
  echo "  parent: $(ps -o command= -p $PPID 2>/dev/null | head -c 200)"
  echo "  cwd: $PWD"
} >> "$LOG_DIR/notify-idle.log" 2>&1

SESSION="${TMUX:+$(tmux display-message -p '#S' 2>/dev/null)}"
# Stable pane id (%N) of the agent's own pane (the Stop hook inherits TMUX_PANE), so rctrl-' lands on the exact pane even when a session hosts several agents.
PANE_ID="${TMUX:+$(tmux display-message -p '#{pane_id}' 2>/dev/null)}"
BRANCH="$(git -C "$PWD" branch --show-current 2>/dev/null)"

# Only notify inside the normal tmux+git workflow; otherwise it's noise.
if [ -z "$SESSION" ] || [ -z "$BRANCH" ]; then
  exit 0
fi

# Marker for rctrl-' — written FIRST and on every OS, so the jump works even if the banner delivery below fails.
echo "${PANE_ID:-$SESSION}" > /tmp/notify-idle.latest 2>/dev/null || true

# Terminal hosting the session (for the banner icon). Inside tmux use client_termtype, not $TERM (the server keeps the first client's TERM forever).
TERM_ID=""
[ -n "$SESSION" ] && TERM_ID=$(tmux display-message -p -t "$SESSION" '#{client_termtype}' 2>/dev/null)
TERM_ID="${TERM_ID:-${TERM:-}}"

# Which agent fired the hook — walk up the process tree (claude = direct child; opencode = zx-shell grandparent).
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

case "$("$HOME/.local/bin/machine-identity" os 2>/dev/null || uname)" in
  darwin | Darwin)
    # Agent runs on the Mac — fire the banner locally; click attaches to the session.
    "$HOME/.local/bin/notify-idle-emit.sh" "$AGENT" "$SESSION" "$TERM_ID" \
      "$HOME/.local/bin/open-tmux-attach.sh '$SESSION'"
    ;;
  linux | Linux)
    # Devbox: reverse-SSH the banner to the Mac, fire-and-forget (backgrounded, short timeout, never blocks the Stop hook). Mac host via machine-identity (= $NOTIFY_MAC_SSH / mac-ssh-host); unset → marker-only.
    MAC_HOST="$("$HOME/.local/bin/machine-identity" mac-host 2>/dev/null)"
    [ -n "$MAC_HOST" ] || exit 0
    # Strip single quotes so the payload can't break out of the single-quoted remote command (defense-in-depth).
    AGENT_S=${AGENT//\'} SESSION_S=${SESSION//\'} TERM_S=${TERM_ID//\'}
    ssh -o ConnectTimeout=2 -o BatchMode=yes "$MAC_HOST" \
      "\$HOME/.local/bin/notify-idle-emit.sh '$AGENT_S' '$SESSION_S' '$TERM_S'" \
      >/dev/null 2>&1 &
    ;;
esac
