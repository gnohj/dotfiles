#!/usr/bin/env bash
# review-e2e-budget.sh pre | post <event> - cap the wall clock one review session spends in long Bash runs.
set -uo pipefail

budget="${REVIEW_E2E_BUDGET_S:-720}"
long="${REVIEW_E2E_LONG_S:-45}"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/gh-review-lavish/budget"

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
session=$(jq -r '.session_id // ""' <<<"$input")
tool_id=$(jq -r '.tool_use_id // ""' <<<"$input")
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
[[ "$session" =~ ^[A-Za-z0-9_-]+$ ]] || exit 0
[[ "$tool_id" =~ ^[A-Za-z0-9_-]*$ ]] || tool_id=""
# Waiting on the human is not verification time.
case "$cmd" in *"lavish-axi poll"*) exit 0 ;; esac

mkdir -p "$dir"
spent_file="$dir/$session.spent"
starts="$dir/$session.starts"
spent=$(cat "$spent_file" 2>/dev/null || echo 0)

# Browser drivers and script runs; `node -e` and `python3 -` stay allowed for publishing.
looks_like_e2e() {
  grep -qE '(^|[^[:alnum:]_-])(playwright|chromium|puppeteer|chrome-devtools-axi|agent-browser|chrome-headed-bg)([^[:alnum:]_]|$)|(^|[^[:alnum:]_])node +[^- ][^ ]*\.[cm]?[jt]s([^[:alnum:]_]|$)|(^|[^[:alnum:]_])python3? +[^- ][^ ]*\.py([^[:alnum:]_]|$)|(^|[^[:alnum:]_])timeout +[0-9]' <<<"$1"
}

case "${1:-}" in
  pre)
    find "$dir" -type f -mtime +2 -delete 2>/dev/null
    [ -n "$tool_id" ] && printf '%s %s\n' "$tool_id" "$(date +%s)" >>"$starts"
    [ "$spent" -lt "$budget" ] && exit 0
    bg=$(jq -r '.tool_input.run_in_background // false' <<<"$input")
    if [ "$bg" = true ] || looks_like_e2e "$cmd"; then
      reason="E2E budget spent: $((spent / 60)) of $((budget / 60)) minutes already went to long-running commands in this review. Stop verifying. Publish now with what you have: any claim not yet confirmed goes on the page as unverified, saying what would confirm it. Record friction kind e2e-budget-spent."
      jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
    fi
    ;;
  post)
    ms=$(jq -r '.duration_ms // empty' <<<"$input")
    if [ -n "$ms" ]; then
      secs=$((${ms%.*} / 1000))
    else
      start=$(awk -v id="$tool_id" '$1 == id { s = $2 } END { print s }' "$starts" 2>/dev/null)
      secs=$(($(date +%s) - ${start:-$(date +%s)}))
    fi
    [ "$secs" -ge "$long" ] || exit 0
    spent=$((spent + secs))
    printf '%s\n' "$spent" >"$spent_file"
    note="E2E time used: $((spent / 60)) of $((budget / 60)) minutes. Past the budget, browser and script runs are refused, so spend what is left on the claim that matters most."
    jq -n --arg n "$note" --arg e "$2" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$n}}'
    ;;
esac
exit 0
