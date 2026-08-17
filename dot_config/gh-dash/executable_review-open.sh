#!/usr/bin/env bash
# review-open.sh — open a PR-review window layout (Octo / hunk / Claude / ENHANCE)
# for one PR in tmux/herdr windows. Dispatches on <mode> to match each gh-dash
# `prs` binding.
#
#   review-open.sh <mode> <pr-number> <repo-name> <repo-path>
#
#   mode       binding  windows
#   ---------  -------  --------------------------------------------------
#   full       P        Octo (auto-review) + Claude /review-lavish + ENHANCE
#   octo       enter    Octo
#   diff       D        hunk + Claude /hunk-review
#   enhance    E        ENHANCE
#   claude     A        Claude /review
#   fan        F        Octo + sealed Opus/Codex finders + Lavish merge owner + ENHANCE
#
# Invoked BACKGROUNDED by the gh-dash bindings (`nohup bash review-open.sh ... &`).
# That detachment is the whole point: the first `mux window` call runs
# `tmux new-window` (no -d), which steals the active window away from gh-dash
# while gh-dash is still running the keybind command. gh-dash then tears that
# command down with SIGTERM (`exit status 143`) before the chain finishes.
# Running the chain detached means gh-dash sees an instant exit 0, and the focus
# switch to the review windows happens after gh-dash has restored its TUI.
# `full` opts out of that switch entirely via --no-focus; the rest still take it.

set -euo pipefail

mode="${1:?review-open: missing <mode>}"
pr="${2:?review-open: missing <pr-number>}"
repo="${3:?review-open: missing <repo-name>}"
repo_path="${4:?review-open: missing <repo-path>}"

# Detached from gh-dash's terminal, so send our own output to a log and surface
# failures (e.g. treehouse pool exhausted) as a multiplexer message instead of
# swallowing them. The log MUST live outside the review-worktree state dir
# (~/.local/state/gh-review-worktrees), which `review-worktree.sh sweep`
# iterates as one-file-per-PR — a log file in there is mistaken for a lease.
LOG="${XDG_STATE_HOME:-$HOME/.local/state}/gh-review-open.log"
mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
echo "=== $(date '+%Y-%m-%d %H:%M:%S') mode=$mode PR $pr ($repo) ==="

notify_fail() {
  local rc=$?
  [ "$rc" -eq 0 ] && return 0
  local msg="review-open: $mode PR $pr failed (exit $rc) — see $LOG"
  case "$("$HOME/.local/bin/mux/mux" kind)" in
    herdr) "${HERDR_BIN_PATH:-herdr}" notification show "gh-dash review" --body "$msg" --sound request >/dev/null 2>&1 || true ;;
    tmux) tmux display-message -d 6000 "$msg" 2>/dev/null || true ;;
  esac
}
trap notify_fail EXIT

# MUX is overridable so the command strings can be dry-run with `MUX=echo`.
mux_bin="${MUX:-$HOME/.local/bin/mux/mux}"
window_opts=()
mux() {
  if [ "$mux_bin" = echo ]; then
    echo ${window_opts[@]+"${window_opts[@]}"} "$@"
  else
    "$mux_bin" window ${window_opts[@]+"${window_opts[@]}"} "$@"
  fi
}
wt_script="$HOME/.config/gh-dash/review-worktree.sh"

cd "$repo_path"

base_ref() { gh pr view "$pr" --json baseRefName -q .baseRefName; }
head_ref() { gh pr view "$pr" --json headRefName -q .headRefName; }

# After the checkout, not at lease time - post_create would resolve master's manifests (see install-deps.sh).
install_deps() { "$HOME/.config/treehouse/install-deps.sh" "$1" || true; }

open_octo() {
  local cwd="$1" auto="$2" extra=""
  [ "$auto" = 1 ] && extra=' --cmd "let g:octo_auto_review=1"'
  mux "🐙 #$pr" "$cwd" "nvim --cmd \"let g:zen_disabled=1\"$extra -c \":silent Octo pr edit $pr\""
}

