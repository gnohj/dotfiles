#!/usr/bin/env bash

WEZTERM_CONFIG="$HOME/.config/wezterm/wezterm.lua"

# Check current transparency state
if grep -q "^config\.window_background_opacity" "$WEZTERM_CONFIG" 2>/dev/null; then
  current_opacity=$(grep "^config\.window_background_opacity" "$WEZTERM_CONFIG" | sed 's/.*= //' | tr -d ' ')
else
  current_opacity="1.0"
fi

# Check if there's a commented previous value
if grep -q "^-- config\.window_background_opacity" "$WEZTERM_CONFIG" 2>/dev/null; then
  previous_opacity=$(grep "^-- config\.window_background_opacity" "$WEZTERM_CONFIG" | sed 's/.*= //' | tr -d ' ')
else
  previous_opacity="0.875" # default fallback to match your current setting
fi

# Toggle logic
if [ "$current_opacity" = "1.0" ] || [ "$current_opacity" = "1" ]; then
  # Going from opaque to transparent - use the previous value or default
  new_opacity="$previous_opacity"
  comment_opacity="1.0"
  # Only show message if we're actually in WezTerm
  if [[ "$TERM_PROGRAM" == "WezTerm" ]]; then
    tmux display-message "WezTerm: Transparency ON ($new_opacity)" 2>/dev/null || true
  fi
else
  # Going from transparent to opaque
  new_opacity="1.0"
  comment_opacity="$current_opacity"
  # Only show message if we're actually in WezTerm
  if [[ "$TERM_PROGRAM" == "WezTerm" ]]; then
    tmux display-message "WezTerm: Transparency OFF" 2>/dev/null || true
  fi
fi

# Remove any existing window_background_opacity lines (both active and commented)
if [ -f "$WEZTERM_CONFIG" ]; then
  sed -i '' '/^config\.window_background_opacity/d' "$WEZTERM_CONFIG"
  sed -i '' '/^-- config\.window_background_opacity/d' "$WEZTERM_CONFIG"
fi

# Find the line before "return config" to insert the new opacity setting
# Insert the new active opacity and comment the previous one before the return statement
sed -i '' "/^return config$/i\\
config.window_background_opacity = $new_opacity\\
-- config.window_background_opacity = $comment_opacity
" "$WEZTERM_CONFIG"

# WezTerm automatically reloads config when the file changes
# No need for explicit reload like Ghostty
