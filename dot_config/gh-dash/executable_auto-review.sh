#!/usr/bin/env bash
set -euo pipefail

case "$(uname -s)" in
  Darwin) export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" ;;
  Linux) export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin" ;;
  *) export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin" ;;
esac

STATE_DIR="${GH_AUTO_REVIEW_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/gh-auto-review}"
REVIEWED="$STATE_DIR/reviewed.tsv"
LOCK_DIR="$STATE_DIR/lock"
LOG="$STATE_DIR/auto-review.log"
FILTER="${GH_AUTO_REVIEW_FILTER:-$HOME/.config/gh-dash/review-filter-bots.sh}"
REVIEW_OPEN="${GH_AUTO_REVIEW_LAUNCHER:-$HOME/.config/gh-dash/review-open.sh}"
REVIEW_WORKTREE="${GH_AUTO_REVIEW_WORKTREE:-$HOME/.config/gh-dash/review-worktree.sh}"
REVIEW_DISPATCH="${GH_AUTO_REVIEW_DISPATCH:-$HOME/.config/gh-dash/review-dispatch.sh}"
MODE_OVERRIDE="${GH_AUTO_REVIEW_MODE:-}"
CANDIDATES=""
STARTED_AT="$(date +%s)"
OUTCOME=failed

mkdir -p "$STATE_DIR"

log() {
  local line
  line="$(date '+%Y-%m-%d %H:%M:%S') $*"
  printf '%s\n' "$line" >>"$LOG"
  printf '%s\n' "$line"
}

notify() {
  "$HOME/.local/bin/mac-notify" -t "Automatic PR reviews" -m "$1" -g gh-auto-review -T 12 >/dev/null 2>&1 || true
}

fail() {
  log "FAILED: $1"
  notify "$1"
  exit 1
}

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  lock_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
  case "$lock_pid" in
    '' | *[!0-9]*) ;;
    *) kill -0 "$lock_pid" 2>/dev/null && exit 0 ;;
  esac
  rm -f "$LOCK_DIR/pid"
  rmdir "$LOCK_DIR" 2>/dev/null || exit 0
  mkdir "$LOCK_DIR" 2>/dev/null || exit 0
fi
printf '%s\n' "$$" >"$LOCK_DIR/pid"

cleanup() {
  [ -z "$CANDIDATES" ] || rm -f "$CANDIDATES"
  rm -f "$LOCK_DIR/pid"
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

finish() {
  local rc="$1" elapsed status=failed
  cleanup
  elapsed=$(($(date +%s) - STARTED_AT))
  [ "$rc" -eq 0 ] && status=success
  log "=== run pid=$$ finished status=$status outcome=$OUTCOME elapsed=${elapsed}s ==="
}
trap 'finish $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
log "=== run pid=$$ started ==="

case "$MODE_OVERRIDE" in '' | full | fan) ;; *) fail "Unknown review mode: $MODE_OVERRIDE" ;; esac
for command_name in gh jq herdr; do
  command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is unavailable"
done
[ -x "$FILTER" ] || fail "Review bot filter is unavailable"
[ -x "$REVIEW_OPEN" ] || fail "Review launcher is unavailable"
[ -x "$REVIEW_DISPATCH" ] || fail "Review policy resolver is unavailable"
HERDR_SOCKET="$(herdr status server 2>/dev/null | awk '$1 == "socket:" { print $2; exit }')"
[ -n "$HERDR_SOCKET" ] || fail "Herdr server is unavailable"
VIEWER="$(gh api user --jq .login 2>/dev/null)"
[ -n "$VIEWER" ] || fail "GitHub viewer lookup failed"

CANDIDATES="$(mktemp "$STATE_DIR/candidates.XXXXXX")"
for repo in iheartradio/web iheartradio/inferno-monorepo; do
  if ! gh search prs 'draft:false' \
    --review-requested=@me \
    --state=open \
    --repo "$repo" \
    --sort=created \
    --order=asc \
    --limit=100 \
    --json number,title,author,repository,url \
    | "$FILTER" \
    | jq -r '.[] | [.repository.nameWithOwner, (.number | tostring), .title, .url] | @tsv' \
    >>"$CANDIDATES"; then
    fail "GitHub query failed for $repo"
  fi
done

sort -t $'\t' -k1,1 -k2,2n -o "$CANDIDATES" "$CANDIDATES"
touch "$REVIEWED"
[ -x "$REVIEW_WORKTREE" ] && "$REVIEW_WORKTREE" sweep >/dev/null 2>&1 || true

