#!/bin/bash
# Shared sesh startup body for git/worktree sessions.
#
# The session's original window (window 0) becomes the nvim ("pen") window and
# stays focused the entire time. The 3-pane shell ("fish") window is created in
# the BACKGROUND (tmux new-window -d) so its shells boot while you're already in
# nvim - the spawn lands straight in nvim with no focus flash, yet both windows
# show in the status bar immediately and the fish shells are warm by the time
# you navigate to them.
#
# First parameter is an unused placeholder (''); second is the working dir.

# /opt/homebrew stays first so macOS resolution is unchanged; the Linux dirs
# (linuxbrew / mise shims / ~/.local/bin) are appended so nvim/gitmux/sesh resolve
# on a headless Linux VPS too (matches sesh-session-created.sh / status-git-refresh.sh).
export PATH="/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
source "$HOME/.config/tmux/lib/dev-window.sh"

# Diagnostic: set to 1 to flash how long from spawn until window 0's shell is
# actually ready to launch nvim (the injected `n` command sits in the TTY buffer
# until zsh finishes sourcing .zshrc - that gate, not nvim itself, is the wait).
SHOW_LOAD_TIME=0

WORKING_DIR="${2:-$HOME}"
START_MS=$(( $(date +%s%N) / 1000000 ))

SESSION_NAME=$(tmux display-message -p '#{session_name}')
WINDOW_INDEX=$(tmux display-message -p '#{window_index}')

# Window 0 is the focused nvim/pen window.
mark_window "${SESSION_NAME}:${WINDOW_INDEX}" pen

# Launch nvim first so it renders before the background shells start competing
# for CPU. The small sleep lets window 0's shell line editor be ready for the
# injected keystrokes.
sleep 0.2
if [[ "$SHOW_LOAD_TIME" == "1" ]]; then
  # Fire the readout as a detached background job ( ... & ) so nvim launches
  # immediately and isn't blocked by the date subprocess / tmux round-trip. The
  # timestamp is still captured at this instant, so it measures the real spawn
  # -> shell-ready gate (elapsed math runs in window 0's zsh after its .zshrc).
  LAUNCH="cd \"$WORKING_DIR\" && clear && ( tmux display-message -d 4000 \"🖊️ shell ready in \$(( \$(date +%s%N)/1000000 - $START_MS ))ms\" & ) && n"
else
  LAUNCH="cd \"$WORKING_DIR\" && clear && n"
fi
tmux send-keys -t "${SESSION_NAME}:${WINDOW_INDEX}" "$LAUNCH" Enter

# Create the 3-pane fish window in the background (-d keeps focus on nvim).
create_fish_window "$SESSION_NAME" "$WORKING_DIR"
