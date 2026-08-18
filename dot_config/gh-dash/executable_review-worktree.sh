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
LAVISH_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/gh-review-lavish"
# Backstop for artifacts whose slot was never reclaimed: release_pr is lease-driven and never fires for those.
LAVISH_MAX_AGE="${GH_REVIEW_LAVISH_MAX_AGE:-604800}"

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

# gh-dash `R` runs reclaim fully detached (nohup … >/dev/null 2>&1 &), so the TUI
# shows no feedback. Surface the result as a macOS toast via the unified
# ~/.local/bin/mac-notify helper (single source of truth for the
# terminal-notifier || osascript pattern; owns icon/timeout/group/fallback).
# Absolute path: reclaim runs detached, where ~/.local/bin may not be on PATH.
# -group collapses repeated R presses onto one banner. Best-effort — a notify
# failure must never abort the reclaim under set -e.
notify() {
  "$HOME/.local/bin/mac-notify" -t 'gh-dash reclaim' -m "$1" -g gh-dash-reclaim >/dev/null 2>&1 || true
}

# GNU first: on Linux `stat -f %m FILE` reads FILE as a filesystem and poisons the value.
_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

# `mux tabs` / `mux pane-cwds` enumerate the live mux, so release + sweep don't branch.
MUX="${MUX:-$HOME/.local/bin/mux/mux}"
mux_kind() { "$MUX" kind; }

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

  # Auto-release is DISABLED (release is manual via gh-dash `R` → reclaim), for both
  # tmux and herdr. Reclaim idle slots by hand with `R`.

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

  # EXPORTED, not just flagged: treehouse never forwards it to post_create, which inherits our env and keys its install-defer off it.
  export TREEHOUSE_LEASE_HOLDER="review-$pr"
  if ! wt="$(treehouse get --lease --lease-holder "review-$pr" 2>/dev/null)" || [ -z "$wt" ]; then
    echo "review-worktree: treehouse pool exhausted or unavailable (release finished reviews with R)" >&2
    exit 1
  fi

  echo "$wt" >"$state_file"
  echo "$wt"
}

release_pr() {
  # Digits only: this interpolates into an rm -rf path, and an empty value makes the tab pattern match every "#".
  case "${1:-}" in '' | *[!0-9]*) return 0 ;; esac
  local pr="$1" state_file="$STATE_DIR/$1" wt="" busy="" lavish_dir="$LAVISH_DIR/$1"
  # Read tolerantly: a concurrent sweep may remove this file between the test and the read, aborting under set -e.
  wt="$(cat "$state_file" 2>/dev/null || true)"

  # Order is load-bearing: the caller lives in the window this closes, so survivable work runs first and the fatal steps last.

  # 1. Artifact + session, ended before removal or a live session serves a page whose assets are gone. $pr guarded: empty would rm every artifact.
  if [ -n "$pr" ] && [ -d "$lavish_dir" ]; then
    busy="$(lavish_busy "$lavish_dir" || true)"
    if [ -n "$busy" ]; then
      _slog "  lavish artifact KEPT for $pr: $busy"
      notify "📋 Kept PR #$pr review page - $busy"
    else
      if command -v lavish-axi >/dev/null 2>&1; then
        lavish-axi end "$lavish_dir/review.html" >/dev/null 2>&1 || true
      fi
      rm -rf "$lavish_dir"
      _slog "  lavish artifact removed for $pr"
    fi
  fi

  # 2. Drop our own record of the lease before anything can kill us.
  [ -n "$wt" ] && rm -f "$state_file"

  # 3. The fatal tail, detached so the caller dying partway through cannot leave the pool leased. setsid is util-linux; macOS falls back to nohup.
  _detach() { if command -v setsid >/dev/null 2>&1; then setsid "$@"; else nohup "$@"; fi; }
  (
    _detach bash -c '
      # Out of the worktree first, or the reap below matches this tail own cwd and kills it before it closes the tabs.
      cd / 2>/dev/null || true
      wt="$1"; pr="$2"; mux="$3"
      if [ -n "$wt" ] && [ -d "$wt" ]; then
        # No cd into $wt: --force reaps by cwd, so from inside it treehouse racily kills itself and the slot stays leased.
        treehouse return "$wt" --force >/dev/null 2>&1 || true
        if command -v lsof >/dev/null 2>&1; then
          lsof -d cwd -Fpn 2>/dev/null | awk -v wt="$wt" "
            /^p/ { pid = substr(\$0, 2) }
            /^n/ { if (substr(\$0, 2) == wt) print pid }
          " | while read -r p; do kill "$p" 2>/dev/null || true; done || true
        fi
      fi
      "$mux" tabs \
        | awk -F"\t" -v pr="$pr" "\$2 ~ (\"#\" pr \"([^0-9]|\$)\") { print \$1 }" \
        | while IFS= read -r id; do [ -n "$id" ] && "$mux" close "$id" || true; done || true
    ' _ "$wt" "$pr" "$MUX" >/dev/null 2>&1 &
  ) 2>/dev/null
  return 0
}

