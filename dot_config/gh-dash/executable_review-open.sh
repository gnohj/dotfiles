#!/usr/bin/env bash
# review-open.sh — open a PR-review window layout (Octo / hunk / Claude / ENHANCE)
# for one PR in tmux/herdr windows. Dispatches on <mode> to match each gh-dash
# `prs` binding.
#
#   review-open.sh <mode> <pr-number> <repo-name> <repo-path>
#
#   mode       binding  windows
#   ---------  -------  --------------------------------------------------
#   full       P        Octo PR view + Claude /review-lavish
#   octo       enter    Octo
#   diff       D        hunk + Claude /hunk-review
#   enhance    E        ENHANCE
#   claude     A        Claude /review
#   fan        F        Octo PR view + sealed Opus/gpt finders + Lavish merge owner
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
case "$pr" in '' | *[!0-9]*) echo "review-open: PR must be numeric" >&2; exit 2 ;; esac
[[ "$repo" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || { echo "review-open: invalid repository" >&2; exit 2; }

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

# Scope-driven profile, shared by every mode so P and F reason at the same depth on the same PR.
REVIEW_CLAUDE_MODEL="" REVIEW_CLAUDE_EFFORT="" REVIEW_FINDER_MODEL="" REVIEW_FINDER_THINKING="" REVIEW_FINDER_RUNG_TIMEOUT="" REVIEW_DISPATCH_TIER=""
IFS=$'\t' read -r REVIEW_CLAUDE_MODEL REVIEW_CLAUDE_EFFORT REVIEW_FINDER_MODEL REVIEW_FINDER_THINKING REVIEW_FINDER_RUNG_TIMEOUT REVIEW_DISPATCH_TIER < <("$HOME/.config/gh-dash/review-dispatch.sh" "$pr" "$repo" 2>/dev/null) || true
: "${REVIEW_CLAUDE_MODEL:=claude-opus-5}" "${REVIEW_CLAUDE_EFFORT:=high}"
: "${REVIEW_FINDER_MODEL:=gpt-5.6-sol}" "${REVIEW_FINDER_THINKING:=high}" "${REVIEW_FINDER_RUNG_TIMEOUT:=600}"
export REVIEW_FINDER_MODEL REVIEW_FINDER_THINKING REVIEW_FINDER_RUNG_TIMEOUT
echo "review-open: dispatch ${REVIEW_DISPATCH_TIER:-?} -> claude $REVIEW_CLAUDE_MODEL/$REVIEW_CLAUDE_EFFORT, gpt $REVIEW_FINDER_MODEL/$REVIEW_FINDER_THINKING, timeout ${REVIEW_FINDER_RUNG_TIMEOUT}s"

base_ref() { gh pr view "$pr" --json baseRefName -q .baseRefName; }
head_ref() { gh pr view "$pr" --json headRefName -q .headRefName; }

# After the checkout, not at lease time - post_create would resolve master's manifests (see install-deps.sh).
install_deps() { "$HOME/.config/treehouse/install-deps.sh" "$1" || true; }

open_octo() {
  mux "🐙 #$pr" "$1" "nvim --cmd \"let g:zen_disabled=1\" -c \":silent Octo pr edit $pr\""
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
    'eval "$($HOME/.local/bin/claude-account env)"; CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false "$HOME/.local/bin/claude" --dangerously-skip-permissions --model '"$REVIEW_CLAUDE_MODEL"' --effort '"$REVIEW_CLAUDE_EFFORT"' "/'"$cmd"' '"$pr"'"'
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
Write ONLY .review/findings-$model.json, shaped {"model":"$model","findings":[{file,line,side,severity,kind,summary,detail:{issue,why,fix,tradeoff,snippets:[{label,file,code}],evidence:[]},comment}]},
severity one of blocker|important|minor|question, kind one of breaking|bug|refactor|perf|test|style|docs|wording.
Keep issue, why, and fix to one or two sentences each, tradeoff to one sentence, and all four under 140 words total.
Tradeoff says "None identified." when empty; use at most two snippets and keep code out of the prose fields.
Leave evidence empty because the page owner runs and links the final E2E checks after this finder completes.
When that file is complete and valid JSON, create .review/$model.done as the last action.
EOF
}

# A finder that dies leaves no marker, so the owner waits out its FULL timeout before falling back - a 429 on
# the gpt finder cost 30 minutes per fan-out. Seal a .failed on exit whenever the agent's own .done is absent.
# The exit code only, never the output: both finders are interactive TUIs and piping them through tee to capture
# an error message hands them a non-tty. The message stays readable in the pane, which is what --keep-open is for.
seal_on_exit() {
  printf '; rc=$?; [ -f .review/%s.done ] || printf "finder exited (%%s) without writing %s.done\\n" "$rc" > .review/%s.failed' "$1" "$1" "$1"
}

# Sealed-bid: each finder writes its own file plus a .done marker and never reads a sibling's.
open_finder_claude() {
  write_finder_brief "$1" opus
  mux --no-focus "🔎1 #$pr opus" "$1" \
    'eval "$($HOME/.local/bin/claude-account env)"; "$HOME/.local/bin/claude" --dangerously-skip-permissions --model '"$REVIEW_CLAUDE_MODEL"' --effort '"$REVIEW_CLAUDE_EFFORT"' "$(cat .review/brief-opus.txt)"'"$(seal_on_exit opus)"
}

# The finder is pinned; $2 labels the tab with the rung resolved by --check.
open_finder_pi() {
  write_finder_brief "$1" gpt
  mux --keep-open --no-focus --env REVIEW_FINDER_MODEL="$REVIEW_FINDER_MODEL" \
    --env REVIEW_FINDER_THINKING="$REVIEW_FINDER_THINKING" \
    --env REVIEW_FINDER_RUNG_TIMEOUT="$REVIEW_FINDER_RUNG_TIMEOUT" "🔎2 #$pr ${2:-gpt}" "$1" \
    '"$HOME/.config/gh-dash/review-finder-pi.sh" gpt'"$(seal_on_exit gpt)"
}

# "pi|openai-codex|gpt-5.6-sol" -> "sol"; a harness-only rung like "codex|-|-" keeps the harness name.
finder_label() {
  local rung="$1" model="${1##*|}"
  case "$model" in '' | '-') printf '%s' "${rung%%|*}" ;; *) printf '%s' "${model##*-}" ;; esac
}

