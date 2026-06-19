#!/bin/bash
# Native macOS screenshot - save to file AND copy filepath to clipboard

# Generate filename with timestamp
# Match macshot's filenameTemplate "Screenshot-{date} at {time}" so hyper+x and
# hyper+s (macshot Quick Capture) produce identical naming.
FILENAME="Screenshot-$(date +'%Y-%m-%d at %H-%M-%S').png"
FILEPATH="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Downloads/$FILENAME"

# Take screenshot and save to file
screencapture -i "$FILEPATH"

# If file was created, copy filepath to clipboard
if [ -f "$FILEPATH" ]; then
    echo -n "$FILEPATH" | pbcopy
fi
