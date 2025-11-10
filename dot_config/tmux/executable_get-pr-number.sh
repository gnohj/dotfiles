#!/usr/bin/env bash

# Get PR number for current branch
# Returns empty string if no PR exists or on error

LOG_FILE="$HOME/.logs/tmux-get-pr-number.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Get current directory
DIR="${1:-$(pwd)}"
log "Starting get-pr-number.sh with DIR=$DIR"

cd "$DIR" 2>/dev/null || {
  log "Failed to cd to $DIR"
  exit 0
}

# Check if we're in a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  log "Not in a git repo"
  exit 0
fi

log "In git repo, checking for PR"

# Simpler approach: just run gh with stderr suppressed
# gh is fast enough (~0.5s) that we can run it synchronously
PR_NUM=$(gh pr view --json number --jq '.number' 2>"$HOME/.logs/tmux-gh-error.log")
log "gh pr view returned: '$PR_NUM'"

# Only output if we got a valid number
if [ -n "$PR_NUM" ] && [ "$PR_NUM" -eq "$PR_NUM" ] 2>/dev/null; then
  log "Outputting PR_NUM=$PR_NUM"
  echo "$PR_NUM"
else
  log "PR_NUM is not a valid number or empty"
fi