open_fanout_owner() {
  mux "🤖 #$pr merge" "$1" "$HOME/.config/gh-dash/review-fanout.sh \"$1\" \"$pr\""
}

background_review() {
  local desktop_mode=tailnet cdp=""
  if [ "${REVIEW_NO_BROWSER:-}" = 1 ]; then
    desktop_mode=print
  fi
  window_opts=(--no-focus --env AGENT_BROWSER_HEADLESS=1 --env PLAYWRIGHT_MCP_HEADLESS=1 --env LAVISH_DESKTOP_MODE="$desktop_mode" --env LAVISH_DESKTOP_BACKGROUND=1)
  if [ "${REVIEW_NO_BROWSER:-}" = 1 ]; then
    window_opts+=(--env AUTO_REVIEW=1)
  fi
  # The skill picks headed at runtime for visual/login PRs, so pre-start one and hand drivers a CDP endpoint; with no endpoint the headless env above still stands.
  if [ "${REVIEW_NO_BROWSER:-}" != 1 ] && cdp="$("$HOME/.local/bin/chrome-headed-bg" ensure "review-$pr" 2>&1)" && [ -n "$cdp" ]; then
    echo "review-open: headed browser attached at $cdp (background, no focus)"
    window_opts+=(--env AGENT_BROWSER_CDP_URL="$cdp" --env CHROME_DEVTOOLS_AXI_BROWSER_URL="$cdp" --env PLAYWRIGHT_MCP_CDP_ENDPOINT="$cdp")
  else
    echo "review-open: no background browser (${cdp:-unavailable}) - drivers stay headless"
  fi
}

case "$mode" in
  full)
    background_review
    WT="$("$wt_script" acquire "$pr")"
    BASE="$(base_ref)"
    HEAD="$(head_ref)"
    git -C "$WT" fetch origin "$BASE" "$HEAD" 2>/dev/null
    git -C "$WT" checkout --detach "origin/$HEAD" 2>/dev/null
    install_deps "$WT"
    open_octo "$WT"
    open_claude_review "$WT" review-lavish
    ;;
  resume)
    background_review
    WT="$("$wt_script" acquire "$pr")"
    BASE="$(base_ref)"
    HEAD="$(head_ref)"
    git -C "$WT" fetch origin "$BASE" "$HEAD" 2>/dev/null
    git -C "$WT" checkout --detach "origin/$HEAD" 2>/dev/null
    install_deps "$WT"
    open_claude_review "$WT" review-lavish
    ;;
  fan)
    background_review
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
    open_octo "$WT"
    open_finder_claude "$WT"
    # Ask BEFORE spawning: with every second-model rung pruned or refusing, the gpt tab only ever renders an error
    # and the owner then waits for a seal that cannot arrive. Degrade to a one-finder review up front instead, and
    # tell the owner to expect one bid so it merges immediately rather than sitting out its timeout.
    if RUNG=$(cd "$WT" && "$HOME/.config/gh-dash/review-finder-pi.sh" --check 2>/dev/null | tail -n1); [ -n "$RUNG" ]; then
      open_finder_pi "$WT" "$(finder_label "$RUNG")"
    else
      echo "review-open: no second finder is available (copilot/codex both refusing) - single-finder review"
      window_opts+=(--env REVIEW_FANOUT_EXPECTED=1)
    fi
    open_fanout_owner "$WT"
    ;;
  octo)
    WT="$("$wt_script" acquire "$pr")"
    HEAD="$(head_ref)"
    git -C "$WT" fetch origin "$HEAD" 2>/dev/null
    git -C "$WT" checkout --detach "origin/$HEAD" 2>/dev/null
    install_deps "$WT"
    open_octo "$WT"
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
