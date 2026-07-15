#!/usr/bin/env bash
# Notify Sketchybar of github repo update notification

export PATH="/opt/homebrew/bin:$PATH"

# Inherently macOS: drives the sketchybar github-notification widget. No sketchybar
# on a headless Linux VPS — no-op cleanly.
[[ "$OSTYPE" == darwin* ]] || exit 0

# Gentle fade-in effect (5 blinks)
for i in {1..5}; do
  touch "$HOME/github-custom-notification.txt"
  sketchybar --update 2>/dev/null || true
  sleep 1.0

  rm -f "$HOME/github-custom-notification.txt"
  sketchybar --update 2>/dev/null || true
  sleep 0.5
done

# Final persistent show for 5 seconds
touch "$HOME/github-custom-notification.txt"
sketchybar --update 2>/dev/null || true
sleep 5

rm -f "$HOME/github-custom-notification.txt"
sketchybar --update 2>/dev/null || true
