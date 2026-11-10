#!/usr/bin/env bash
# One treehouse worktree per PR under review (hunk diffs the working tree, so PRs must not share one); treehouse is the only record of a lease.
#
#   review-worktree.sh acquire <pr-number>   # prints the worktree path
#   review-worktree.sh release <pr-number>   # return ONE slot by PR, closes its tabs
#   review-worktree.sh reclaim               # return EVERY idle slot now, then finish any submitted-but-untorn review (gh-dash R)
#   review-worktree.sh sweep                 # same, but waits and re-reads first (automatic callers)
#   review-worktree.sh settle                # free leases GitHub shows finished and nothing runs in (timer)
#   review-worktree.sh leases                # every review lease in every pool: pr, path, leased-at
#   review-worktree.sh path <pr-number>      # the worktree(s) leased to one PR, or nothing

set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "review-worktree: jq is required" >&2; exit 1; }

LAVISH_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/gh-review-lavish"
# Backstop for artifacts whose slot was never reclaimed: release_pr is lease-driven and never fires for those.
LAVISH_MAX_AGE="${GH_REVIEW_LAVISH_MAX_AGE:-604800}"

# A fresh lease has no pane yet, so a sweep must not return it.
SWEEP_GRACE="${GH_REVIEW_SWEEP_GRACE:-30}"
SWEEP_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/gh-review-sweep.log"
mkdir -p "${SWEEP_LOG%/*}"

# tmux listings flicker under churn, so an automatic sweep waits this long and re-reads.
SWEEP_CONFIRM="${GH_REVIEW_SWEEP_CONFIRM:-8}"

_slog() {
  printf '%s [%s] %s\n' "$(date '+%H:%M:%S')" "$$" "$*" >>"$SWEEP_LOG" 2>/dev/null || true
}

# reclaim runs detached with no TUI feedback, so toast the result; a failed notify must never abort it under set -e.
notify() {
  "$HOME/.local/bin/mac-notify" -t 'gh-dash reclaim' -m "$1" -g gh-dash-reclaim >/dev/null 2>&1 || true
}

# GNU first: on Linux `stat -f %m FILE` reads FILE as a filesystem and poisons the value.
_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

