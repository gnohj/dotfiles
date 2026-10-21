#!/usr/bin/env bash
# review-finder-pi.sh <slot> - run the second finder for <slot>, walking a quota-aware ladder when a rung refuses.
#
# Provider fallback keeps the model fixed; rungs are <harness>|<provider>|<model>.
#
# Two hard-won constraints shape this:
#   * pi does NOT exit when a call fails. It prints the error and returns to its prompt, so "the command returned"
#     is not a usable signal - a 403 left pi sitting at a prompt for 6 minutes on 2026-08-21 and the ladder never
#     advanced. Only the seal on disk, plus a deadline, can move a pi rung along.
#   * quota-axi cannot see Copilot: it reports `copilot,all,no_quota,no measurable scope`, the same blind spot as
#     the credits endpoint. So quota is used to PRUNE dead candidates and prefer measured runway, never to predict
#     this particular failure. Unmeasurable is not the same as exhausted, and is still worth trying.
#
# Attribution stays honest: whatever seals is written to .review/<slot>.model, and review-fanout.sh puts that in
# the merge brief so models[] never claims a bid came from a model that refused.
#
# BILLING: rung order prefers a measured subscription harness over an api_key one. Set REVIEW_FINDER_LADDER="" to
# disable fallback entirely and fail on rung 1.
set -uo pipefail

# --check answers "could a second finder run at all right now" without running one, so the caller can decline to
# spawn a tab that is already doomed. Prints the first eligible rung and exits 0, or exits 1 with nothing eligible.
CHECK=0
[ "${1:-}" = --check ] && { CHECK=1; set -- gpt; }

slot="${1:?review-finder-pi: missing <slot>}"
brief=".review/brief-$slot.txt"
[ "$CHECK" = 1 ] || [ -f "$brief" ] || { echo "review-finder-pi: no $brief" >&2; exit 2; }

# Dispatch picks the model; quota picks Codex subscription, Copilot, then CLI, excluding the unfunded OpenAI API.
FINDER_MODEL="${REVIEW_FINDER_MODEL:-gpt-6.1-sol}"
LADDER="${REVIEW_FINDER_LADDER-pi|openai-codex|$FINDER_MODEL pi|github-copilot|$FINDER_MODEL codex|-|-}"
THINKING="${REVIEW_FINDER_THINKING:-high}"
RUNG_TIMEOUT="${REVIEW_FINDER_RUNG_TIMEOUT:-600}"

# Three orthogonal facts make a candidate a non-starter, and they live in DIFFERENT quota-axi blocks: attention[]
# carries auth_required and unavailable, while quota[]/exhaustion[] carry exhausted_now. Reading only attention[]
# missed codex sitting at 0% with runway exhausted_now, and spent a rung rediscovering it (2026-08-22).
# no_quota is deliberately NOT a skip: copilot reports it always, and unmeasurable is not the same as exhausted.
DEAD_INFO=$(quota-axi 2>/dev/null | awk -F, 'match($0, /auth_required|unavailable|exhausted_now/) {gsub(/ /, "", $1); print $1, substr($0, RSTART, RLENGTH)}' | sort -u)
DEAD=$(printf '%s\n' "$DEAD_INFO" | awk 'NF {print $1}' | sort -u)
[ -n "$DEAD" ] && echo "review-finder-pi: quota-axi reports unusable: $(printf '%s' "$DEAD" | tr '\n' ' ')"

# Every refusal is kept so the merge and the page can say WHY the second model is missing, not just that it is.
REASONS=()
refused() { REASONS+=("$1: $2"); }
classify() {
  local text lower
  text=$(printf '%s' "$1" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-140)
  lower=$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')
  case "$lower" in
    *401* | *403* | *unauthori* | *forbidden* | *"not licensed"* | *"not logged in"* | *login* | *subscription* | *plan* | *auth_required*) printf 'auth refused (subscription or login) - %s' "$text" ;;
    *429* | *quota* | *"rate limit"* | *"usage limit"* | *credits* | *exhausted*) printf 'quota or rate limit - %s' "$text" ;;
    *50[0-9]* | *overloaded* | *"fetch failed"* | *"timed out"* | *unavailable* | *websocket* | *upstream*) printf 'provider error - %s' "$text" ;;
    *) printf '%s' "${text:-no output}" ;;
  esac
}

