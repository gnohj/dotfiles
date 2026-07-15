#!/bin/bash

export PATH="/opt/homebrew/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

GITHUB_NOTIFICATION_FILE="$HOME/github-custom-notification.txt"

if [ -f "$GITHUB_NOTIFICATION_FILE" ]; then
  sketchybar --set widgets.github_notification \
    drawing=true \
    label=" " \
    icon.color="$BLUE" \
    label.color="$BLUE"
else
  sketchybar --set widgets.github_notification drawing=false
fi