# macOS ships no `timeout`, and one hung `treehouse return` would otherwise wedge the whole reclaim.
_bounded() {
  local secs="$1" pid i=0
  shift
  if command -v timeout >/dev/null 2>&1; then timeout "$secs" "$@"; return; fi
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@"; return; fi
  "$@" &
  pid=$!
  while kill -0 "$pid" 2>/dev/null && [ "$i" -lt "$secs" ]; do
    sleep 1
    i=$((i + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null
    return 124
  fi
  wait "$pid"
}

MUX="${MUX:-$HOME/.local/bin/mux/mux}"

review_idle() {
  local pr="$1" wts="$2" tabs cwds wt
  tabs="$("$MUX" tabs --all-muxes)" && cwds="$("$MUX" pane-cwds --all-muxes)" || {
    _slog "  keep $pr: multiplexer listing failed"
    return 1
  }
  if printf '%s\n' "$tabs" | cut -f2- | grep -qE "#${pr}([^0-9]|$)"; then
    _slog "  keep $pr: review tab still open"
    return 1
  fi
  while IFS= read -r wt; do
    if [ -n "$wt" ] && cwd_in_worktree "$cwds" "$wt"; then
      _slog "  keep $pr: pane still open in $wt"
      return 1
    fi
  done <<<"$wts"
  return 0
}

# True when a line of $1 is $2 or below it; prefix-safe, so /a/b does not match /a/bc.
cwd_in_worktree() {
  printf '%s\n' "$1" | awk -v wt="$2" '$0 == wt || index($0, wt "/") == 1 { f = 1 } END { exit f ? 0 : 1 }'
}

# /proc first: the VPS has no lsof.
_process_cwds() {
  if [ -d /proc/self ]; then
    for p in /proc/[0-9]*/cwd; do readlink "$p" 2>/dev/null || true; done
  elif command -v lsof >/dev/null 2>&1; then
    lsof -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' || true
  else
    return 1
  fi
}

# Unknown counts as occupied: this backs a destructive release.
_occupied() {
  local cwds
  cwds="$(_process_cwds)" || return 0
  cwd_in_worktree "$cwds" "$1"
}

# -u on macOS: GitHub timestamps are UTC, and a local-time parse shifts them by the zone offset.
_epoch() { date -d "$1" +%s 2>/dev/null || date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null || echo 0; }

cmd="${1:-}"
pr="${2:-}"

case "$cmd" in
  acquire | release | path)
    if [ -z "$pr" ]; then
      echo "usage: review-worktree.sh {acquire|release|path} <pr-number>" >&2
      exit 2
    fi
    ;;
esac

_leases() {
  local f
  for f in "$HOME"/.treehouse/*/treehouse-state.json; do
    [ -f "$f" ] || continue
    jq -r '.worktrees[]? | select(.leased and ((.lease_holder // "") | test("^review-[0-9]+$"))) | [(.lease_holder | ltrimstr("review-")), .path, (.leased_at // "")] | @tsv' "$f" 2>/dev/null || true
  done
}

_lease_paths() { _leases | awk -F'\t' -v pr="$1" '$1 == pr { print $2 }'; }

# BSD date rejects treehouse's nanoseconds and colon offset.
_lease_epoch() {
  date -d "$1" +%s 2>/dev/null ||
    date -j -f '%Y-%m-%dT%H:%M:%S%z' "$(printf '%s' "$1" | sed -E 's/\.[0-9]+//; s/Z$/+0000/; s/([+-][0-9]{2}):([0-9]{2})$/\1\2/')" +%s 2>/dev/null ||
    echo 0
}

acquire() {
  local pr="$1" wt
  # This checkout's pool only; release returns every pool's slot for the PR.
  wt="$(treehouse status --json 2>/dev/null | jq -r --arg h "review-$pr" 'first(.[]? | select(.lease_holder == $h) | .path) // empty' 2>/dev/null || true)"
  if [ -n "$wt" ] && [ -d "$wt" ]; then
    echo "$wt"
    return 0
  fi

  # EXPORTED, not just flagged: treehouse never forwards it to post_create, which inherits our env and keys its install-defer off it.
  export TREEHOUSE_LEASE_HOLDER="review-$pr"
  if ! wt="$(treehouse get --lease --lease-holder "review-$pr" 2>/dev/null)" || [ -z "$wt" ]; then
    echo "review-worktree: treehouse pool exhausted or unavailable (release finished reviews with R)" >&2
    exit 1
  fi

  echo "$wt"
}

release_pr() {
  # Digits only: this interpolates into an rm -rf path, and an empty value makes the tab pattern match every "#".
  case "${1:-}" in '' | *[!0-9]*) return 0 ;; esac
  local pr="$1" mode="${2:-idle}" wts="" busy="" lavish_dir="$LAVISH_DIR/$1"
  wts="$(_lease_paths "$pr")"
  # An explicit release is the review's own teardown, run from one of the tabs it closes, so only automatic releases wait for idle.
  [ "$mode" = explicit ] || review_idle "$pr" "$wts" || return 1

  # End idle review resources before returning the worktree.

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

  # Stop the background browser before returning its worktree.
  "$HOME/.local/bin/chrome-headed-bg" stop "review-$pr" >/dev/null 2>&1 || true

  # Detach the return so process cleanup cannot interrupt it.
  _detach() {
    if command -v setsid >/dev/null 2>&1; then
      setsid "$@"
    elif command -v perl >/dev/null 2>&1; then
      # macOS has no setsid, and nohup leaves the tail in the caller's process group - killed with the pane.
      perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV or exit 127' -- "$@"
    else
      nohup "$@"
    fi
  }
  (
    _detach bash -c '
      # Return from outside the worktree to survive process cleanup.
      cd / 2>/dev/null || true
      wts="$1"; pr="$2"; mux="$3"; log="$4"; mode="$5"
      nl=$(printf "\nx"); nl=${nl%x}; IFS=$nl; set -f
      if [ "$mode" != explicit ]; then
        tabs=$("$mux" tabs --all-muxes) && cwds=$("$mux" pane-cwds --all-muxes) || exit 1
        printf "%s\n" "$tabs" | cut -f2- | grep -qE "#${pr}([^0-9]|$)" && exit 1
        for wt in $wts; do
          printf "%s\n" "$cwds" | awk -v wt="$wt" '\''$0 == wt || index($0, wt "/") == 1 { f = 1 } END { exit !f }'\'' && exit 1
        done
      fi
      # Every step announces itself: the tail is detached with all output discarded, so an unlogged step that dies is indistinguishable from one that worked.
      _tlog() { printf "%s [%s]   tail #%s: %s\n" "$(date +%H:%M:%S)" "$$" "$pr" "$*" >>"$log" 2>/dev/null || true; }
      [ -n "$wts" ] || _tlog "no worktree is leased to review-$pr, nothing to return"
      for wt in $wts; do
        # No cd into $wt: --force reaps by cwd, so from inside it treehouse racily kills itself and the slot stays leased.
        _tlog "treehouse return starting for $wt"
        if treehouse return "$wt" --force --if-lease-holder "review-$pr" >/dev/null 2>&1; then
          _tlog "treehouse returned $wt"
        else
          _tlog "treehouse return FAILED for $wt - still leased, the settle timer retries"
        fi
      done
      [ "$mode" = explicit ] || exit 0
      # Re-enumerate and retry: the gpt finder runs with --keep-open, so its tab never closes on its own.
      attempt=1
      while [ "$attempt" -le 3 ]; do
        ids=$("$mux" tabs | awk -F"\t" -v pr="$pr" "\$2 ~ (\"#\" pr \"([^0-9]|\$)\") { print \$1 }")
        [ -n "$ids" ] || break
        _tlog "close pass $attempt: $(printf %s "$ids" | tr "\n" " ")"
        for id in $ids; do "$mux" close "$id" >/dev/null 2>&1 || true; done
        sleep 2
        attempt=$((attempt + 1))
      done
      left=$("$mux" tabs | awk -F"\t" -v pr="$pr" "\$2 ~ (\"#\" pr \"([^0-9]|\$)\") { print \$1 \"=\" \$2 }" | tr "\n" " ")
      # A tab that survives three passes is almost certainly mux close skipping the last tab in its workspace or session.
      if [ -n "$left" ]; then _tlog "LEFTOVER after 3 passes: $left"; else _tlog "all matching tabs closed"; fi
    ' _ "$wts" "$pr" "$MUX" "$SWEEP_LOG" "$mode" >/dev/null 2>&1 &
  ) 2>/dev/null
  return 0
}

# Backstop for a review whose agent submitted then ended before its teardown: finish verifies on GitHub and refuses otherwise.
reconcile_artifacts() {
  local s out
  for s in "$HOME/Developer/agents/shared/skills/review-lavish/review-lavish-state" \
    "$HOME/.claude-work/skills/review-lavish/review-lavish-state" \
    "$HOME/.claude/skills/review-lavish/review-lavish-state"; do
    [ -x "$s" ] || continue
    out="$("$s" reconcile 2>&1 || true)"
    [ -n "$out" ] && printf '%s\n' "$out" | while IFS= read -r l; do _slog "  reconcile: $l"; done
    return 0
  done
}

_review_done() {
  local wt="$1" pr="$2" since="$3" repo state me newest
  repo="$(git -C "$wt" remote get-url origin 2>/dev/null | sed -E 's#^(git@[^:]+:|[a-z]+://([^@/]+@)?[^/]+/)##; s#\.git$##' || true)"
  [ -n "$repo" ] || return 1
  state="$(gh api "repos/$repo/pulls/$pr" -q '.merged_at // .state' 2>/dev/null)" || return 1
  case "$state" in
    closed | 20*) echo "PR merged/closed"; return 0 ;;
  esac
  me="$(gh api user -q .login 2>/dev/null)" || return 1
  newest="$(gh api "repos/$repo/pulls/$pr/reviews" --paginate --slurp 2>/dev/null |
    jq -r --arg me "$me" '[add // [] | .[] | select(.user.login == $me and .submitted_at != null) | .submitted_at] | max // empty' 2>/dev/null)"
  [ -n "$newest" ] && [ "$(_epoch "$newest")" -gt "$since" ] || return 1
  echo "review posted $newest"
}

# Timer backstop for leases finish never freed: a failed return, or a page reopened after posting.
settle() {
  local pr wt at why freed=0 done_prs=" "
  command -v gh >/dev/null 2>&1 || return 0
  # fd 3 so gh inside the loop cannot swallow the lease list.
  while IFS=$'\t' read -r -u 3 pr wt at; do
    [ -n "$wt" ] && [ -d "$wt" ] || continue
    case "$done_prs" in *" $pr "*) continue ;; esac
    _occupied "$wt" && continue
    why="$(_review_done "$wt" "$pr" "$(_lease_epoch "$at")")" || continue
    _slog "  SETTLE $pr: $why, nothing running in $wt"
    release_pr "$pr" || continue
    done_prs="$done_prs$pr "
    freed=$((freed + 1))
  done 3< <(_leases)
  [ "$freed" -eq 0 ] || notify "🧹 Freed $freed finished review slot$([ "$freed" -eq 1 ] || echo s)"
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

# A background browser outlives its review whenever release_pr never ran: drop any whose PR has neither a lease nor a window.
sweep_chrome() {
  local wins="$1" leased="$2" name pr
  while IFS=$'\t' read -r name _; do
    case "$name" in review-*) ;; *) continue ;; esac
    pr="${name#review-}"
    case "$pr" in '' | *[!0-9]*) continue ;; esac
    case " $leased " in *" $pr "*) continue ;; esac
    printf '%s\n' "$wins" | grep -qE "#${pr}([^0-9]|$)" && continue
    "$HOME/.local/bin/chrome-headed-bg" stop "$name" >/dev/null 2>&1 || true
    _slog "  stopped orphan background browser for $pr"
  done < <("$HOME/.local/bin/chrome-headed-bg" list 2>/dev/null)
  return 0
}

sweep_lavish() {
  local leased="$1" now d pr age busy
  [ -d "$LAVISH_DIR" ] || return 0
  now="$(date +%s)"
  for d in "$LAVISH_DIR"/*; do
    [ -d "$d" ] || continue
    pr="${d##*/}"
    # A live lease means the review is still open, and release_pr owns that one.
    case " $leased " in *" $pr "*) continue ;; esac
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

