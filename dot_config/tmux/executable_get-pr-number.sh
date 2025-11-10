#!/usr/bin/env bash

# Get PR number for current branch (async with caching)
# Returns cached PR number immediately, updates in background

LOG_FILE="$HOME/.logs/tmux-get-pr-number.log"
CACHE_DIR="$HOME/.cache/tmux-pr-numbers"
CACHE_TTL_WITH_PR=86400  # 24 hours when PR exists
CACHE_TTL_NO_PR=300      # 5 minutes when no PR exists

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Get current directory
DIR="${1:-$(pwd)}"

cd "$DIR" 2>/dev/null || exit 0

# Check if we're in a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Get git repo root and branch for cache key
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
BRANCH=$(git branch --show-current 2>/dev/null)
CACHE_KEY=$(echo "$REPO_ROOT:$BRANCH" | md5)
CACHE_FILE="$CACHE_DIR/$CACHE_KEY"

mkdir -p "$CACHE_DIR"

# Check cache first
if [ -f "$CACHE_FILE" ]; then
  CACHED_VALUE=$(cat "$CACHE_FILE")
  CACHE_AGE=$(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)))

  # Use different TTL based on whether we have a PR or not
  if [ -n "$CACHED_VALUE" ]; then
    CACHE_TTL=$CACHE_TTL_WITH_PR
  else
    CACHE_TTL=$CACHE_TTL_NO_PR
  fi

  if [ "$CACHE_AGE" -lt "$CACHE_TTL" ]; then
    # Cache is fresh, return it immediately
    echo "$CACHED_VALUE"
    exit 0
  fi
fi

# Cache is stale or missing, check if background fetch is already running
LOCK_FILE="$CACHE_FILE.lock"
if [ -f "$LOCK_FILE" ]; then
  # Background fetch in progress, return cached value if exists
  if [ -f "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
  fi
  exit 0
fi

# Start background fetch
(
  touch "$LOCK_FILE"
  PR_NUM=$(gh pr view --json number --jq '.number' 2>/dev/null)
  if [ -n "$PR_NUM" ] && [ "$PR_NUM" -eq "$PR_NUM" ] 2>/dev/null; then
    echo "$PR_NUM" > "$CACHE_FILE"
  else
    # No PR, cache empty result
    echo "" > "$CACHE_FILE"
  fi
  rm -f "$LOCK_FILE"
) &

# Return cached value if exists (even if stale)
if [ -f "$CACHE_FILE" ]; then
  cat "$CACHE_FILE"
fi
