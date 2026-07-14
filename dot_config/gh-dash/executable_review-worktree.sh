#!/usr/bin/env bash
# Manage treehouse-leased git worktrees for PR review, keyed by PR number.
#
# Used by the gh-dash review bindings (acquire) and the R binding (reclaim).
# treehouse maintains a pool of pre-warmed detached worktrees; we lease one per
# PR under review so concurrent PRs never share a working directory (hunk diffs
# the working tree, so a shared worktree would corrupt overlapping reviews).
#
# Leases are pinned until explicitly returned. Each PR's slot is recorded in a
# state file. Release is MANUAL: the automatic window-unlinked → sweep hook is
# disabled (it killed live reviews on transient tmux read glitches — see
# agentic.conf), so gh-dash `R` runs `reclaim` to free every slot whose review
# windows are already closed (covers PRs that merged/closed and left gh-dash,
# which a per-PR release can't reach). Acquiring the same PR twice reuses its slot.
#
#   review-worktree.sh acquire <pr-number>   # prints the worktree path
#   review-worktree.sh release <pr-number>   # return ONE slot by PR, kills its windows
#   review-worktree.sh reclaim               # return EVERY idle slot now (gh-dash R)
#   review-worktree.sh sweep                 # same, but two-strike deferred (auto; disabled)

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/gh-review-worktrees"
herdr="${HERDR_BIN_PATH:-herdr}"

# sweep grace period: a freshly-acquired lease has its worktree windows created
# ASYNCHRONOUSLY (gh-dash bindings run review-open.sh detached), so for the first
# few seconds the state file exists but NO pane sits in the worktree yet. Without
# this guard, any window-unlinked event during that setup gap makes sweep return
# the worktree out from under the still-initializing review (treehouse return
# --force terminates its processes) — the tabs flash up, then die. Skip leases
# younger than this. Override with GH_REVIEW_SWEEP_GRACE.
SWEEP_GRACE="${GH_REVIEW_SWEEP_GRACE:-30}"
SWEEP_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/gh-review-sweep.log"

# Two-strike confirmation: tmux list-windows/list-panes return INCONSISTENT
# results under churn (repeated P presses, sesh session create/destroy) — the
# review windows momentarily vanish from the listing then reappear a second
# later. A single window-less read must NOT trigger the destructive release
# (treehouse return --force kills the worktree's live processes). Instead we
# require the lease to be seen window-less on a sweep at least SWEEP_CONFIRM
# seconds after the first window-less sweep; any intervening sweep that sees the
# window cancels the pending release. Markers live in a dot-dir so the STATE_DIR
# "*" glob (one file per PR) never mistakes them for leases.
SWEEP_CONFIRM="${GH_REVIEW_SWEEP_CONFIRM:-8}"
PENDING_DIR="$STATE_DIR/.pending"

_slog() {
  printf '%s [%s] %s\n' "$(date '+%H:%M:%S')" "$$" "$*" >>"$SWEEP_LOG" 2>/dev/null || true
}

# Epoch seconds of a file's mtime (macOS BSD stat, Linux GNU stat fallback).
_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# Which multiplexer are we under? gh-dash review windows live in tmux windows on
# the Mac (off-herdr) and in herdr tabs under herdr; window/tab enumeration for
# release + sweep must follow suit. Same signal used by mux-window.sh / mux.lua.
mux_kind() {
  if [ -n "${HERDR_SOCKET_PATH:-}" ]; then echo herdr
  elif [ -n "${TMUX:-}" ]; then echo tmux
  else echo none; fi
}

# All open herdr tabs as "<tab_id>\t<label>" lines across every workspace (herdr
# tab list is per-workspace, so iterate). Best-effort: never aborts the caller.
herdr_tabs() {
  "$herdr" workspace list 2>/dev/null \
    | jq -r '.result.workspaces[]?.workspace_id // empty' 2>/dev/null \
    | while IFS= read -r ws; do
        [ -n "$ws" ] || continue
        "$herdr" tab list --workspace "$ws" 2>/dev/null \
          | jq -r '.result.tabs[]? | "\(.tab_id)\t\(.label // "")"' 2>/dev/null
      done || true
}

# Current cwd of every open herdr pane (foreground process cwd, falling back to the
# pane cwd). Used to decide whether ANY pane still sits in a leased worktree.
herdr_pane_cwds() {
  "$herdr" pane list 2>/dev/null \
    | jq -r '.result.panes[]? | (.foreground_cwd // .cwd // empty)' 2>/dev/null || true
}

