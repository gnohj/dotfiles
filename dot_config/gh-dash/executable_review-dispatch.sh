#!/bin/bash
# Size picks a band, Jev matches the PR to a rule, risk paths and mechanical PRs override both.

case "$(uname -s)" in
  Darwin) export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH" ;;
  Linux) export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:$PATH" ;;
  *) export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin:$PATH" ;;
esac

CONFIG="${REVIEW_DISPATCH_CONFIG:-$HOME/.config/gh-dash/review-dispatch.json}"
output=profile
if [ "${1:-}" = --mode ]; then
  output=mode
  shift
fi
pr="${1:?review-dispatch: missing <pr-number>}"
repo="${2:-}"

emit() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6"
}

# No config, no gh, or an unreachable PR all fall back rather than blocking the review.
fallback() {
  if [ "$output" = mode ]; then printf 'full\n'; else emit claude-opus-5-5 high gpt-6.1-sol xhigh 600 fallback; fi
  exit 0
}
[ -f "$CONFIG" ] || fallback
command -v jq >/dev/null 2>&1 || fallback

gh_args=(pr view "$pr")
[ -n "$repo" ] && gh_args+=(--repo "$repo")
stats=$(gh "${gh_args[@]}" --json files,title,author,body 2>/dev/null) || fallback
[ -n "$stats" ] || fallback

# Generated files excluded, matching the size the Library shows, so badge and band cannot disagree.
GENERATED='(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|Cargo\.lock|poetry\.lock|go\.sum|Gemfile\.lock)$|(^|/)(dist|build|out|coverage|node_modules|__generated__|__snapshots__)/|\.(snap|pb\.go)$|\.gen\.[^/]+$|(^|/)CHANGELOG\.md$'
counted=$(printf '%s' "$stats" | jq --arg skip "$GENERATED" '[.files[]? | select((.path // "") | test($skip) | not)]')
lines=$(printf '%s' "$counted" | jq -r 'map((.additions // 0) + (.deletions // 0)) | add // 0')
files=$(printf '%s' "$counted" | jq -r 'length')
title=$(printf '%s' "$stats" | jq -r '.title // ""')
author=$(printf '%s' "$stats" | jq -r '.author.login // ""')
case "$lines$files" in '' | *[!0-9]*) fallback ;; esac

