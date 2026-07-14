#!/bin/bash
# herdr-close-tabs-right — close every tab to the RIGHT of the first tab in the
# current (focused) herdr workspace, i.e. keep only the leftmost (position 1) tab.
# Bound to prefix+0 (type = "shell") in ~/.config/herdr/config.toml.
#
# Ordering: herdr `tab list` returns tabs in tab-bar order (index 0 = leftmost),
# which is exactly how herdr-tab-renumber.py derives 1-based positions. The tab
# `number` field is a STABLE per-workspace creation counter (never renumbers on
# delete), NOT the bar position — so we use array order, never `number`.
#
# Closes are keyed by the stable tab_id, so the renumber daemon reindexing the
# survivors mid-loop is harmless.
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

ws=$(herdr workspace list 2>/dev/null | jq -r '.result.workspaces[] | select(.focused) | .workspace_id')
[ -z "$ws" ] && exit 0

herdr tab list --workspace "$ws" 2>/dev/null \
  | jq -r '.result.tabs[1:][].tab_id' \
  | while IFS= read -r tid; do
      [ -n "$tid" ] && herdr tab close "$tid"
    done
