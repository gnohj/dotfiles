#!/bin/bash
# Native macOS screenshot - save to file AND copy image to clipboard

# Generate filename with timestamp
FILENAME="Screenshot-$(date +%Y%m%d-%H%M%S).png"
FILEPATH="$HOME/Pictures/$FILENAME"

# Take screenshot and save to file
screencapture -i "$FILEPATH"

# If file was created, copy image to clipboard with clippy (paste directly into apps)
if [ -f "$FILEPATH" ]; then
    clippy "$FILEPATH"
fi