# Prints why an artifact must survive teardown: a page open in a browser is invisible to any window check.
LAVISH_STATE="${LAVISH_AXI_STATE:-$HOME/.lavish-axi/state.json}"
lavish_busy() {
  local dir="$1" n=""
  command -v jq >/dev/null 2>&1 || return 1
  # jq rejects data.js (a JS object literal) silently, reading unposted comments as zero - parse it with node instead.
  if [ -f "$dir/data.js" ]; then
    if command -v node >/dev/null 2>&1; then
      n=$(node -e '
        global.window = {};
        try { require(require("path").resolve(process.argv[1])); } catch { process.exit(1); }
        const r = global.window.__REVIEW__;
        if (!r || typeof r !== "object") process.exit(1);
        process.stdout.write(String((r.pendingComments || []).length));
      ' "$dir/data.js" 2>/dev/null) || n=""
    else
      # No node: jq reads only the artifacts that happen to be strict JSON, so an empty answer means unknown, not zero.
      n=$(sed 's/^window\.__REVIEW__=//; s/;[[:space:]]*$//' "$dir/data.js" 2>/dev/null |
        jq -r '(.pendingComments // []) | length' 2>/dev/null)
    fi
    case "$n" in
      0) ;;
      '' | *[!0-9]*) echo "data.js unreadable - keeping it rather than guessing"; return 0 ;;
      *) echo "$n unsubmitted comment(s)"; return 0 ;;
    esac
  fi
  if [ -f "$LAVISH_STATE" ] && [ "$(jq -r --arg f "$dir/review.html" \
    '(.sessions // {}) | to_entries[] | select(.value.file == $f) | .value.status' \
    "$LAVISH_STATE" 2>/dev/null | head -n1)" = open ]; then
    echo "review page still open in the browser"
    return 0
  fi
  return 1
}

sweep_lavish() {
  local now d pr age busy
  [ -d "$LAVISH_DIR" ] || return 0
  now="$(date +%s)"
  for d in "$LAVISH_DIR"/*; do
    [ -d "$d" ] || continue
    pr="${d##*/}"
    # A live lease means the review is still open, and release_pr owns that one.
    [ -e "$STATE_DIR/$pr" ] && continue
    age=$((now - $(_mtime "$d")))
    [ "$age" -lt "$LAVISH_MAX_AGE" ] && continue
    busy="$(lavish_busy "$d" || true)"
    if [ -n "$busy" ]; then _slog "  lavish artifact KEPT for $pr: $busy"; continue; fi
    if command -v lavish-axi >/dev/null 2>&1; then
      lavish-axi end "$d/review.html" >/dev/null 2>&1 || true
    fi
    rm -rf "$d"
    _slog "  lavish artifact expired for $pr (age ${age}s, no lease)"
  done
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
  local reclaimed=0
  # Before the STATE_DIR bail below: an orphaned artifact outlives the lease dir it came from.
  sweep_lavish
  if [ ! -d "$STATE_DIR" ]; then
    if [ "$mode" = immediate ]; then
      notify "🧹 No idle treehouse review slots to reclaim"
    fi
    return 0
  fi
  sleep 0.3 # debounce: let the just-closed window/tab finish unlinking
  local cwds wins f pr wt now age total
  [ "$(mux_kind)" = none ] && return 0
  cwds="$("$MUX" pane-cwds || true)"
  wins="$("$MUX" tabs | cut -f2- || true)"

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
      reclaimed=$((reclaimed + 1))
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
  if [ "$mode" = immediate ]; then
    if [ "$reclaimed" -gt 0 ]; then
      notify "🧹 Reclaimed $reclaimed idle treehouse review slot$([ "$reclaimed" -eq 1 ] || echo s)"
    else
      notify "🧹 No idle treehouse review slots to reclaim"
    fi
  fi
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
