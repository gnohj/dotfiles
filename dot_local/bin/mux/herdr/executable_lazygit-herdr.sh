#!/usr/bin/env bash
# herdr counterpart of mux/tmux/lazygit.sh: ctrl+g is exec'd with the server's frozen env, so lazygit's customCommands (<c-o>, <c-e>, <c-s>) need a current PATH.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"

# herdr's popup cwd is pane.cwd (the LEADER shell's dir), which doesn't follow the child zsh `treehouse get` opens - so prefer foreground_cwd.
# A popup is not a pane, so $HERDR_PANE_ID is unset and the focused pane is the only anchor; keeps herdr's own cwd if herdr/jq are missing.
if [ -n "${HERDR_SOCKET_PATH:-}" ] && command -v jq >/dev/null 2>&1; then
  fg="$("${HERDR_BIN_PATH:-herdr}" pane list 2>/dev/null \
    | jq -r '[.result.panes[] | select(.focused==true)][0].foreground_cwd // empty' 2>/dev/null)"
  [ -n "$fg" ] && [ -d "$fg" ] && cd "$fg"
fi

# HUSKY=0 mirrors mux/tmux/lazygit.sh: built-in ops (branch-panel `f` runs `git pull --ff-only`) would otherwise fire web's post-merge `pnpm i` + `pnpm build-packages`.
exec env HUSKY=0 lazygit "$@"
