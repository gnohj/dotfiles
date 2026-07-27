#!/usr/bin/env bash
# Row source for the sesh picker: every `sesh list` row, plus - under each ACTIVE
# tmux session - one indented child row per AI agent pane in it, carrying the
# tmux-dash status (working / input / done / idle). Child rows hide a
# `session:window.pane` target behind a tab, so picking one jumps to that pane
# instead of just the session.
#
# Row grammar - defined only here + sesh-agent-rows.py; sesh-popup.sh binds
# against it:
#   session row  "<icon> <name>"                         no tab, no leading space
#   agent row    "  <glyph> <name> · <state>\t<target>"   two leading spaces
#
# Enrichment applies only when tmux sessions are actually in the source set
# (bare `sesh list`, or `-t`): a config/zoxide/find-only list has no live panes
# to hang children off, and a same-named zoxide dir must not inherit them.
#
# Modes:
#   [sesh flags...]   emit the list
#   --kill <row>      ctrl-d: an agent row kills only its own pane, a session row the whole session.

export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
[ "$(uname)" = Linux ] && PATH="$HOME/.nix-profile/bin:/home/linuxbrew/.linuxbrew/bin:$PATH"

if [[ "${1:-}" == "--kill" ]]; then
  row="${2:-}"
  # Agent rows are indented and carry their pane target after a tab (fzf's {} is the raw line); require the full session:window.pane or kill-pane hits whatever pane is active there.
  if [[ "$row" == " "* ]]; then
    target="${row##*$'\t'}"
    [[ "$target" == *:*.* ]] && tmux kill-pane -t "$target" 2>/dev/null
    exit 0
  fi
  # Drop the leading sesh icon glyph (fzf has already stripped the ANSI).
  name="${row#* }"
  [[ -n "$name" ]] && tmux kill-session -t "$name" 2>/dev/null
  exit 0
fi

tmpd=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpd"' EXIT

enrich=1
for flag in "$@"; do
  case "$flag" in
    -t | --tmux) ;;
    -*) enrich=0 ;;
  esac
done

# The three reads are independent, so overlap them - tmux-dash's cold load is
# the slow one (~120ms) and it shouldn't stack on top of sesh's.
sesh list "$@" --icons >"$tmpd/sesh" 2>/dev/null &
if [[ $enrich == 1 ]]; then
  tmux-dash json >"$tmpd/agents" 2>/dev/null &
  tmux-dash theme >"$tmpd/theme" 2>/dev/null &
fi
wait

# No agents anywhere is the common case - skip the merge rather than pay for a
# python start that would just echo the sesh list back.
if [[ $enrich == 0 || ! -s "$tmpd/agents" ]] || grep -q '"sessions":\[\]' "$tmpd/agents"; then
  cat "$tmpd/sesh"
  exit 0
fi

python3 "$HOME/.config/tmux/sesh-agent-rows.py" "$tmpd" || cat "$tmpd/sesh"
