#!/usr/bin/env bash

# Timeout wrapper for gitmux status; prevents hanging in tmux status bar

DIR="${1:-$(pwd)}"

run_gitmux() {
  cd "$DIR" 2>/dev/null || exit 0

  FULL_REPO_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
  REPO_NAME=$(echo "$FULL_REPO_NAME" | sed 's/[-_].*//')

  if OUTPUT=$(gitmux -cfg "$HOME/.config/gitmux/gitmux.yml" 2>/dev/null | sed 's/^ //' | "$HOME/.config/tmux/truncate-branch.sh"); then
    if [ -n "$REPO_NAME" ]; then
      echo "#[fg=#b7ce97]${REPO_NAME}#[fg=#9ea3b9]${OUTPUT} "
    else
      echo "$OUTPUT "
    fi
  fi
}

# Execute with timeout - kill if takes more than 0.5 seconds
(run_gitmux) &
pid=$!
(sleep 0.5 && kill -9 $pid 2>/dev/null) &
timeout_pid=$!

# Wait for gitmux to finish
if wait $pid 2>/dev/null; then
  kill $timeout_pid 2>/dev/null
else
  # Killed by timeout, show simple fallback
  echo ""
fi

