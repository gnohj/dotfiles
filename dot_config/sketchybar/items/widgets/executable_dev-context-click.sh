#!/bin/bash
# Left-click: flip the dev context (local<->vps) and repaint the widget.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

dev-context toggle >/dev/null 2>&1 || true
sketchybar --trigger dev_context_change
