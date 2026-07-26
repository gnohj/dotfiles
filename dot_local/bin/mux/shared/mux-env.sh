# Canonical PATH for every mux helper. Sourced by absolute path, never executed: a herdr keybind inherits the server's frozen env and a tmux run-shell job gets a near-empty PATH, so each helper must set its own.

_mux_path="$HOME/.local/bin/mux/herdr:$HOME/.local/bin/mux/tmux:$HOME/.local/bin/mux/shared"
_mux_path="$_mux_path:$HOME/.local/bin/mux:$HOME/.local/bin/worktree:$HOME/.local/bin"
_mux_path="$_mux_path:/opt/homebrew/bin:/opt/homebrew/sbin:$HOME/.nix-profile/bin:/run/current-system/sw/bin"
# bun's global bin dir - `aic` lives here, and a frozen herdr env has no bun shell init.
_mux_path="$_mux_path:$HOME/.bun/bin"
[ "$(uname)" = Linux ] && _mux_path="$_mux_path:/home/linuxbrew/.linuxbrew/bin"

# ~/.local/bin MUST stay ahead of /usr/bin: tmux 3.6b lives there, apt ships 3.4, and the mismatch fails every tmux call.
_mux_path="$_mux_path:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# mise shims are appended, never prepended, so nix and homebrew keep front precedence.
export PATH="$_mux_path:$PATH:$HOME/.local/share/mise/shims"
unset _mux_path
