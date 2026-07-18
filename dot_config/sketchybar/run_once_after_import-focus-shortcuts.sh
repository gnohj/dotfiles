#!/bin/bash
# Import the FocusOn/FocusOff toggle Shortcuts if missing. macOS has no headless import, so `open` shows a one-click Add dialog; usually a no-op (iCloud syncs them).

set -eu

command -v shortcuts >/dev/null 2>&1 || exit 0
DIR="$HOME/.config/sketchybar/shortcuts"

for name in FocusOn FocusOff; do
  if shortcuts list 2>/dev/null | grep -qx "$name"; then
    continue
  fi
  if [ ! -f "$DIR/$name.shortcut" ]; then
    echo "sketchybar: '$name' shortcut absent and no export at $DIR/$name.shortcut — skipping (export it from Shortcuts.app into dot_config/sketchybar/shortcuts/ to enable auto-import)" >&2
    continue
  fi
  echo "sketchybar: importing '$name' — click 'Add Shortcut' in the dialog"
  open "$DIR/$name.shortcut"
  sleep 2
done
