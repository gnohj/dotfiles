#!/bin/bash
# Default startup script for sesh sessions
# Runs dev.sh for worktrees matching pattern or regular git repos

SESSION_PATH="${1:-$PWD}"
WORKTREE_PATTERN="(work|scratch|develop|master|review)(/|$)"

cd "$SESSION_PATH" || exit 0

# (No re-run guard needed: sesh only executes startup_command when it CREATES
# a session — connector/tmux.go gates startup.Exec on connection.New — so this
# script cannot fire again on reconnect.)
SESSION_NAME=$(tmux display-message -p '#{session_name}' 2>/dev/null)

# If the fast session-created hook (sesh-session-created.sh) already claimed this
# session, do NOT also run dev.sh (would duplicate the dev windows / relaunch
# nvim the slow way). dev.sh stays as a graceful fallback for sesh sessions the
# hook skipped (e.g. an entry point missing the @sesh_spawn stamp).
if [[ "$(tmux show-options -qv -t "$SESSION_NAME" @nvim_fast_done 2>/dev/null)" == "1" ]]; then
  exit 0
fi

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

# Claim the session against the sesh-session-created hook (which ALSO builds the
# dev layout via dev.sh and gates on @nvim_fast_done). We're past the git check
# and about to run dev.sh, so claim now: if the hook hasn't set the flag yet, this
# makes it defer at its once-guard instead of building a duplicate set of dev windows.
# Symmetric with the hook's early claim — whichever wins, the other backs off.
tmux set-option -t "$SESSION_NAME" @nvim_fast_done 1

if [[ "$SESSION_PATH" =~ $WORKTREE_PATTERN ]]; then
  ~/.config/sesh/dev.sh '' "$SESSION_PATH"
  exit 0
fi

if [[ -d "$SESSION_PATH/.git" || -f "$SESSION_PATH/.git" ]]; then
  ~/.config/sesh/dev.sh '' "$SESSION_PATH"
  exit 0
fi
