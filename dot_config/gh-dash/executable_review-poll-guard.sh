#!/usr/bin/env bash
# Stop hook: a review agent may not end its turn while its open Lavish page has nobody polling it.
set -uo pipefail

cat >/dev/null
pr="${REVIEW_LAVISH_PR:-}"
case "$pr" in '' | *[!0-9]*) exit 0 ;; esac

dir="${REVIEW_LAVISH_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/gh-review-lavish}/$pr"
artifact="$dir/review.html"
[ -f "$artifact" ] || exit 0

status=$(jq -r --arg f "$artifact" '[.sessions[]? | select(.file == $f) | .status] | first // empty' "${LAVISH_AXI_STATE_DIR:-$HOME/.lavish-axi}/state.json" 2>/dev/null)
case "$status" in open | feedback) ;; *) exit 0 ;; esac

if [ -f "$dir/data.js" ] && command -v node >/dev/null 2>&1 &&
  node -e 'global.window={}; require(process.argv[1]); process.exit(window.__REVIEW__ && window.__REVIEW__.submitted ? 0 : 1)' "$dir/data.js" 2>/dev/null; then
  exit 0
fi

pgrep -f "lavish-axi poll .*$artifact" >/dev/null 2>&1 && exit 0

# Three refusals in ten minutes means poll keeps returning at once; let the agent stop and explain instead of looping.
blocks="$dir/.stop-guard"
now=$(date +%s)
recent=$(awk -v now="$now" 'now - $1 < 600' "$blocks" 2>/dev/null | wc -l | tr -d ' ')
[ "${recent:-0}" -ge 3 ] && exit 0
echo "$now" >>"$blocks"

jq -n --arg artifact "$artifact" --arg pr "$pr" '{
  decision: "block",
  reason: "The Lavish review page for PR \($pr) is open and nothing is polling it, so the reviewer'"'"'s buttons reach no one. Run `lavish-axi poll \($artifact)` in the foreground now and handle what it returns. End the turn only after the session is ended or the review is submitted."
}'
