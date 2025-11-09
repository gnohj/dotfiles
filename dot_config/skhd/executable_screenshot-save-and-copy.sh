#!/bin/bash
# Native macOS screenshot - save to file AND copy to clipboard

# Generate filename with timestamp
FILENAME="Screenshot-$(date +%Y%m%d-%H%M%S).png"
FILEPATH="$HOME/Pictures/$FILENAME"

# Take screenshot and save to file
screencapture -i "$FILEPATH"

# If file was created, also copy it to clipboard
if [ -f "$FILEPATH" ]; then
    osascript -e "set the clipboard to (read (POSIX file \"$FILEPATH\") as «class PNGf»)"
fi