# --watch here, not the global preference, so ad-hoc `hunk diff` holds no watcher.
open_hunk() {
  mux --print-pane "🔀 #$pr" "$1" "hunk diff --watch $2"
}

# hunk auto-draws its sidebar only at >= 220 cols and 0.17.6 has no key to preset it, so press `s`.
HUNK_SIDEBAR_AUTO_COLS=220
HUNK_SIDEBAR_MIN_COLS=71

# By PID, not path: treehouse reuses worktrees, so a stale session answers a path match too early.
hunk_pane_registered() {
  local pane_pids session_pids p s
  pane_pids="$("$mux_bin" pane-pids "$1" 2>/dev/null)"
  [ -n "$pane_pids" ] || return 1
  session_pids="$(hunk session list --json 2>/dev/null | jq -r '.sessions[]?.pid // empty')"
  [ -n "$session_pids" ] || return 1
  for p in $pane_pids; do
    for s in $session_pids; do
      [ "$p" = "$s" ] && return 0
    done
  done
  return 1
}

# Every failure path leaves the sidebar closed, since a stray `s` toggles the WRONG way.
open_hunk_sidebar() {
  local pane="$1" width tries=0
  [ "$mux_bin" = echo ] && return 0
  command -v hunk >/dev/null 2>&1 || return 0
  while [ "$tries" -lt 40 ] && ! hunk_pane_registered "$pane"; do
    sleep 0.25
    tries=$((tries + 1))
  done
  if ! hunk_pane_registered "$pane"; then
    echo "review-open: hunk never registered a session for pane $pane - sidebar left closed"
    return 0
  fi
  width="$("$mux_bin" pane-width "$pane" 2>/dev/null || true)"
  case "$width" in
    '' | *[!0-9]*)
      echo "review-open: pane width unknown for $pane - sidebar left closed"
      return 0
      ;;
  esac
  # At/above the auto width hunk already drew the sidebar, so `s` would close it.
  if [ "$width" -ge "$HUNK_SIDEBAR_AUTO_COLS" ] || [ "$width" -lt "$HUNK_SIDEBAR_MIN_COLS" ]; then
    return 0
  fi
  "$mux_bin" send-keys "$pane" s || true
}

# $3 picks the review command: `full` adds the Lavish surface, `diff` stays text-only.
open_claude_hunk() {
  local cmd="${3:-hunk-review}"
  mux --env HUNK_PANE="$2" "🔍 #$pr" "$1" \
    'eval "$($HOME/.local/bin/claude-account env)"; sleep 3; claude --dangerously-skip-permissions "/'"$cmd"' '"$pr"' pane=$HUNK_PANE"'
}

# $2 picks the command: `claude` mode uses /review, `full` uses /review-lavish.
open_claude_review() {
  local cmd="${2:-review}"
  mux "🤖 #$pr" "$1" \
    'eval "$($HOME/.local/bin/claude-account env)"; claude --dangerously-skip-permissions "/'"$cmd"' '"$pr"'"'
}

open_enhance() {
  mux "✨ #$pr" "$1" "ENHANCE_THEME=iceberg_dark gh-enhance -R $repo $pr"
}

# Brief goes to a file so no quoting form has to survive whichever shell the multiplexer uses.
write_finder_brief() {
  local wt="$1" model="$2"
  mkdir -p "$wt/.review"
  cat >"$wt/.review/brief-$model.txt" <<EOF
Review PR $pr in this worktree. Work alone: do NOT read .review/findings-*.json from any other model.
Do NOT post to GitHub, do NOT build a Lavish page, do NOT write data.js.
Write ONLY .review/findings-$model.json, shaped {"model":"$model","findings":[{file,line,side,severity,kind,summary,detail,comment}]},
severity one of blocker|important|minor|question, kind one of breaking|bug|refactor|perf|test|style|docs|wording.
When that file is complete and valid JSON, create .review/$model.done as the last action.
EOF
}

