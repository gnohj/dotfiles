#!/bin/bash
# Hook that runs after sesh connects to a session.
# Auto-launches nvim into a 🖊️-renamed window for "blank" sessions —
# i.e. ones with no `startup_command` of their own. Sessions WITH a
# startup_command (e.g. `chezmoi` runs `git status`, `web/bare` runs
# `treekanga tui`, `web/master` runs `git status`) are left alone —
# their startup_command's output IS what the user wanted to see, and
# launching nvim on top would clobber it.

SESSION_NAME=$(tmux display-message -p '#{session_name}')
SESH_TOML="$HOME/.config/sesh/sesh.toml"

# Bail if this session has a `startup_command` defined in sesh.toml.
# Parse the [[session]] block where `name = "<SESSION_NAME>"` and
# check for a startup_command key inside it. awk skips the [default_session]
# block so this only inspects [[session]] entries.
if [ -f "$SESH_TOML" ]; then
  HAS_STARTUP=$(awk -v target="$SESSION_NAME" '
    /^\[\[session\]\]/ {
      # Closing the previous block — record a match if it had what we want.
      if (in_block && name == target && cmd) found = 1
      in_block = 1; name = ""; cmd = 0; next
    }
    /^\[/ && !/^\[\[session\]\]/ { in_block = 0; next }
    in_block && /^name[[:space:]]*=/ {
      gsub(/^name[[:space:]]*=[[:space:]]*"|"[[:space:]]*$/, "")
      name = $0
    }
    in_block && /^startup_command[[:space:]]*=/ { cmd = 1 }
    END {
      # Catches the file-final block (no trailing header to close it).
      if (in_block && name == target && cmd) found = 1
      if (found) print "yes"
    }
  ' "$SESH_TOML")
  if [ "$HAS_STARTUP" = "yes" ]; then
    exit 0
  fi
fi

# Otherwise: blank session → launch nvim into a 🖊️ window.
WINDOW_COUNT=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_index}' | wc -l)
if [ "$WINDOW_COUNT" -eq 1 ]; then
  FIRST_WINDOW_NAME=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' | head -1)
  if [[ "$FIRST_WINDOW_NAME" == *"🐠"* ]] || [[ "$FIRST_WINDOW_NAME" == *"zsh"* ]] || [[ "$FIRST_WINDOW_NAME" == *"bash"* ]] || [[ "$FIRST_WINDOW_NAME" == *"fish"* ]]; then
    tmux rename-window -t "${SESSION_NAME}:0" "🖊️"
    tmux send-keys -t "${SESSION_NAME}:0" "nvim" Enter
  fi
fi