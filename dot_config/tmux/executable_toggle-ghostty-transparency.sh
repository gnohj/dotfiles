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
  tmux display-message "Ghostty: Transparency ON ($new_opacity)"
else
  # Going from transparent to opaque
  new_opacity="1.0"
  comment_opacity="$current_opacity"
  tmux display-message "Ghostty: Transparency OFF"
fi

# Remove any existing background-opacity lines (both active and commented)
if [ -f "$GHOSTTY_CONFIG" ]; then
  sed -i '' '/^background-opacity/d' "$GHOSTTY_CONFIG"
  sed -i '' '/^# background-opacity/d' "$GHOSTTY_CONFIG"
fi

# Add the new active opacity and comment the previous one
echo "background-opacity = $new_opacity" >>"$GHOSTTY_CONFIG"
echo "# background-opacity = $comment_opacity" >>"$GHOSTTY_CONFIG"

# Reload Ghostty config
osascript "$HOME/.config/ghostty/reload-config.scpt" 2>/dev/null || true
