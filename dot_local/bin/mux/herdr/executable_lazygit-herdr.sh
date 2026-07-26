#!/usr/bin/env bash
# herdr counterpart of mux/tmux/lazygit.sh: ctrl+g is exec'd with the server's frozen env, so lazygit's customCommands (<c-o>, <c-e>, <c-s>) need a current PATH.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"

exec lazygit "$@"
