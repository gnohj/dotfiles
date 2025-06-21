#!/bin/bash
# Notify Sketchybar of github repo update notification

# Gentle fade-in effect (5 blinks)
for i in {1..5}; do
  # Show notification
  touch "$HOME/github-custom-notification.txt"
  sketchybar --update 2>/dev/null || true
  sleep 1.0

  # Hide notification
  rm -f "$HOME/github-custom-notification.txt"
  sketchybar --update 2>/dev/null || true
  sleep 0.5
done

# Final persistent show for 5 seconds
touch "$HOME/github-custom-notification.txt"
sketchybar --update 2>/dev/null || true
sleep 5

# Final cleanup
rm -f "$HOME/github-custom-notification.txt"
sketchybar --update 2>/dev/null || true
