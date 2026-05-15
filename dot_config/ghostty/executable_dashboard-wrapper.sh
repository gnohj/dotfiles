#!/usr/bin/env bash
# Ghostty `command =` wrapper. Normally just exec's the user's login shell.
# But if ~/.local/bin/agent-sidebar-dashboard.sh dropped a fresh marker file, take over
# this Ghostty window and run the recon dashboard instead. This lets the
# dashboard launcher transform the next-spawned Ghostty window without
# keystroke injection — Ghostty drops CLI args (-e, --command) for new
# windows when an instance is already running, so a wrapper-as-default-shell
# is the only reliable way to run a custom command.

MARKER="/tmp/agent-dashboard-launching"
if [ -f "$MARKER" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$MARKER" 2>/dev/null || echo 0) ))
  rm -f "$MARKER"
  if [ "$age" -lt 5 ]; then
    # Delegate to the shared launcher which sets PATH then exec's the
    # sidebar. Same wrapper is used by the kitty path in
    # ~/.local/bin/agent-sidebar-dashboard.sh.
    exec "$HOME/.local/bin/agent-sidebar-launch"
  fi
fi

exec /bin/zsh --login
