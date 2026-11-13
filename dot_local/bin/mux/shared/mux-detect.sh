# Canonical "which multiplexer is live" answer, sourced by absolute path like mux-env.sh since callers include near-empty-PATH jobs and daemons.
#
# Consumers: `mux kind` (the dispatcher verb) and active_mux() in launcher.sh.
# nvim's config/mux.lua deliberately re-implements this in Lua — it can't source
# bash, and an in-process answer avoids a subprocess per keypress.
#
# Order: own pane env (Rex, then tmux) > reachable Rex server > any tmux server, so a detached tmux never claims to be live.

rex_bin() {
  if [ -n "${REX_BIN_DIR:-}" ] && [ -x "$REX_BIN_DIR/rex" ]; then printf '%s' "$REX_BIN_DIR/rex"
  elif command -v rex >/dev/null 2>&1; then command -v rex
  elif [ -x "$HOME/.local/bin/rex" ]; then printf '%s' "$HOME/.local/bin/rex"
  else return 1
  fi
}

# Prints rex | tmux | none.
#
# Deliberately NOT memoized in here. A cache variable set inside this function is
# invisible to the caller whenever it is invoked as `$(mux_kind)`, because that forks
# a subshell — so an internal memo would look like it worked while re-probing every
# time. Callers that ask repeatedly must resolve ONCE into their own shell variable;
# see MUX_LIVE in launcher.sh.
mux_kind() {
  local kind rex
  # An explicit choice wins: a detached caller inherits whatever pane env it started in, by accident.
  case "${MUX_FORCE_KIND:-}" in
  rex | tmux) echo "${MUX_FORCE_KIND}"; return 0 ;;
  esac
  if [ "${TERM_PROGRAM:-}" = rex ] && [ -n "${REX_BLOCK:-}" ]; then
    kind=rex
  elif [ -n "${TMUX:-}" ]; then
    kind=tmux
  elif rex="$(rex_bin)" && "$rex" --autostart=false server status >/dev/null 2>&1; then
    kind=rex
  elif command -v tmux >/dev/null 2>&1 && tmux ls >/dev/null 2>&1; then
    kind=tmux
  else
    kind=none
  fi

  echo "$kind"
}
