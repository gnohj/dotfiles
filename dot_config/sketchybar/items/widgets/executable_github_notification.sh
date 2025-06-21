#!/bin/bash
source "$HOME/.config/sketchybar/config/colors.sh"

# Path to the notification flag file
GITHUB_NOTIFICATION_FILE="$HOME/github-custom-notification.txt"

if [ -f "$GITHUB_NOTIFICATION_FILE" ]; then
  # Show the notification with blinking effect
  sketchybar --set widgets.github_notification \
    drawing=true \
    label=" " \
    icon.color=$BLUE \
    label.color=$BLUE
else
  sketchybar --set widgets.github_notification drawing=false
fi
