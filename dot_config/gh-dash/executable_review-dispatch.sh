#!/bin/bash
# Rules run narrowest-first; both finders use matching effort so their bids remain comparable.

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
  if [ "$output" = mode ]; then printf 'full\n'; else emit claude-opus-5-5 high gpt-5.6-sol high 600 fallback; fi
  exit 0
}
[ -f "$CONFIG" ] || fallback
command -v jq >/dev/null 2>&1 || fallback

gh_args=(pr view "$pr")
[ -n "$repo" ] && gh_args+=(--repo "$repo")
stats=$(gh "${gh_args[@]}" --json files,title 2>/dev/null) || fallback
[ -n "$stats" ] || fallback

# Generated files excluded, matching the size the Library shows, so badge and band cannot disagree.
GENERATED='(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|Cargo\.lock|poetry\.lock|go\.sum|Gemfile\.lock)$|(^|/)(dist|build|out|coverage|node_modules|__generated__|__snapshots__)/|\.(snap|pb\.go)$|\.gen\.[^/]+$|(^|/)CHANGELOG\.md$'
counted=$(printf '%s' "$stats" | jq --arg skip "$GENERATED" '[.files[]? | select((.path // "") | test($skip) | not)]')
lines=$(printf '%s' "$counted" | jq -r 'map((.additions // 0) + (.deletions // 0)) | add // 0')
files=$(printf '%s' "$counted" | jq -r 'length')
title=$(printf '%s' "$stats" | jq -r '.title // ""')
case "$lines$files" in '' | *[!0-9]*) fallback ;; esac

semantic=""
if command -v jev-route >/dev/null 2>&1; then
  semantic_state=$(jq -cn --arg title "$title" --argjson lines "$lines" --argjson files "$files" --argjson changed "$counted" \
    '{title: $title, changedLines: $lines, changedFiles: $files, paths: [$changed[].path // ""]}')
  semantic_result=$(printf '%s' "$semantic_state" | jev-route review - 2>/dev/null) || semantic_result=""
  semantic=$(printf '%s' "$semantic_result" | jq -r 'if .action == "auto" then (.handler // "") else "" end' 2>/dev/null) || semantic=""
fi

# Size picks the band; riskPaths floors it at the hardest, lowRiskPaths drops one but only if EVERY counted file matches.
profile=$(jq -r --argjson lines "$lines" --argjson files "$files" --arg title "$title" --argjson counted "$counted" --arg semantic "$semantic" '
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
  | (if $hitRisk or $semantic == "critical" then ($count - 1)
     elif $semantic == "deep" and ($idx != null) then ([$idx, ([1, ($count - 1)] | min)] | max)
     elif $allCheap and ($idx != null) then ([$idx - 1, 0] | max)
     else $idx end) as $pick
  | (if $pick == null then {use: .default} else .rules[$pick] end) as $r
  | ($r.use // $r) as $u
  | (if $hitRisk then "risk" elif $semantic == "critical" then "jev-critical" elif $semantic == "deep" then "jev-deep" elif $allCheap then "tests" else "" end) as $why
  | (if ($title | test("^\\[Backport #[0-9]+\\]"; "i")) then "full" else ($u.mode // "full") end) as $mode
  | [ $mode, $u.claude.model, $u.claude.effort, $u.gpt.model, $u.gpt.effort, ($u.rungTimeout | tostring), $why ] | @tsv
' "$CONFIG" 2>/dev/null) || fallback
[ -n "$profile" ] || fallback

IFS=$'\t' read -r review_mode cmodel ceffort gmodel geffort timeout band_why <<<"$profile"
case "$review_mode" in full | fan) ;; *) fallback ;; esac
if [ "$output" = mode ]; then
  printf '%s\n' "$review_mode"
  exit 0
fi
case "$cmodel$gmodel" in '' | *[!A-Za-z0-9._:/+-]*) fallback ;; esac
case "$ceffort" in low | medium | high | xhigh) ;; *) fallback ;; esac
case "$geffort" in low | medium | high | xhigh) ;; *) fallback ;; esac
case "$timeout" in '' | *[!0-9]*) fallback ;; esac

emit "$cmodel" "$ceffort" "$gmodel" "$geffort" "$timeout" "${lines}L/${files}f${band_why:++$band_why}"
