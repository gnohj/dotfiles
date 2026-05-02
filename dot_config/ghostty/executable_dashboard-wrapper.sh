#!/usr/bin/env bash
# Ghostty `command =` wrapper. Normally just exec's the user's login shell.
# But if ~/Scripts/agent-dashboard.sh dropped a fresh marker file, take over
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
    # Run the custom narrow-width agent sidebar (Python/Textual). It calls
    # `tmux switch-client` directly using the primary-client/window files
    # in /tmp, so the wrapper-tmux shim isn't needed for this path.
    # PATH must include $HOME/.local/bin so the script's `uv run` shebang
    # can find `uv` — Ghostty launches this wrapper with a minimal PATH.
    export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
    exec "$HOME/.local/bin/agent-sidebar"
  fi
fi

exec /bin/zsh --login
