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
# A .failed counts as settled, not as still-running: review-open.sh seals one when a finder exits without its
# own .done, so a 429 ends the wait now instead of burning the full timeout for a finder that is already dead.
waited=0
while [ "$waited" -lt "$timeout" ]; do
  count=$(find .review -maxdepth 1 \( -name '*.done' -o -name '*.failed' \) 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -ge "$expected" ] && break
  printf '\r  waiting for sealed reviews: %s/%s  (%ss)' "$count" "$expected" "$waited"
  sleep 5
  waited=$((waited + 5))
done
printf '\n'

failed=$(find .review -maxdepth 1 -name '*.failed' 2>/dev/null | sort)
for f in $failed; do
  printf '  finder FAILED: %s - %s\n' "$(basename "$f" .failed)" "$(head -1 "$f" 2>/dev/null)"
done

sealed=$(find .review -maxdepth 1 -name 'findings-*.json' 2>/dev/null | sort | tr '\n' ' ')

if [ -z "$sealed" ]; then
  echo "review-fanout: no finder produced a sealed findings file after ${waited}s."
  echo "Falling back to a single-model review."
  MERGE_BRIEF=""
else
  echo "review-fanout: merging $sealed"
  # A finder that fell down its ladder sealed under a DIFFERENT model, and models[] is the page's attribution -
  # so the merge is told what actually produced each bid rather than assuming the slot name.
  RAN=""
  for m in .review/*.model; do
    [ -f "$m" ] || continue
    RAN="$RAN
$(basename "$m" .model) actually ran on $(head -1 "$m")."
  done
  [ -n "$RAN" ] && RAN="

Model attribution for models[] - use these, not the slot names:$RAN"
  # A finder that timed out is disclosed rather than silently treated as "found nothing". A finder that DIED is
  # disclosed by name and reason, because "gpt hit its quota" and "gpt found nothing" mean opposite things to a reader.
  MISSING=""
  if [ -n "$failed" ]; then
    for f in $failed; do
      MISSING="$MISSING The $(basename "$f" .failed) finder did not run to completion ($(head -1 "$f" 2>/dev/null)), so its perspective is MISSING from this merge - say so in the overview and do not present this as a two-model agreement."
    done
  elif [ "$(find .review -maxdepth 1 -name '*.done' | wc -l | tr -d ' ')" -lt "$expected" ]; then
    MISSING=" One or more finders did not finish within ${timeout}s, so this merge is incomplete - say so in the overview."
  fi

  MERGE_BRIEF="

Two independent reviews of this PR were produced BEFORE this session and sealed on disk: ${sealed}.
Each file is {\"model\":..., \"findings\":[{file,line,side,severity,kind,summary,detail,comment}]} - already the page's schema.

Your job is to MERGE them, not to review from scratch:
- Same file+line raised by BOTH models: keep it.
- Raised by ONE model: keep it.
- The two DISAGREE about the same code: render it as severity question rather than dropping either side, and write both positions out in detail.
Never drop a finding silently.
Every merged finding carries models[], naming which finders raised it: both slugs when they agree, one when only that model reached it.
models[] IS the attribution and the page renders it as a pill, so never restate it in prose - no \"raised by X alone\" or \"both models reached it\" openers. detail carries only what the finding itself argues.${RAN}${MISSING}"
fi

eval "$($HOME/.local/bin/claude-account env)"
exec "$HOME/.local/bin/claude" --dangerously-skip-permissions "/review-lavish ${pr}${MERGE_BRIEF}"