# A PR holding two slots keeps both while either is in use.
sweep() {
  local mode="${1:-confirm}" reclaimed=0 cwds wins pr wt at now age total leased kept=" " idle=" "
  leased="$(_leases | cut -f1 | tr '\n' ' ')"
  sweep_lavish "$leased"
  sleep 0.3 # debounce: let the just-closed window/tab finish unlinking
  if ! cwds="$("$MUX" pane-cwds --all-muxes)" ||
    ! wins="$("$MUX" tabs --all-muxes | cut -f2-)"; then
    _slog "sweep abort: multiplexer listing failed; no releases"
    return 0
  fi

  now="$(date +%s)"
  total="$(printf '%s\n' "$cwds" | grep -c . 2>/dev/null || true)"
  _slog "$mode run ($total panes total; $(printf '%s\n' "$cwds" | grep -c treehouse 2>/dev/null) under a treehouse worktree)"
  while IFS=$'\t' read -r -u 3 pr wt at; do
    [ -n "$wt" ] || continue
    age=$((now - $(_lease_epoch "$at")))
    if [ "$age" -lt "$SWEEP_GRACE" ]; then
      kept="$kept$pr "
      _slog "  skip $pr: lease age ${age}s < ${SWEEP_GRACE}s grace"
    elif printf '%s\n' "$wins" | grep -qE "#${pr}([^0-9]|$)"; then
      kept="$kept$pr "
      _slog "  keep $pr: window #${pr} still open"
    elif cwd_in_worktree "$cwds" "$wt"; then
      kept="$kept$pr "
      _slog "  keep $pr: pane present in $wt"
    else
      case "$idle" in *" $pr "*) ;; *) idle="$idle$pr " ;; esac
    fi
  done 3< <(_leases)

  for pr in $idle; do
    case "$kept" in *" $pr "*) continue ;; esac
    if [ "$mode" != immediate ]; then
      _slog "  defer $pr: window-less, re-reading in ${SWEEP_CONFIRM}s"
      sleep "$SWEEP_CONFIRM"
    fi
    _slog "  RELEASE $pr ($mode): no #${pr} window and no pane in its worktree"
    # release_pr re-reads tabs and panes: the second look.
    release_pr "$pr" || continue
    reclaimed=$((reclaimed + 1))
  done
  sweep_chrome "$wins" "$leased"
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
  release) release_pr "$pr" explicit ;;
  sweep) sweep ;;
  reclaim) sweep immediate; reconcile_artifacts ;;
  settle) settle ;;
  leases) _leases ;;
  path) _lease_paths "$pr" ;;
  *)
    echo "unknown command: $cmd" >&2
    exit 2
    ;;
esac
