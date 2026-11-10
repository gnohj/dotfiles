#!/bin/bash
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

REX="/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex"
if [ -x "$REX" ] && "$REX" --autostart=false --timeout 3s server status 2>/dev/null | grep -q '^tailscale: needs login'; then
  osascript -e 'display notification "Rex was started from a shell. Quit Rex (cmd+Q), reopen it from the Dock, then restart its server." with title "Rex is off the tailnet"'
  exit 0
fi
open -a 'Tailscale'
