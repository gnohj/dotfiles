#!/bin/bash
# Default startup script for sesh sessions
# Runs dev.sh for worktrees matching pattern or regular git repos

SESSION_PATH="${1:-$PWD}"
WORKTREE_PATTERN="(_work|_infra|_scratch|_develop|_master|_review)(/|$)"

cd "$SESSION_PATH" || exit 0

# Check if inside a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

# Worktree matching our pattern - run dev.sh with current worktree
if [[ "$SESSION_PATH" =~ $WORKTREE_PATTERN ]]; then
  ~/.config/sesh/dev.sh '' "$SESSION_PATH"
  exit 0
fi

# Regular git repo with .git directory - run dev.sh with current path
if [[ -d "$SESSION_PATH/.git" ]]; then
  ~/.config/sesh/dev.sh '' "$SESSION_PATH"
  exit 0
fi

# Default: do nothing
