#!/bin/bash
# Copy the most recent screenshot image to clipboard (paste directly into apps)

SCREENSHOT_DIR="$HOME/Pictures"

# Find the most recent screenshot (Shottr: SCR-*, macOS: Screenshot-*)
RECENT_FILE=$(fd -t f '^(SCR-|Screenshot-)' "$SCREENSHOT_DIR" -x stat -f "%m %N" 2>/dev/null | \
  sort -rn | \
  head -1 | \
  cut -d' ' -f2-)

if [ -z "$RECENT_FILE" ]; then
  osascript -e 'display notification "No recent screenshot found" with title "Copy Screenshot"'
  exit 1
fi

# Copy image to clipboard with clippy (paste directly into apps)
clippy "$RECENT_FILE"

# Show notification
FILENAME=$(basename "$RECENT_FILE")
osascript -e "display notification \"$FILENAME\" with title \"Screenshot copied to clipboard!\""
