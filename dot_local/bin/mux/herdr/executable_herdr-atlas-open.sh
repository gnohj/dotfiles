#!/usr/bin/env bash
# Usage: herdr-atlas-open.sh <origin-pane> <pane-label> <jira-key|pr-url> - :Atlas open in a 50/50 split beside origin.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"
herdr="${HERDR_BIN_PATH:-herdr}"

origin=${1:?origin pane}
label=${2:?pane label}
target=${3:?atlas target}
# HERDR_ATLAS_NO_FOCUS=1 builds the split without taking focus, like HERDR_SESH_NO_FOCUS.
focus=--focus
[ -n "${HERDR_ATLAS_NO_FOCUS:-}" ] && focus=--no-focus

case "$target" in
  *[!A-Za-z0-9:/._#-]*) echo "unsafe target: $target"; exit 1 ;;
esac

tab=$("$herdr" pane get "$origin" 2>/dev/null | jq -r '.result.pane.tab_id // empty')
[ -n "$tab" ] || { echo "unknown pane $origin"; exit 1; }
panes=$("$herdr" pane list 2>/dev/null | jq -c --arg t "$tab" '[.result.panes[] | select(.tab_id == $t)]')

same=$(printf '%s' "$panes" | jq -r --arg l "$label" '[.[] | select(.label == $l)] | (first // {}).pane_id // empty')
if [ -n "$same" ]; then
  [ "$focus" = --focus ] && herdr-focus-pane.sh "$same" >/dev/null 2>&1
  exit 0
fi

# One companion per tab: a previous ticket/PR pane is replaced rather than stacked.
printf '%s' "$panes" | jq -r --arg o "$origin" \
  '.[] | select(.pane_id != $o) | select((.label // "") | test("^(🔷 [A-Z]+-[0-9]+|🐙 PR-[0-9]+)$")) | .pane_id' |
  while read -r old; do "$herdr" pane close "$old" >/dev/null 2>&1; done

out=$("$herdr" pane split "$origin" --direction right --ratio 0.5 --cwd "$HOME/.config/gh-dash" "$focus" 2>/dev/null)
pane=$(printf '%s' "$out" | jq -r '.result.pane.pane_id // .result.pane_id // empty')
[ -n "$pane" ] || { echo "split failed: $out"; exit 1; }
"$herdr" pane rename "$pane" "$label" >/dev/null 2>&1
# The balancer saw this pane before its label and may have pushed it to 25%; re-run it now that it is a companion.
sleep 0.3
python3 "$HOME/.local/bin/mux/herdr/herdr-balance-panes.py" --once "$tab" >/dev/null 2>&1
# ATLAS_COMPANION tells the nvim in here to open further links in place instead of splitting again.
"$herdr" pane run "$pane" "ATLAS_COMPANION=1 nvim -c 'Atlas open $target'; exit" >/dev/null 2>&1