# Normalizing provider names lets Codex exhaustion skip both its Pi and CLI rungs.
quota_name() { case "$1" in github-copilot) echo copilot ;; openai-codex) echo codex ;; *) echo "$1" ;; esac; }

sealed=0
for rung in $LADDER; do
  harness="${rung%%|*}"; rest="${rung#*|}"
  provider="${rest%%|*}"; model="${rest#*|}"
  qn=$(quota_name "${provider:--}")
  [ "$harness" = codex ] && qn=codex

  if printf '%s\n' "$DEAD" | grep -qx "$qn"; then
    echo "review-finder-pi: skipping $rung - quota-axi says $qn is unusable"
    refused "$rung" "$(classify "quota-axi $(printf '%s\n' "$DEAD_INFO" | awk -v p="$qn" '$1 == p {print $2; exit}')")"
    continue
  fi

  # codex has no cheap probe - any call spends tokens - so surviving the prune IS its eligibility answer.
  [ "$CHECK" = 1 ] && [ "$harness" = codex ] && { printf '%s\n' "$rung"; exit 0; }

  echo "review-finder-pi: $slot on $rung"
  # pi idles at its prompt after sealing, so the post-run write lands too late for the merge.
  [ "$CHECK" = 1 ] || printf '%s\n' "$rung" >".review/$slot.model"
  case "$harness" in
    codex)
      # `codex exec` is non-interactive and EXITS, so it needs no deadline and no preflight - a refusal is its exit.
      # stdin MUST be closed: with it open codex waits on "Reading additional input from stdin" and never starts.
      # workspace-write, not the read-only default: the finder's entire output is .review/findings-gpt.json plus its
      # .done marker, and a read-only sandbox answers "the workspace is read-only" and seals nothing. Not
      # danger-full-access - the brief only ever needs to write inside this worktree.
      # Reasoning effort must be set explicitly: codex exec defaults to "reasoning effort: none", so PR 19660's
      # fallback finder read the whole diff with no reasoning and sealed an empty findings[]. The pi rung it stands
      # in for runs --thinking high, and a sealed bid is only worth merging if both bids thought as hard.
      # Non-interactive, so tee is safe here; the log is what names an auth or 5xx refusal after it exits.
      codex exec --sandbox workspace-write -c model_reasoning_effort="$THINKING" "$(cat "$brief")" </dev/null 2>&1 | tee ".review/codex-$slot.log"
      rc=${PIPESTATUS[0]}
      if [ ! -f ".review/$slot.done" ] && [ "$rc" -ne 0 ]; then
        refused "$rung" "$(classify "exit $rc: $(grep -iE 'error|unauthori|forbidden|401|403|429|5[0-9][0-9]|quota|limit|subscription|plan|login' ".review/codex-$slot.log" | tail -n1)")"
        echo "review-finder-pi: $rung exited $rc, trying the next rung"
        continue
      fi
      ;;
    pi)
      pi auth check --provider "$provider" --json 2>/dev/null | grep -q '"status":"ready"' || {
        echo "review-finder-pi: $provider has no ready credential, skipping"
        refused "$rung" "auth refused (subscription or login) - pi has no ready $provider credential"
        continue
      }
      # `auth check` only proves a credential EXISTS; it says ready for a Copilot seat that answers 403 not-licensed
      # and for an OpenAI key with no credits. So probe entitlement for real before spending a rung: -p exits, and a
      # refusal comes back in about a second, against 600s of watchdog if the interactive finder is launched blind.
      if ! probe=$(pi --no-session -p --provider "$provider" --model "$model" "say ok" 2>&1) ||
        printf '%s' "$probe" | grep -qiE "error|no credits|unauthorized|quota"; then
        echo "review-finder-pi: $rung refused the preflight, skipping: $(printf '%s' "$probe" | tr '\n' ' ' | cut -c1-90)"
        refused "$rung" "$(classify "preflight: $probe")"
        continue
      fi
      [ "$CHECK" = 1 ] && { printf '%s\n' "$rung"; exit 0; }
      # pi never exits on failure, so a watchdog owns the deadline: it kills this script's own pi child once the
      # window closes with no seal. Started before pi so it never has to race for the pid.
      # A pi error record untouched for a minute means pi stopped retrying, so end the rung then, not at the deadline.
      rm -f ".review/$slot.rung-error"
      ( slept=0
        while [ "$slept" -lt "$RUNG_TIMEOUT" ]; do
          sleep 5; slept=$((slept + 5))
          [ -f ".review/$slot.done" ] && exit 0
          last=$(find ".review/pi-$slot" -name '*.jsonl' -mmin +1 2>/dev/null | head -n1)
          if [ -n "$last" ] && [ -z "$(find ".review/pi-$slot" -name '*.jsonl' -mmin -1 2>/dev/null)" ] &&
            tail -n1 "$last" | grep -q '"stopReason":"error"'; then
            tail -n1 "$last" | jq -r '.message.errorMessage // "pi stopped on an error"' >".review/$slot.rung-error" 2>/dev/null ||
              echo "pi stopped on an error" >".review/$slot.rung-error"
            echo "review-finder-pi: pi stopped on an error, ending this rung: $(head -c 120 ".review/$slot.rung-error")"
            for c in $(pgrep -P "$$" 2>/dev/null); do [ "$c" = "$BASHPID" ] || kill "$c" 2>/dev/null; done
            exit 0
          fi
        done
        echo "no seal within ${RUNG_TIMEOUT}s" >".review/$slot.rung-error"
        echo "review-finder-pi: $RUNG_TIMEOUT s with no seal, ending this rung"
        # By pid, never by name: pi is a `#!/usr/bin/env node` script and presents as `node` for subcommands, so
        # `pkill -x pi` matches nothing. $$ is the SCRIPT inside a bash subshell (it does not re-point) while
        # $BASHPID is this watchdog - $PPID would be the script's own launcher and killed nothing, verified.
        for c in $(pgrep -P "$$" 2>/dev/null); do [ "$c" = "$BASHPID" ] || kill "$c" 2>/dev/null; done ) &
      watchdog=$!
      # Not --no-session: this session dir is the only record of what the finder spent.
      pi --session-dir ".review/pi-$slot" --provider "$provider" --model "$model" --thinking "$THINKING" "$(cat "$brief")"
      kill "$watchdog" 2>/dev/null
      wait "$watchdog" 2>/dev/null
      if [ ! -f ".review/$slot.done" ]; then
        refused "$rung" "$(classify "$(cat ".review/$slot.rung-error" 2>/dev/null || echo "pi exited without a seal")")"
        rm -f ".review/$slot.rung-error"
      fi
      ;;
    *)
      echo "review-finder-pi: unknown harness '$harness' in rung $rung" >&2
      continue
      ;;
  esac

  if [ -f ".review/$slot.done" ]; then
    printf '%s\n' "$rung" >".review/$slot.model"
    echo "review-finder-pi: $slot sealed on $rung"
    sealed=1
    break
  fi
  echo "review-finder-pi: $rung produced no seal, trying the next rung"
  [ "$harness" = codex ] && refused "$rung" "exited 0 without writing $slot.done"
done

[ "$sealed" = 1 ] && exit 0
# Nothing eligible is a legitimate outcome, not a stall: the caller's seal_on_exit writes .failed, review-fanout
# counts that as settled and merges opus alone with its INCOMPLETE disclosure. Degrading to one bid, said out loud,
# beats waiting out a timeout for a second bid that was never reachable.
summary="second-model finder unavailable - $(IFS=';'; printf '%s' "${REASONS[*]:-no rung was eligible}")"
# --check reports on its last stdout line so review-open.sh can seal the reason before the owner starts.
if [ "$CHECK" = 1 ]; then
  printf 'UNAVAILABLE: %s\n' "$summary"
  exit 1
fi
rm -f ".review/$slot.model"
printf '%s\n' "$summary" >".review/$slot.failed"
echo "review-finder-pi: no rung could seal $slot - $summary" >&2
exit 1