# Sealed-bid: each finder writes its own file plus a .done marker and never reads a sibling's.
open_finder_claude() {
  write_finder_brief "$1" opus
  mux --no-focus "🔎1 #$pr opus" "$1" \
    'eval "$($HOME/.local/bin/claude-account env)"; "$HOME/.local/bin/claude" --dangerously-skip-permissions "$(cat .review/brief-opus.txt)"'
}

# Pinned explicitly so the finder never drifts with pi's settings.json defaults.
open_finder_pi() {
  write_finder_brief "$1" gpt
  mux --keep-open --no-focus "🔎2 #$pr gpt" "$1" \
    'echo "◐ gpt-5.6-sol reviewing - pi -p stays silent until it seals findings-gpt.json"; pi -p --no-session --provider github-copilot --model gpt-5.6-sol --thinking high "$(cat .review/brief-gpt.txt)"'
}

open_fanout_owner() {
  mux "🤖 #$pr merge" "$1" "$HOME/.config/gh-dash/review-fanout.sh \"$1\" \"$pr\""
}

case "$mode" in
  full)
    window_opts=(--no-focus)
    WT="$("$wt_script" acquire "$pr")"
    BASE="$(base_ref)"
    HEAD="$(head_ref)"
    git -C "$WT" fetch origin "$BASE" "$HEAD" 2>/dev/null
    git -C "$WT" checkout --detach "origin/$HEAD" 2>/dev/null
    install_deps "$WT"
    open_octo "$WT" 1
    open_claude_review "$WT" review-lavish
    open_enhance "$WT"
    ;;
  fan)
    window_opts=(--no-focus)
    WT="$("$wt_script" acquire "$pr")"
    BASE="$(base_ref)"
    HEAD="$(head_ref)"
    git -C "$WT" fetch origin "$BASE" "$HEAD" 2>/dev/null
    git -C "$WT" checkout --detach "origin/$HEAD" 2>/dev/null
    install_deps "$WT"
    # A retried F re-adopts the same lease, so a prior run's .done markers would satisfy the wait instantly.
    rm -rf "${WT:?acquire returned no worktree}/.review"
    mkdir -p "$WT/.review"
    # One lease serves every window: review reads the checkout, so no finder needs its own worktree.
    open_octo "$WT" 1
    open_finder_claude "$WT"
    open_finder_pi "$WT"
    open_fanout_owner "$WT"
    open_enhance "$WT"
    ;;
  octo)
    WT="$("$wt_script" acquire "$pr")"
    HEAD="$(head_ref)"
    git -C "$WT" fetch origin "$HEAD" 2>/dev/null
    git -C "$WT" checkout --detach "origin/$HEAD" 2>/dev/null
    install_deps "$WT"
    open_octo "$WT" 0
    ;;
  diff)
    WT="$("$wt_script" acquire "$pr")"
    BASE="$(base_ref)"
    HEAD="$(head_ref)"
    git -C "$WT" fetch origin "$BASE" "$HEAD" 2>/dev/null
    git -C "$WT" checkout --detach "origin/$HEAD" 2>/dev/null
    install_deps "$WT"
    MERGE_BASE="$(git -C "$WT" merge-base "origin/$BASE" "origin/$HEAD")"
    PANE="$(open_hunk "$WT" "$MERGE_BASE")"
    open_hunk_sidebar "$PANE" &
    open_claude_hunk "$WT" "$PANE"
    ;;
  enhance)
    open_enhance "$repo_path"
    ;;
  claude)
    WT="$("$wt_script" acquire "$pr")"
    HEAD="$(head_ref)"
    git -C "$WT" fetch origin "$HEAD" 2>/dev/null
    git -C "$WT" checkout --detach "origin/$HEAD" 2>/dev/null
    install_deps "$WT"
    open_claude_review "$WT"
    ;;
  *)
    echo "review-open: unknown mode: $mode" >&2
    exit 2
    ;;
esac
