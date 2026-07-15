#!/bin/bash
# Open yazi in a tmux window. If the focused pane is nvim (per-pane RPC socket up),
# seed yazi with the active buffer's path; otherwise fall back to the pane cwd.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

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

tmux new-window -n "$EMOJI" -c "$PANE_PATH" "bash -l -c 'yazi $(printf %q "$TARGET")'"
