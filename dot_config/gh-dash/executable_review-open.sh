#!/usr/bin/env bash
# review-open.sh — open a PR-review window layout (Octo / hunk / Claude / ENHANCE)
# for one PR in tmux/herdr windows. Dispatches on <mode> to match each gh-dash
# `prs` binding.
#
#   review-open.sh <mode> <pr-number> <repo-name> <repo-path>
#
#   mode       binding  windows
#   ---------  -------  --------------------------------------------------
#   full       P        Octo (auto-review) + hunk + Claude /hunk-review + ENHANCE
#   octo       enter    Octo
#   diff       D        hunk + Claude /hunk-review
#   enhance    E        ENHANCE
#   claude     A        Claude /review
#
# Invoked BACKGROUNDED by the gh-dash bindings (`nohup bash review-open.sh ... &`).
# That detachment is the whole point: the first `mux-window.sh` call runs
# `tmux new-window` (no -d), which steals the active window away from gh-dash
# while gh-dash is still running the keybind command. gh-dash then tears that
# command down with SIGTERM (`exit status 143`) before the chain finishes.
# Running the chain detached means gh-dash sees an instant exit 0, and the focus
# switch to the review windows happens after gh-dash has restored its TUI.

set -euo pipefail

mode="${1:?review-open: missing <mode>}"
pr="${2:?review-open: missing <pr-number>}"
repo="${3:?review-open: missing <repo-name>}"
repo_path="${4:?review-open: missing <repo-path>}"

# Detached from gh-dash's terminal, so send our own output to a log and surface
# failures (e.g. treehouse pool exhausted) via a tmux status message instead of
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
  if [ -n "${TMUX:-}" ]; then
    tmux display-message -d 6000 "review-open: $mode PR $pr failed (exit $rc) — see $LOG" 2>/dev/null || true
  fi
}
trap notify_fail EXIT

# MUX is overridable so the command strings can be dry-run with `MUX=echo`.
mux="${MUX:-$HOME/.local/bin/mux-window.sh}"
wt_script="$HOME/.config/gh-dash/review-worktree.sh"

cd "$repo_path"

base_ref() { gh pr view "$pr" --json baseRefName -q .baseRefName; }
head_ref() { gh pr view "$pr" --json headRefName -q .headRefName; }

open_octo() {
  local cwd="$1" auto="$2" extra=""
  [ "$auto" = 1 ] && extra=' --cmd "let g:octo_auto_review=1"'
  "$mux" "🐙 #$pr" "$cwd" "nvim --cmd \"let g:zen_disabled=1\"$extra -c \":silent Octo pr edit $pr\""
}

open_hunk() {
  "$mux" --print-pane "🔀 #$pr" "$1" "hunk diff $2"
}

open_claude_hunk() {
  "$mux" --env HUNK_PANE="$2" "🔍 #$pr" "$1" \
    'eval "$($HOME/.local/bin/claude-account env)"; sleep 3; claude --dangerously-skip-permissions "/hunk-review '"$pr"' pane=$HUNK_PANE"'
}

open_claude_review() {
  "$mux" "🤖 #$pr" "$1" \
    'eval "$($HOME/.local/bin/claude-account env)"; claude --dangerously-skip-permissions "/review '"$pr"'"'
}

open_enhance() {
  "$mux" "✨ #$pr" "$1" "ENHANCE_THEME=iceberg_dark gh-enhance -R $repo $pr"
}

case "$mode" in
  full)
    WT="$("$wt_script" acquire "$pr")"
    BASE="$(base_ref)"
    HEAD="$(head_ref)"
    git -C "$WT" fetch origin "$BASE" "$HEAD" 2>/dev/null
    git -C "$WT" checkout --detach "origin/$HEAD" 2>/dev/null
    MERGE_BASE="$(git -C "$WT" merge-base "origin/$BASE" "origin/$HEAD")"
    open_octo "$WT" 1
    PANE="$(open_hunk "$WT" "$MERGE_BASE")"
    open_claude_hunk "$WT" "$PANE"
    open_enhance "$WT"
    ;;
  octo)
    WT="$("$wt_script" acquire "$pr")"
    HEAD="$(head_ref)"
    git -C "$WT" fetch origin "$HEAD" 2>/dev/null
    git -C "$WT" checkout --detach "origin/$HEAD" 2>/dev/null
    open_octo "$WT" 0
    ;;
  diff)
    WT="$("$wt_script" acquire "$pr")"
    BASE="$(base_ref)"
    HEAD="$(head_ref)"
    git -C "$WT" fetch origin "$BASE" "$HEAD" 2>/dev/null
    git -C "$WT" checkout --detach "origin/$HEAD" 2>/dev/null
    MERGE_BASE="$(git -C "$WT" merge-base "origin/$BASE" "origin/$HEAD")"
    PANE="$(open_hunk "$WT" "$MERGE_BASE")"
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
    open_claude_review "$WT"
    ;;
  *)
    echo "review-open: unknown mode: $mode" >&2
    exit 2
    ;;
esac
