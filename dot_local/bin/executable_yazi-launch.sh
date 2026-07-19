#!/bin/bash
# Open yazi in a tmux window. If the focused pane is nvim (per-pane RPC socket up),
# seed yazi with the active buffer's path; otherwise fall back to the pane cwd.

# Insert ~/.local/bin (+ mise shims) BEFORE /usr/bin so the source-built
# ~/.local/bin/tmux (3.6b) beats apt's /usr/bin/tmux (3.4) on Linux — a
# client/server version mismatch otherwise makes every `tmux` call here fail
# ("server exited unexpectedly"). macOS order is unchanged (no tmux lives in
# ~/.local/bin there, so it still resolves via /run/current-system or homebrew).
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/bin:/bin:$PATH"

EMOJI="📂"
SESSION=$(tmux display-message -p '#{session_name}' 2>/dev/null)

# Reuse an existing yazi window if one already exists in this session.
if tmux select-window -t "${SESSION}:${EMOJI}" 2>/dev/null; then
  exit 0
fi

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

# Resolve yazi to an absolute path here (this script's PATH has the mise shims);
# a fresh `bash -l` in the new window does NOT activate mise on Linux, so a bare
# `yazi` was "command not found" → the window opened and closed instantly.
YAZI_BIN="$(command -v yazi 2>/dev/null || echo yazi)"
tmux new-window -n "$EMOJI" -c "$PANE_PATH" "$YAZI_BIN $(printf %q "$TARGET")"
