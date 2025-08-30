#!/usr/bin/env bash

GHOSTTY_CONFIG="$HOME/.config/ghostty/config"

# Check current transparency state
if grep -q "^background-opacity" "$GHOSTTY_CONFIG" 2>/dev/null; then
  current_opacity=$(grep "^background-opacity" "$GHOSTTY_CONFIG" | cut -d'=' -f2 | tr -d ' ')
else
  current_opacity="1.0"
fi

# Check if there's a commented previous value
if grep -q "^# background-opacity" "$GHOSTTY_CONFIG" 2>/dev/null; then
  previous_opacity=$(grep "^# background-opacity" "$GHOSTTY_CONFIG" | cut -d'=' -f2 | tr -d ' ')
else
  previous_opacity="0.85" # default fallback
fi

# Toggle logic
if [ "$current_opacity" = "1.0" ] || [ "$current_opacity" = "1" ]; then
  # Going from opaque to transparent - use the previous value or default
  new_opacity="$previous_opacity"
  comment_opacity="1.0"
  MSG="Ghostty: Transparency ON ($new_opacity) - Press Cmd+Shift+, to reload"
  tmux display-message "$MSG" 2>/dev/null || echo "$MSG"
else
  # Going from transparent to opaque
  new_opacity="1.0"
  comment_opacity="$current_opacity"
  MSG="Ghostty: Transparency OFF - Press Cmd+Shift+, to reload"
  tmux display-message "$MSG" 2>/dev/null || echo "$MSG"
fi

# Remove any existing background-opacity lines (both active and commented)
if [ -f "$GHOSTTY_CONFIG" ]; then
  sed -i '' '/^background-opacity/d' "$GHOSTTY_CONFIG"
  sed -i '' '/^# background-opacity/d' "$GHOSTTY_CONFIG"
fi

# Add the new active opacity and comment the previous one
echo "background-opacity = $new_opacity" >>"$GHOSTTY_CONFIG"
echo "# background-opacity = $comment_opacity" >>"$GHOSTTY_CONFIG"

# Note: Ghostty requires manual reload with cmd+shift+, or restart
# Try to send the reload keystroke via AppleScript (may not work depending on Ghostty version)
osascript -e 'tell application "System Events" to keystroke "," using {command down, shift down}' 2>/dev/null || true
