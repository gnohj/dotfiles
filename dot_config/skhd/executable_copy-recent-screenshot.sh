#!/bin/bash
# Copy the most recent screenshot filepath to clipboard

SCREENSHOT_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Downloads"

# Find the most recent screenshot (Shottr: SCR-*, macOS: Screenshot-*)
RECENT_FILE=$(fd -t f '^(SCR-|Screenshot-)' "$SCREENSHOT_DIR" -x stat -f "%m %N" 2>/dev/null | \
  sort -rn | \
  head -1 | \
  cut -d' ' -f2-)

if [ -z "$RECENT_FILE" ]; then
  mac-notify -t "Copy Screenshot Path" -m "No recent screenshot found"
  exit 1
fi

# Copy filepath to clipboard
echo -n "$RECENT_FILE" | pbcopy

# Show notification
FILENAME=$(basename "$RECENT_FILE")
mac-notify -t "Screenshot path copied!" -m "$FILENAME"
