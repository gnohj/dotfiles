#!/bin/bash
# Native macOS screenshot - save to file AND copy filepath to clipboard

# Match macshot's filenameTemplate "Screenshot-{date} at {time}" so hyper+x and
# hyper+s (macshot Quick Capture) produce identical naming.
FILENAME="Screenshot-$(date +'%Y-%m-%d at %H-%M-%S').png"
FILEPATH="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Downloads/$FILENAME"

screencapture -i "$FILEPATH"

if [ -f "$FILEPATH" ]; then
    echo -n "$FILEPATH" | pbcopy
fi
