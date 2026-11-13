#!/usr/bin/env bash
# Carry Rex's key-action state (last tab/pane/session, open popups) over to its renamed directory; files already in the new one win.
set -eu

state="${XDG_STATE_HOME:-$HOME/.local/state}"
old="$state/rex-herdr-keys"
new="$state/rex-keys"
[ -d "$old" ] || exit 0
mkdir -p "$new"
for f in "$old"/* "$old"/.[!.]*; do
  [ -e "$f" ] || continue
  [ -e "$new/$(basename "$f")" ] || mv "$f" "$new/"
done
rm -rf "$old"
echo "rex-keys: migrated state from $old"
