#!/usr/bin/env bash
# review-fanout.sh <worktree> <pr-number> - wait for the sealed finders, then run the Lavish merge owner.
set -uo pipefail

wt="${1:?review-fanout: missing <worktree>}"
pr="${2:?review-fanout: missing <pr-number>}"
expected="${REVIEW_FANOUT_EXPECTED:-2}"
timeout="${REVIEW_FANOUT_TIMEOUT:-1800}"

cd "$wt" || exit 1
mkdir -p .review

# Sealed-bid: agreement is meaningless if a finder saw its sibling; .done also avoids half-written JSON.
waited=0
while [ "$waited" -lt "$timeout" ]; do
  count=$(find .review -maxdepth 1 -name '*.done' 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -ge "$expected" ] && break
  printf '\r  waiting for sealed reviews: %s/%s  (%ss)' "$count" "$expected" "$waited"
  sleep 5
  waited=$((waited + 5))
done
printf '\n'

sealed=$(find .review -maxdepth 1 -name 'findings-*.json' 2>/dev/null | sort | tr '\n' ' ')

if [ -z "$sealed" ]; then
  echo "review-fanout: no finder produced a sealed findings file after ${waited}s."
  echo "Falling back to a single-model review."
  MERGE_BRIEF=""
else
  echo "review-fanout: merging $sealed"
  # A finder that timed out is disclosed rather than silently treated as "found nothing".
  MISSING=""
  [ "$(find .review -maxdepth 1 -name '*.done' | wc -l | tr -d ' ')" -lt "$expected" ] &&
    MISSING=" One or more finders did not finish within ${timeout}s, so this merge is incomplete - say so in the overview."

  MERGE_BRIEF="

Two independent reviews of this PR were produced BEFORE this session and sealed on disk: ${sealed}.
Each file is {\"model\":..., \"findings\":[{file,line,side,severity,kind,summary,detail,comment}]} - already the page's schema.

Your job is to MERGE them, not to review from scratch:
- Same file+line raised by BOTH models: keep it, and say in detail that both models raised it independently.
- Raised by ONE model: keep it, naming the source model in detail.
- The two DISAGREE about the same code: render it as severity question rather than dropping either side.
Never drop a finding silently.${MISSING}"
fi

eval "$($HOME/.local/bin/claude-account env)"
exec "$HOME/.local/bin/claude" --dangerously-skip-permissions "/review-lavish ${pr}${MERGE_BRIEF}"