# True (0) if some line in $1 is exactly $2 or a subdirectory of it — i.e. a pane
# still sits in the worktree. Prefix-safe: "/a/b" does not match "/a/bc".
cwd_in_worktree() {
  printf '%s\n' "$1" | awk -v wt="$2" '$0 == wt || index($0, wt "/") == 1 { f = 1 } END { exit f ? 0 : 1 }'
}

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

  # Auto-release is DISABLED (release is manual via gh-dash `R` → reclaim). The
  # herdr close-event sweep daemon (herdr-review-sweep.py) is intentionally NOT
  # started: besides herdr close-events it ran a 60s PERIODIC `review-worktree.sh
  # sweep`, which — decoupled from any tmux hook — kept killing live reviews on
  # its timer. Leaving it unstarted is the other half of disabling the tmux
  # window-unlinked sweep (see agentic.conf). Reclaim idle slots by hand with `R`.
  # if [ "$(mux_kind)" = herdr ]; then
  #   "$HOME/.local/bin/herdr-review-sweep.py" ensure >/dev/null 2>&1 || true
  # fi

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

  case "$(mux_kind)" in
    herdr)
      # Close every herdr tab whose label carries "#<pr>" (e.g. "2.🐙 #19156").
      herdr_tabs \
        | awk -F'\t' -v pr="$pr" '$2 ~ ("#" pr "([^0-9]|$)") { print $1 }' \
        | while IFS= read -r tid; do
            [ -n "$tid" ] && "$herdr" tab close "$tid" >/dev/null 2>&1 || true
          done || true
      ;;
    tmux)
      tmux list-windows -a -F '#{window_id} #{window_name}' 2>/dev/null \
        | grep -E "#${pr}([^0-9]|$)" \
        | awk '{print $1}' \
        | while read -r wid; do tmux kill-window -t "$wid" 2>/dev/null || true; done || true
      ;;
  esac

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
# Return every leased slot whose worktree no longer has ANY open pane in it.
# Keyed on the worktree path (the state-file contents), NOT the PR label or a
# single window: closing one of a PR's several review windows must NOT release
# the slot — only when the LAST pane sitting in that worktree is gone.
sweep() {
  # mode=confirm (default): two-strike deferral, for the (currently disabled)
  #   automatic window-unlinked sweep.
  # mode=immediate: release every idle slot on this single pass, for the manual
  #   `reclaim` command (gh-dash `R`) — frees slots for PRs that already merged /
  #   closed and dropped out of gh-dash, which no per-PR release could reach.
  local mode="${1:-confirm}"
  [ -d "$STATE_DIR" ] || return 0
  sleep 0.3 # debounce: let the just-closed window/tab finish unlinking
  local cwds wins f pr wt now age total
  case "$(mux_kind)" in
    herdr)
      cwds="$(herdr_pane_cwds || true)"
      wins="$(herdr_tabs | cut -f2- || true)"
      ;;
    tmux)
      cwds="$(tmux list-panes -a -F '#{pane_current_path}' 2>/dev/null || true)"
      wins="$(tmux list-windows -a -F '#{window_name}' 2>/dev/null || true)"
      ;;
    *) return 0 ;;
  esac

  # Guard against transient enumeration failure: this sweep was triggered BY a
  # window/tab close, so the multiplexer IS running and necessarily has at least
  # one pane and one window. If BOTH queries come back empty, the query glitched
  # (heavy server load during a session switch, etc.) — releasing on that would
  # wrongly kill EVERY live review. Bail; the next window-unlinked re-runs us.
  if [ -z "${cwds//[[:space:]]/}" ] && [ -z "${wins//[[:space:]]/}" ]; then
    _slog "sweep abort: empty pane+window enumeration (transient glitch); no releases"
    return 0
  fi

  now="$(date +%s)"
  total="$(printf '%s\n' "$cwds" | grep -c . 2>/dev/null)"
  _slog "$mode run ($total panes total; $(printf '%s\n' "$cwds" | grep -c treehouse 2>/dev/null) under a treehouse worktree)"
  for f in "$STATE_DIR"/*; do
    [ -e "$f" ] || continue
    pr="${f##*/}"
    wt="$(cat "$f" 2>/dev/null || true)"
    # Missing/empty path recorded — can't verify occupancy; leave it for R.
    [ -n "$wt" ] || continue
    # Grace period: don't sweep a lease whose review windows are still being
    # created asynchronously (see SWEEP_GRACE above).
    age=$((now - $(_mtime "$f")))
    if [ "$age" -lt "$SWEEP_GRACE" ]; then
      _slog "  skip $pr: lease age ${age}s < ${SWEEP_GRACE}s grace"
      continue
    fi
    # Occupancy: keep the lease while EITHER a review window/tab still carries
    # "#<pr>" (the primary, drift-proof signal — matches release_pr's own
    # matching) OR any pane still sits in the worktree (also preserves a
    # manually-opened shell in the tree). Only release when both are absent.
    if printf '%s\n' "$wins" | grep -qE "#${pr}([^0-9]|$)"; then
      rm -f "$PENDING_DIR/$pr"
      _slog "  keep $pr: window #${pr} still open"
    elif cwd_in_worktree "$cwds" "$wt"; then
      rm -f "$PENDING_DIR/$pr"
      _slog "  keep $pr: pane present in $wt"
    elif [ "$mode" = immediate ]; then
      _slog "  RELEASE $pr (reclaim): no #${pr} window and no pane in $wt (lease age ${age}s)"
      release_pr "$pr"
      rm -f "$PENDING_DIR/$pr"
    elif [ -f "$PENDING_DIR/$pr" ] && [ "$((now - $(_mtime "$PENDING_DIR/$pr")))" -ge "$SWEEP_CONFIRM" ]; then
      _slog "  RELEASE $pr: window-less for >=${SWEEP_CONFIRM}s, confirmed (lease age ${age}s)"
      release_pr "$pr"
      rm -f "$PENDING_DIR/$pr"
    else
      mkdir -p "$PENDING_DIR"
      [ -f "$PENDING_DIR/$pr" ] || : >"$PENDING_DIR/$pr"
      _slog "  defer $pr: window-less but unconfirmed (needs ${SWEEP_CONFIRM}s sustained absence) — likely transient churn"
    fi
  done
  return 0
}

case "$cmd" in
  acquire) acquire "$pr" ;;
  release) release_pr "$pr" ;;
  sweep) sweep ;;
  reclaim) sweep immediate ;;
  *)
    echo "unknown command: $cmd" >&2
    exit 2
    ;;
esac
