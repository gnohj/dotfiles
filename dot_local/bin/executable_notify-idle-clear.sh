#!/usr/bin/env bash
# Clear stuck agent-idle notification banners + the shared idle-state marker.
# Bound to `rctrl-esc` locally via skhd; on a VPS the same script is invoked by a
# tmux key server-side. uname-branched so it does the right thing on whichever box
# the tmux server lives on, and safe to re-run (already-clear = clean no-op).
#
# Companion to the notify-idle family: notify-idle.sh (emitter) writes the marker,
# notify-idle-switch.sh (rctrl-') jumps to the latest banner's session, this clears.
set -uo pipefail

# Shared idle-state marker written by notify-idle.sh — portable on both OSes.
rm -f /tmp/notify-idle.latest

case "$(uname -s)" in
  Darwin)
    # macOS: dismiss any stuck terminal-notifier banners, then bounce the
    # notification agents so nothing lingers on screen. Best-effort.
    export PATH="/opt/homebrew/bin:$PATH"
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
