#!/bin/bash
# Native macOS screenshot - save to file AND copy filepath to clipboard

# Generate filename with timestamp
FILENAME="Screenshot-$(date +%Y%m%d-%H%M%S).png"
FILEPATH="$HOME/Pictures/$FILENAME"

# Take screenshot and save to file
screencapture -i "$FILEPATH"

# If file was created, copy filepath to clipboard
if [ -f "$FILEPATH" ]; then
    echo -n "$FILEPATH" | pbcopy
fi
