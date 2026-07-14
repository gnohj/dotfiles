#!/bin/bash
# Terminal-focus gate for skhd hotkeys whose ACTION is running a script.
#
# skhd hotkeys fire GLOBALLY, regardless of which app is focused. A key like
# rctrl-i should only fire its action when a terminal (Ghostty / kitty, where
# tmux / herdr run) is frontmost; in any other app (Chrome, Slack, ...) it must
# BAIL so a stray right-ctrl press doesn't throw a tmux popup behind the wrong
# window.
#
# SCOPE: this only works for hotkeys whose action is to RUN something (a popup,
# a script). It does NOT work for "pass the keystroke through to the multiplexer"
# — `skhd -k` synthetic key events are not delivered into Ghostty/tmux/herdr as
# terminal input, so a re-emit approach silently dies (verified 2026-07). Keys
# that need to reach the multiplexer (g/t/y for lazygit/sesh/yazi) are therefore
# left FREED in skhdrc: physical right-ctrl+<k> collapses to ctrl+<k> and passes
# straight to whichever multiplexer is focused, which is the proven-working path.
#
# Detection uses lsappinfo (~5ms) rather than osascript System Events (~120ms) —
# this runs on every keypress, so the latency has to be invisible.

FRONT="$(lsappinfo info -only bundleID "$(lsappinfo front 2>/dev/null)" 2>/dev/null)"
case "$FRONT" in
  *com.mitchellh.ghostty* | *net.kovidgoyal.kitty*) ;;  # in a terminal -> act below
  *) exit 0 ;;                                          # anywhere else -> bail (swallow the key)
esac

case "$1" in
  # Jump straight to the next agent that needs you — no dashboard UI. Input
  # (blocked) agents first, then Done (finished) as a last tier.
  i) exec "$HOME/.config/skhd/tmux-dash-next-input.sh" ;;
  *) exit 0 ;;
esac
