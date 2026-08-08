#!/usr/bin/env bash

# Inherently macOS: no local GUI kitty on a headless Linux VPS, and the BSD `sed -i ''` below is macOS-only.
[[ "$OSTYPE" == darwin* ]] || exit 0

KITTY_CONFIG="$HOME/.config/kitty/kitty.conf"

if grep -q "^background_opacity " "$KITTY_CONFIG" 2>/dev/null; then
  current_opacity=$(grep "^background_opacity " "$KITTY_CONFIG" | grep -v "^background_opacity background_opacity" | head -n1 | awk '{print $2}')
  # If empty or invalid, default to 1.0
  if [[ -z "$current_opacity" || "$current_opacity" == "background_opacity" ]]; then
    current_opacity="1.0"
  fi
else
  current_opacity="1.0"
fi

if grep -q "^# background_opacity " "$KITTY_CONFIG" 2>/dev/null; then
  previous_opacity=$(grep "^# background_opacity " "$KITTY_CONFIG" | head -n1 | awk '{print $2}')
  # If empty or invalid, use default
  if [[ -z "$previous_opacity" || "$previous_opacity" == "background_opacity" ]]; then
    previous_opacity="0.875"
  fi
else
  previous_opacity="0.875" # default from config
fi

# Toggle logic
if [ "$current_opacity" = "1.0" ] || [ "$current_opacity" = "1" ]; then
  # Going from opaque to transparent - use the previous value or default
  new_opacity="$previous_opacity"
  comment_opacity="1.0"
  MSG="Kitty: Transparency ON ($new_opacity)"
else
  # Going from transparent to opaque
  new_opacity="1.0"
  comment_opacity="$current_opacity"
  MSG="Kitty: Transparency OFF"
fi

# Remove any existing background_opacity number lines (both active and commented)
# This preserves "dynamic_background_opacity yes"
if [ -f "$KITTY_CONFIG" ]; then
  sed -i '' '/^background_opacity /d' "$KITTY_CONFIG"
  sed -i '' '/^# background_opacity /d' "$KITTY_CONFIG"
fi

# Add the new active opacity and comment the previous one at the end of file
echo "background_opacity $new_opacity" >>"$KITTY_CONFIG"
echo "# background_opacity $comment_opacity" >>"$KITTY_CONFIG"

# Matched off `ps`: macOS compares `pkill -x` against comm, which is the full bundle
# path here, so the old form signalled nothing. Anchored to match the trailing path segment.
ps -eo pid,comm= | awk '$2 ~ /(^|\/)kitty$/ {print $1}' | while read -r _pid; do
  kill -USR1 "$_pid" 2>/dev/null || true
done

tmux display-message "$MSG" 2>/dev/null || echo "$MSG"
