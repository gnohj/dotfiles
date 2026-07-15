#!/bin/bash
# Terminal-focus gate for skhd hotkeys whose ACTION is running a script.
# skhd fires GLOBALLY, so bail unless a terminal (Ghostty/kitty) is frontmost —
# else a stray right-ctrl press throws a tmux popup behind the wrong window.
# Does NOT work for pass-through keys: `skhd -k` synthetic events don't reach the
# multiplexer (verified 2026-07), so those (g/t/y) are FREED in skhdrc instead.
# Detection via lsappinfo (~5ms) not osascript (~120ms) — runs on every keypress.

FRONT="$(lsappinfo info -only bundleID "$(lsappinfo front 2>/dev/null)" 2>/dev/null)"
case "$FRONT" in
  *com.mitchellh.ghostty* | *net.kovidgoyal.kitty*) ;;
  *) exit 0 ;;
esac

case "$1" in
  # Jump straight to the next agent that needs you — no dashboard UI. Input
  # (blocked) agents first, then Done (finished) as a last tier.
  i) exec "$HOME/.config/skhd/tmux-dash-next-input.sh" ;;
  *) exit 0 ;;
esac