workspace_for_path() {
  herdr pane list 2>/dev/null | jq -r --arg path "$1" '
    [.result.panes[]? | select((.foreground_cwd // .cwd // "") == $path)]
    | first
    | .workspace_id // empty
  '
}

review_open_in_workspace() {
  herdr tab list 2>/dev/null | jq -e --arg workspace "$1" --arg pr "$2" '
    any(.result.tabs[]?; .workspace_id == $workspace and ((.label // "") | test("#" + $pr + "([^0-9]|$)")))
  ' >/dev/null
}

submitted_review_status() {
  local reviews
  if ! reviews="$(gh pr view "$2" --repo "$1" --json reviews 2>/dev/null)"; then
    printf 'error\n'
    return
  fi
  printf '%s\n' "$reviews" | jq -r --arg viewer "$VIEWER" '
    if any(.reviews[]?; .author.login == $viewer and .state != "PENDING") then "submitted" else "none" end
  '
}

backport_status() {
  local metadata
  if ! metadata="$(gh pr view "$2" --repo "$1" --json title,baseRefName,headRefName 2>/dev/null)"; then
    printf 'error\n'
    return
  fi
  printf '%s\n' "$metadata" | jq -r '
    if ((.title // "") | test("^\\[Backport #[0-9]+\\]"; "i"))
      and ((.baseRefName // "") | startswith("release/"))
      and ((.headRefName // "") | test("^backport[-/][0-9]+"; "i"))
    then "backport" else "regular" end
  '
}

PIDS=()
LABELS=()
MODES=()
URLS=()
KEYS=()

while IFS=$'\t' read -r repo pr title url; do
  [ -n "$repo" ] && [ -n "$pr" ] || continue
  key="$repo"$'\t'"$pr"
  grep -Fqx "$key" "$REVIEWED" && continue
  review_status="$(submitted_review_status "$repo" "$pr")"
  case "$review_status" in
    submitted)
      printf '%s\n' "$key" >>"$REVIEWED"
      log "Recorded submitted review for $repo#$pr"
      continue
      ;;
    none) ;;
    *) fail "Could not read review status for $repo#$pr" ;;
  esac

  backport="$(backport_status "$repo" "$pr")"
  case "$backport" in
    backport)
      log "Approving backport $repo#$pr ($title)"
      notify "Approving backport $repo#$pr"
      gh pr review "$pr" --repo "$repo" --approve &
      PIDS+=("$!")
      LABELS+=("$repo#$pr")
      MODES+=(approve)
      URLS+=("$url")
      KEYS+=("$key")
      continue
      ;;
    regular) ;;
    *) fail "Could not classify $repo#$pr" ;;
  esac

  case "$repo" in
    iheartradio/web) repo_path="$HOME/Developer/web/review" ;;
    iheartradio/inferno-monorepo) repo_path="$HOME/Developer/inferno/review" ;;
    *) continue ;;
  esac

  workspace_id="$(workspace_for_path "$repo_path" || true)"
  if [ -z "$workspace_id" ]; then
    log "Skipped $repo#$pr: review workspace is not open"
    notify "Skipped $repo#$pr because its review workspace is not open"
    continue
  fi
  if review_open_in_workspace "$workspace_id" "$pr"; then
    log "Skipped $repo#$pr: review tabs are already open"
    continue
  fi

  mode="$MODE_OVERRIDE"
  [ -n "$mode" ] || mode="$("$REVIEW_DISPATCH" --mode "$pr" "$repo")"
  case "$mode" in full | fan) ;; *) fail "Review policy returned an invalid mode for $repo#$pr" ;; esac
  log "Starting $mode review for $repo#$pr ($title)"
  notify "Starting $repo#$pr in the background"
  HERDR_SOCKET_PATH="$HERDR_SOCKET" HERDR_WORKSPACE_ID="$workspace_id" AUTO_REVIEW=1 REVIEW_NO_BROWSER=1 \
    "$REVIEW_OPEN" "$mode" "$pr" "$repo" "$repo_path" &
  PIDS+=("$!")
  LABELS+=("$repo#$pr")
  MODES+=("$mode")
  URLS+=("$url")
  KEYS+=("$key")
done <"$CANDIDATES"

failed=0
for ((index = 0; index < ${#PIDS[@]}; index++)); do
  if wait "${PIDS[$index]}"; then
    if [ "${MODES[$index]}" = approve ]; then
      printf '%s\n' "${KEYS[$index]}" >>"$REVIEWED"
      log "Approved backport ${LABELS[$index]} (${URLS[$index]})"
    else
      log "Started ${MODES[$index]} review for ${LABELS[$index]} (${URLS[$index]})"
    fi
  else
    if [ "${MODES[$index]}" = approve ]; then
      log "FAILED: Could not approve backport ${LABELS[$index]}"
      notify "Could not approve backport ${LABELS[$index]}"
    else
      log "FAILED: Could not start the review for ${LABELS[$index]}"
      notify "Could not start the review for ${LABELS[$index]}"
    fi
    failed=$((failed + 1))
  fi
done

if [ "${#PIDS[@]}" -eq 0 ]; then
  log "No new review requests"
  OUTCOME=idle
elif [ "$failed" -gt 0 ]; then
  OUTCOME="partial:${#PIDS[@]}-launched:$failed-failed"
  exit 1
else
  OUTCOME="started:${#PIDS[@]}"
fi
