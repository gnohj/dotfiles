#!/usr/bin/env bash
# Usage: herdr-annotate-capture.sh <source-pane> < selection - capture with the source pane's context.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"
herdr="${HERDR_BIN_PATH:-herdr}"

source_pane=${1:?source pane}
selection=$(cat)

root=$(ls -dt "$HOME"/.config/herdr/plugins/github/annotate-*/ 2>/dev/null | head -1)
root=${root%/}
[ -x "$root/bin/herdr-annotate.exe" ] || exit 1

pane=$("$herdr" pane get "$source_pane" 2>/dev/null | jq -c '.result.pane // empty')
[ -n "$pane" ] || exit 1
tab=$("$herdr" tab get "$(jq -r .tab_id <<<"$pane")" 2>/dev/null | jq -c '.result.tab // {}')
workspace=$("$herdr" workspace get "$(jq -r .workspace_id <<<"$pane")" 2>/dev/null | jq -c '.result.workspace // {}')

context=$(jq -n --argjson pane "$pane" --argjson tab "$tab" --argjson ws "$workspace" --arg text "$selection" '{
  workspace_id: $pane.workspace_id, workspace_label: $ws.label,
  tab_id: $pane.tab_id, tab_label: $tab.label,
  focused_pane_id: $pane.pane_id, focused_pane_cwd: ($pane.foreground_cwd // $pane.cwd),
  focused_pane_agent: $pane.agent, selected_text: $text
} | with_entries(select(.value != null))')

HERDR_PLUGIN_CONTEXT_JSON=$context \
  HERDR_PLUGIN_ROOT=$root \
  HERDR_PLUGIN_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/herdr/plugins/annotate" \
  exec "$root/bin/herdr-annotate.exe" capture
