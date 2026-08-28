#!/bin/bash
# Rules run narrowest-first; both finders use matching effort so their bids remain comparable.

case "$(uname -s)" in
  Darwin) export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH" ;;
  Linux) export PATH="/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:$PATH" ;;
  *) export PATH="/usr/local/bin:/usr/bin:/bin:$PATH" ;;
esac

CONFIG="${REVIEW_DISPATCH_CONFIG:-$HOME/.config/gh-dash/review-dispatch.json}"
pr="${1:?review-dispatch: missing <pr-number>}"
repo="${2:-}"

emit() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6"
}

# No config, no gh, or an unreachable PR all fall back rather than blocking the review.
fallback() { emit claude-opus-5 high gpt-5.6-sol high 600 fallback; exit 0; }
[ -f "$CONFIG" ] || fallback
command -v jq >/dev/null 2>&1 || fallback

gh_args=(pr view "$pr")
[ -n "$repo" ] && gh_args+=(--repo "$repo")
stats=$(gh "${gh_args[@]}" --json additions,deletions,changedFiles 2>/dev/null) || fallback
[ -n "$stats" ] || fallback

lines=$(printf '%s' "$stats" | jq -r '(.additions // 0) + (.deletions // 0)')
files=$(printf '%s' "$stats" | jq -r '.changedFiles // 0')
case "$lines$files" in '' | *[!0-9]*) fallback ;; esac

profile=$(jq -r --argjson lines "$lines" --argjson files "$files" '
  (([.rules[] | select(
      ((.when.maxLines // 1e18) >= $lines) and ((.when.maxFiles // 1e18) >= $files)
    )] | first) // {use: .default, why: "default"}) as $r
  | ($r.use // $r) as $u
  | [ $u.claude.model, $u.claude.effort, $u.gpt.model, $u.gpt.effort, ($u.rungTimeout | tostring) ] | @tsv
' "$CONFIG" 2>/dev/null) || fallback
[ -n "$profile" ] || fallback

IFS=$'\t' read -r cmodel ceffort gmodel geffort timeout <<<"$profile"
case "$cmodel$gmodel" in '' | *[!A-Za-z0-9._:/+-]*) fallback ;; esac
case "$ceffort" in low | medium | high | xhigh) ;; *) fallback ;; esac
case "$geffort" in low | medium | high | xhigh) ;; *) fallback ;; esac
case "$timeout" in '' | *[!0-9]*) fallback ;; esac

emit "$cmodel" "$ceffort" "$gmodel" "$geffort" "$timeout" "${lines}L/${files}f"
