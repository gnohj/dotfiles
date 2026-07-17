#!/usr/bin/env bash

# Fires the native macOS agent-idle banner (icon + mac-notify); called locally by notify-idle.sh or over reverse-SSH from the VPS. Args: AGENT SESSION TERM_ID [ATTACH_CMD]

set -uo pipefail
export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

AGENT="${1:-Agent}"
SESSION="${2:-}"
TERM_ID="${3:-}"
ATTACH_CMD="${4:-}"

[ -n "$SESSION" ] || exit 0

# Content-image PNG for the terminal hosting the session (cached under ~/.cache/notify-idle).
ICON_PNG=$(resolve-term-icon "$TERM_ID" 2>/dev/null || true)

notify_args=( -t "$AGENT" -m "$SESSION" -g "agent-idle-$SESSION" -T 12 )
[ -n "$ATTACH_CMD" ] && notify_args+=( -e "$ATTACH_CMD" )
[ -n "$ICON_PNG" ] && [ -f "$ICON_PNG" ] && notify_args+=( -i "$ICON_PNG" )

mac-notify "${notify_args[@]}"
