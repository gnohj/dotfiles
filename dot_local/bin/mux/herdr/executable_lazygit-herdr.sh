#!/usr/bin/env bash
# herdr counterpart of mux/tmux/lazygit.sh: ctrl+g is exec'd with the server's frozen env, so lazygit's customCommands (<c-o>, <c-e>, <c-s>) need a current PATH.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"

# HUSKY=0 mirrors mux/tmux/lazygit.sh: built-in ops (branch-panel `f` runs `git pull --ff-only`) would otherwise fire web's post-merge `pnpm i` + `pnpm build-packages`.
exec env HUSKY=0 lazygit "$@"
