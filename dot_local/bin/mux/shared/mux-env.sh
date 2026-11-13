# Canonical PATH for every mux helper. Sourced by absolute path, never executed: Rex, launchd and systemd callers get a minimal PATH, so each helper must set its own.

_mux_path="$HOME/.local/bin/mux/shared"
_mux_path="$_mux_path:$HOME/.local/bin/mux:$HOME/.local/bin/worktree:$HOME/.local/bin"
_mux_path="$_mux_path:/opt/homebrew/bin:/opt/homebrew/sbin:$HOME/.nix-profile/bin:/run/current-system/sw/bin"
# bun's global bin dir - a minimal caller env has no bun shell init to add it.
_mux_path="$_mux_path:$HOME/.bun/bin"

_mux_path="$_mux_path:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# mise shims are appended, never prepended, so nix and homebrew keep front precedence.
export PATH="$_mux_path:$PATH:$HOME/.local/share/mise/shims"
unset _mux_path
