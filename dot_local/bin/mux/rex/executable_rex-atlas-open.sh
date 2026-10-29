#!/usr/bin/env bash
# Usage: rex-atlas-open.sh <origin-block> <block-label> <jira-key|pr-url> - :Atlas open in a 50/50 best-fit Rex split beside origin.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-detect.sh"
rex="$(rex_bin)" || { echo "Rex CLI unavailable"; exit 1; }

origin=${1:?origin block}
label=${2:?block label}
target=${3:?atlas target}

case "$target" in
  *[!A-Za-z0-9:/._#-]*) echo "unsafe target: $target"; exit 1 ;;
esac

blocks=$("$rex" --autostart=false block ls -s "${REX_SESSION:?REX_SESSION unset}" --json --short=false 2>/dev/null)
window=$(printf '%s' "$blocks" | jq -r --arg o "$origin" 'first(.blocks[] | select(.block_id == $o) | .window_id) // empty')
[ -n "$window" ] || { echo "unknown block $origin"; exit 1; }
siblings=$(printf '%s' "$blocks" | jq -c --arg w "$window" '[.blocks[] | select(.window_id == $w)]')

same=$(printf '%s' "$siblings" | jq -r --arg l "$label" 'first(.[] | select(.label == $l) | .block_id) // empty')
if [ -n "$same" ]; then
  "$rex" --autostart=false block focus "$same" >/dev/null 2>&1
  exit 0
fi

# One companion per window: a previous ticket/PR block is replaced rather than stacked.
printf '%s' "$siblings" | jq -r --arg o "$origin" \
  '.[] | select(.block_id != $o) | select((.label // "") | test("^(🔷 [A-Z]+-[0-9]+|🐙 PR-[0-9]+)$")) | .block_id' |
  while read -r old; do "$rex" --autostart=false block close "$old" >/dev/null 2>&1; done

# Mirror prefix+v's best-fit split: right when the origin is wider than tall in pixels, else below.
direction=$("$rex" --autostart=false block call -b "$origin" size 2>/dev/null |
  jq -r 'if .columns * .cell_width_px >= .rows * .cell_height_px then "right" else "below" end' 2>/dev/null)
[ -n "$direction" ] || direction=right

# ATLAS_COMPANION tells the nvim in here to open further links in place instead of splitting again.
"$rex" --autostart=false split -b "$origin" --split="$direction" --ratio 50 -c "$HOME/.config/gh-dash" --label "$label" \
  --shell=none -- env ATLAS_COMPANION=1 "${SHELL:-/bin/zsh}" -lic "nvim -c 'Atlas open $target'" >/dev/null ||
  { echo "Rex split failed"; exit 1; }
