#!/usr/bin/env bash
# Clears stuck agent-idle banners and the idle marker (skhd rctrl-esc); safe to re-run.
set -uo pipefail

# Shared idle-state marker written by the worktree runner, portable on both OSes.
rm -f /tmp/notify-idle.latest

case "$(uname -s)" in
  Darwin)
    # macOS: dismiss any stuck terminal-notifier banners, then bounce the
    # notification agents so nothing lingers on screen. Best-effort.
    . "$HOME/.local/bin/mux/shared/mux-env.sh"
    terminal-notifier -remove ALL >/dev/null 2>&1 || true
    killall NotificationCenter usernotificationsd >/dev/null 2>&1 || true
    ;;
  *)
    # Linux VPS: no desktop-notification surface here yet (a future remote
    # dispatcher owns banner delivery). Clearing the marker above is the whole
    # meaningful action; nothing else to dismiss.
    :
    ;;
esac
