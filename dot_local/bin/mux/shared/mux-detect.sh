# Canonical "which multiplexer is live" answer. Sourced by absolute path, never
# executed — same contract as mux-env.sh, and for the same reason: callers span herdr
# keybinds (frozen server env), tmux run-shell jobs (near-empty PATH), the kitty
# quake (no pane env at all) and launchd/systemd units.
#
# Consumers: `mux kind` (the dispatcher verb) and active_mux() in launcher.sh.
# nvim's config/mux.lua deliberately re-implements this in Lua — it can't source
# bash, and an in-process answer avoids a subprocess per keypress.
#
# Order is load-bearing:
#   1. Own pane env, herdr ahead of tmux — a herdr pane can sit atop a tmux session.
#   2. herdr server reachable. The quake and any daemon have no pane env, so the
#      socket is the only signal there. Probed BEFORE tmux on purpose: that ordering
#      is what stops a merely-DETACHED tmux server from claiming to be the live mux,
#      which is exactly the bug the launcher had when it checked tmux panes first.
#   3. Any tmux server — last resort.
#
# `herdr status server` and not `herdr api snapshot`: the status probe needs no jq,
# so detection keeps working in the stripped-PATH chains above, and it is ~2x cheaper.

# Prints herdr | tmux | none.
#
# Deliberately NOT memoized in here. A cache variable set inside this function is
# invisible to the caller whenever it is invoked as `$(mux_kind)`, because that forks
# a subshell — so an internal memo would look like it worked while re-probing every
# time. Callers that ask repeatedly must resolve ONCE into their own shell variable;
# see MUX_LIVE in launcher.sh.
mux_kind() {
  local kind herdr_bin="${HERDR_BIN_PATH:-herdr}"
  if [ -n "${HERDR_SOCKET_PATH:-}" ]; then
    kind=herdr
  elif [ -n "${TMUX:-}" ]; then
    kind=tmux
  elif command -v "$herdr_bin" >/dev/null 2>&1 &&
    "$herdr_bin" status server 2>/dev/null | grep -q '^status: running'; then
    kind=herdr
  elif command -v tmux >/dev/null 2>&1 && tmux ls >/dev/null 2>&1; then
    kind=tmux
  else
    kind=none
  fi

  echo "$kind"
}
