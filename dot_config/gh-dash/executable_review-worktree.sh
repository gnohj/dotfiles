#!/usr/bin/env bash
# Manage treehouse-leased git worktrees for PR review, keyed by PR number.
#
# Used by the gh-dash P/H/O bindings (acquire), the R binding (release), and a
# tmux window-unlinked hook (sweep). treehouse maintains a pool of pre-warmed
# detached worktrees; we lease one per PR under review so concurrent PRs never
# share a working directory (hunk diffs the working tree, so a shared worktree
# would corrupt overlapping reviews).
#
# Leases are pinned until explicitly returned. Each PR's slot is recorded in a
# state file. `sweep` auto-returns any slot whose PR has no remaining tmux
# windows, so finishing a review is just "close its windows" — no `R` needed
# (R stays as a manual release-now). Acquiring the same PR twice reuses its slot.
#
#   review-worktree.sh acquire <pr-number>   # prints the worktree path
#   review-worktree.sh release <pr-number>   # returns the slot, kills windows
#   review-worktree.sh sweep                 # returns every slot with no windows

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/gh-review-worktrees"

cmd="${1:-}"
pr="${2:-}"

case "$cmd" in
  acquire | release)
    if [ -z "$pr" ]; then
      echo "usage: review-worktree.sh {acquire|release} <pr-number>" >&2
      exit 2
    fi
    ;;
esac

leased_to_pr() {
  treehouse status 2>/dev/null | grep -qE "held by review-$1([^0-9]|$)"
}

acquire() {
  local pr="$1" state_file="$STATE_DIR/$1" existing wt
  mkdir -p "$STATE_DIR"

  if [ -f "$state_file" ]; then
    existing="$(cat "$state_file")"
    if [ -d "$existing" ] && leased_to_pr "$pr"; then
      echo "$existing"
      return 0
    fi
    rm -f "$state_file"
  fi

  # Reconcile: if treehouse already has a slot leased to this PR (a prior acquire
  # whose state file was lost, or two near-simultaneous presses), adopt it rather
  # than leasing a second slot — otherwise the extra lease orphans and leaks.
  existing="$(treehouse status 2>/dev/null | awk -v h="held by review-$pr" '$0 ~ h {print $3; exit}' | sed "s|^~|$HOME|")"
  if [ -n "$existing" ] && [ -d "$existing" ]; then
    echo "$existing" >"$state_file"
    echo "$existing"
    return 0
  fi

  if ! wt="$(treehouse get --lease --lease-holder "review-$pr" 2>/dev/null)" || [ -z "$wt" ]; then
    echo "review-worktree: treehouse pool exhausted or unavailable (release finished reviews with R)" >&2
    exit 1
  fi

  echo "$wt" >"$state_file"
  echo "$wt"
}

release_pr() {
  local pr="$1" state_file="$STATE_DIR/$1" wt="" p
  # Read tolerantly: concurrent sweeps (e.g. closing many windows at once) may
  # remove this file between a test and a read, which would abort under set -e.
  wt="$(cat "$state_file" 2>/dev/null || true)"

  if command -v tmux >/dev/null 2>&1; then
    tmux list-windows -a -F '#{window_id} #{window_name}' 2>/dev/null \
      | grep -E "#${pr}([^0-9]|$)" \
      | awk '{print $1}' \
      | while read -r wid; do tmux kill-window -t "$wid" 2>/dev/null || true; done || true
  fi

  # The review's processes — hunk, the Octo nvim, and their node/claude helpers —
  # ignore the SIGHUP from their tmux window closing and reparent to the tmux
  # server. Orphaned, they hold a hunk daemon session (which then collides on the
  # reused pool slot) and an fff LMDB reader slot (eventually MDB_READERS_FULL).
  # treehouse's own "return terminates processes" misses them. Reap every process
  # still rooted in this worktree so those resources drop.
  if [ -n "$wt" ] && [ -d "$wt" ] && command -v lsof >/dev/null 2>&1; then
    lsof -d cwd -Fpn 2>/dev/null | awk -v wt="$wt" '
      /^p/ { pid = substr($0, 2) }
      /^n/ { if (substr($0, 2) == wt) print pid }
    ' | while read -r p; do kill "$p" 2>/dev/null || true; done || true
  fi

  if [ -n "$wt" ]; then
    # cd into the worktree so `treehouse return` has a valid repo context even
    # when invoked from the tmux hook (arbitrary cwd).
    (cd "$wt" 2>/dev/null && treehouse return "$wt" --force) >/dev/null 2>&1 || true
    rm -f "$state_file"
  fi
  return 0
}

# Return every leased review slot whose PR no longer has any tmux window.
sweep() {
  [ -d "$STATE_DIR" ] || return 0
  command -v tmux >/dev/null 2>&1 || return 0
  sleep 0.3 # debounce: let the just-closed window finish unlinking
  local open f pr
  open="$(tmux list-windows -a -F '#{window_name}' 2>/dev/null || true)"
  for f in "$STATE_DIR"/*; do
    [ -e "$f" ] || continue
    pr="${f##*/}"
    if ! printf '%s\n' "$open" | grep -qE "#${pr}([^0-9]|$)"; then
      release_pr "$pr"
    fi
  done
  return 0
}

case "$cmd" in
  acquire) acquire "$pr" ;;
  release) release_pr "$pr" ;;
  sweep) sweep ;;
  *)
    echo "unknown command: $cmd" >&2
    exit 2
    ;;
esac
