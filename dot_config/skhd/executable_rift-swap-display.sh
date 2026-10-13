#!/bin/bash
# Move the active rift workspace to the next display by UUID, independent of display arrangement.
rift=/opt/homebrew/bin/rift-cli
target=$("$rift" query displays | /run/current-system/sw/bin/jq -r '(map(.is_active_context) | index(true)) as $i | .[(($i + 1) % length)].uuid')
[ -n "$target" ] && [ "$target" != null ] && "$rift" execute display move-workspace --uuid "$target"