semantic=""
semantic_result=""
semantic_confidence=0
handlers=$(jq -c '[.rules[]? | select((.name // "") != "" and (.match // "") != "") | {key: .name, value: .match}] | from_entries' "$CONFIG" 2>/dev/null) || handlers='{}'
if command -v jev-route >/dev/null 2>&1 && [ "$handlers" != '{}' ]; then
  handlers_file=$(mktemp "${TMPDIR:-/tmp}/review-dispatch.XXXXXX") || handlers_file=""
  if [ -n "$handlers_file" ]; then
    printf '%s\n' "$handlers" >"$handlers_file"
    semantic_state=$(printf '%s' "$stats" | jq -r --argjson lines "$lines" --argjson files "$files" --argjson changed "$counted" '
      ((.body // "") | gsub("<!--[\\s\\S]*?-->"; "") | gsub("\n{3,}"; "\n\n") | .[0:6000]) as $body
      | ([$changed[].path // ""] | .[0:150]) as $paths
      | "Title: \(.title // "")\nSize: \($lines) changed lines across \($files) files, generated files excluded\nPaths:\n"
        + ($paths | map("- " + .) | join("\n"))
        + (if ($changed | length) > 150 then "\n- ...and \(($changed | length) - 150) more" else "" end)
        + "\nDescription:\n" + (if ($body | test("\\S")) then $body else "(none)" end)')
    semantic_result=$(printf '%s' "$semantic_state" | jev-route review --redact --handlers "@$handlers_file" - 2>/dev/null) || semantic_result=""
    rm -f "$handlers_file"
    semantic=$(printf '%s' "$semantic_result" | jq -r 'if .action == "auto" then (.handler // "") else "" end' 2>/dev/null) || semantic=""
    semantic_confidence=$(printf '%s' "$semantic_result" | jq -r '.confidence // 0 | tonumber' 2>/dev/null) || semantic_confidence=0
  fi
fi

# Risk paths win; Jev raises at 0.6, lowers at 0.8 and by one band at most unless every file is low-risk.
profile=$(jq -r --argjson lines "$lines" --argjson files "$files" --arg title "$title" --arg author "$author" --argjson counted "$counted" --arg semantic "$semantic" --argjson confidence "${semantic_confidence:-0}" '
  ([$counted[].path // ""]) as $paths
  | (.riskPaths // []) as $risky
  | (.lowRiskPaths // []) as $cheap
  | ([$paths[] | . as $p | select([$risky[] | . as $re | select($p | test($re; "i"))] | length > 0)] | length > 0) as $hitRisk
  | ([$paths[] | . as $p | select([$cheap[]  | . as $re | select($p | test($re; "i"))] | length > 0)] | length) as $cheapCount
  | (($cheap | length) > 0 and ($paths | length) > 0 and $cheapCount == ($paths | length)) as $allCheap
  | (.rules | length) as $count
  | ([.rules | to_entries[] | select(
       ((.value.when.maxLines // 1e18) >= $lines) and ((.value.when.maxFiles // 1e18) >= $files)
     ) | .key] | first) as $idx
  | ([.rules | to_entries[] | select($semantic != "" and (.value.name // "") == $semantic) | .key] | first) as $named
  | (if $named != null and $idx != null and $named < $idx and $confidence < 0.8 then null else $named end) as $jev
  | (.singleAgent // {}) as $one
  | ([($one.titles // [])[] | select(. as $re | $title | test($re; "i"))] + [($one.authors // [])[] | select(. as $re | $author | test($re; "i"))] | length > 0) as $mechanical
  | (if $hitRisk then ($count - 1)
     elif $mechanical then 0
     elif $jev != null and $allCheap then $jev
     elif $jev != null then ([$jev, ((($idx // ($count - 1)) - 1) | if . < 0 then 0 else . end)] | max)
     elif $allCheap and ($idx != null) then ([$idx - 1, 0] | max)
     else $idx end) as $pick
  | (if $pick == null then {use: .default} else .rules[$pick] end) as $r
  | ($r.use // $r) as $u
  | ([if $hitRisk then "risk" else empty end, if $allCheap then "tests" else empty end, if $jev != null then "jev-" + $semantic else empty end] | join("+")) as $why
  | (if $mechanical then "full" else ($u.mode // "full") end) as $mode
  | (if $mechanical then ($why + (if $why == "" then "" else "+" end) + "mechanical") else $why end) as $why
  | [ $mode, $u.claude.model, $u.claude.effort, $u.gpt.model, $u.gpt.effort, ($u.rungTimeout | tostring), ($idx // "-" | tostring), ($pick // "-" | tostring), (if $why == "" then "-" else $why end) ] | @tsv
' "$CONFIG" 2>/dev/null) || fallback
[ -n "$profile" ] || fallback

IFS=$'\t' read -r review_mode cmodel ceffort gmodel geffort timeout size_band picked_band band_why <<<"$profile"
[ "$band_why" = - ] && band_why=""
case "$review_mode" in full | fan) ;; *) fallback ;; esac

if [ "$output" = profile ]; then
  log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/review-dispatch"
  mkdir -p "$log_dir" 2>/dev/null &&
    jq -cn --arg repo "$repo" --arg pr "$pr" --arg title "$title" --argjson lines "$lines" --argjson files "$files" \
      --arg size "$size_band" --arg picked "$picked_band" --arg why "$band_why" --arg model "$cmodel" --arg effort "$ceffort" \
      --arg jev "$semantic_result" \
      '{ts: (now | floor), repo: $repo, pr: $pr, title: $title, lines: $lines, files: $files, sizeBand: $size, pickedBand: $picked, why: $why, model: $model, effort: $effort,
        jev: ($jev | try (fromjson | {handler, action, confidence, probabilities}) catch null)}' \
      >>"$log_dir/decisions.jsonl" 2>/dev/null || true
fi

if [ "$output" = mode ]; then
  printf '%s\n' "$review_mode"
  exit 0
fi
case "$cmodel$gmodel" in '' | *[!A-Za-z0-9._:/+-]*) fallback ;; esac
case "$ceffort" in low | medium | high | xhigh | max) ;; *) fallback ;; esac
case "$geffort" in low | medium | high | xhigh | max) ;; *) fallback ;; esac
case "$timeout" in '' | *[!0-9]*) fallback ;; esac

emit "$cmodel" "$ceffort" "$gmodel" "$geffort" "$timeout" "${lines}L/${files}f${band_why:++$band_why}"
