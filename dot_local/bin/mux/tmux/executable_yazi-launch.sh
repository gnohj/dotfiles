#!/bin/bash
# prefix+y run-shell job: open yazi in a 90% display-popup, matching the ctrl+g
# lazygit popup. If the focused pane is nvim (per-pane RPC socket up), seed yazi with
# the active buffer's path; otherwise fall back to the pane cwd.

# Insert ~/.local/bin (+ mise shims) BEFORE /usr/bin so the source-built
# ~/.local/bin/tmux (3.6b) beats apt's /usr/bin/tmux (3.4) on Linux — a
# client/server version mismatch otherwise makes every `tmux` call here fail
# ("server exited unexpectedly"). macOS order is unchanged (no tmux lives in
# ~/.local/bin there, so it still resolves via /run/current-system or homebrew).
. "$HOME/.local/bin/mux/shared/mux-env.sh"

PANE_CMD=$(tmux display-message -p '#{pane_current_command}' 2>/dev/null)
PANE_PATH=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
PANE_ID=$(tmux display-message -p '#{pane_id}' 2>/dev/null | tr -d '%')

TARGET="$PANE_PATH"

if [[ "$PANE_CMD" =~ ^n?vim$ ]] && [ -n "$PANE_ID" ]; then
  SOCKET="/tmp/nvim-${PANE_ID}.sock"
  if [ -S "$SOCKET" ]; then
    BUF=$(nvim --server "$SOCKET" --remote-expr 'expand("%:p")' 2>/dev/null)
    [ -n "$BUF" ] && [ -e "$BUF" ] && TARGET="$BUF"
  fi
fi

# Resolve yazi to its REAL binary. `command -v yazi` finds the mise SHIM first
# (shims are on PATH above), and the shim re-resolves through mise at run time —
# which dies in the bare popup env, so the popup flashes and closes. `mise which`
# returns the actual install-dir binary; macOS (yazi from nix, not mise) yields
# nothing and falls back to command -v.
YAZI_BIN="$(mise which yazi 2>/dev/null || command -v yazi 2>/dev/null || echo yazi)"

# YAZI_START_DIR mirrors the `y` alias so yazi.toml's edit opener returns nvim to the launch cwd.
tmux display-popup -E -w 90% -h 90% -d "$PANE_PATH" -B \
  "YAZI_START_DIR=$(printf %q "$PANE_PATH") $(printf %q "$YAZI_BIN") $(printf %q "$TARGET")"

# Always exit 0: a non-zero run-shell job gets dumped into a copy-mode pager.
exit 0
