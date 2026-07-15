#!/usr/bin/env bash
# Pick a repo from treekanga.yml and open its TUI to add a worktree.
#
# Called from:
#   - `tka` alias in .zshrc
#   - "🌳 Add Worktree" entry in the launcher (ql / launcher)
#
# rctrl-semi uses ~/.config/skhd/treekanga-selector.sh, which wraps the same
# flow in `tmux display-popup` because skhd launches outside of tmux.

set -euo pipefail
export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

CONFIG_FILE="$HOME/.config/treekanga/treekanga.yml"

if [ -f "$HOME/.config/colorscheme/active/active-colorscheme.sh" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.config/colorscheme/active/active-colorscheme.sh"
fi
FZF_COLORS="--color=bg+:${gnohj_color13:-},border:${gnohj_color03:-},fg:${gnohj_color02:-},fg+:${gnohj_color02:-},hl+:${gnohj_color04:-},info:${gnohj_color09:-},prompt:${gnohj_color04:-},pointer:${gnohj_color04:-},marker:${gnohj_color04:-},header:${gnohj_color09:-}"

REPOS=$(grep -E '^  [a-zA-Z0-9_-]+:$' "$CONFIG_FILE" | sed 's/^  //;s/:$//' | awk '{print "📂 " $0}')

SELECTED=$(echo "$REPOS" | "$HOME/.local/bin/fzf-vim.sh" \
  --no-border \
  --ansi \
  --no-sort \
  --prompt='🌳 ' \
  --bind 'tab:down,btab:up' \
  $FZF_COLORS) || exit 0

[ -z "$SELECTED" ] && exit 0
SELECTED=$(echo "$SELECTED" | awk '{print $2}')

WORKTREE_DIR=$(awk -v repo="$SELECTED" '
  $0 ~ "^  " repo ":$" { found=1; next }
  found && /^  [a-zA-Z]/ { found=0 }
  found && /worktreeTargetDir:/ { gsub(/.*worktreeTargetDir: */, ""); print; exit }
' "$CONFIG_FILE")

BARE_REPO_PATH="$HOME/$WORKTREE_DIR/.bare"

# PATH-portable: /opt/homebrew first (mac, unchanged) + mise shims / ~/.local/bin
# (linux) so `treekanga` resolves in the popup context on either platform.
TUI_CMD='export PATH="/opt/homebrew/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"; treekanga tui'

# Open the treekanga TUI in whichever multiplexer you're ATTACHED to. A tmux
# server and the herdr server can both be running at once, so "is it running"
# can't decide — we key off the attached client (you're only ever attached to
# one at a time). Covers every entry point (tka alias, ql / launcher, rctrl-semi
# popup):
#   - $TMUX set → already inside a tmux pane → new window right here.
#   - else a tmux client is attached on some socket (the quake / plain-shell case:
#     $TMUX is unset, but you're driving tmux from another window) → open the
#     window in that attached session, on that socket.
#   - else → a herdr tab in the focused workspace, over the socket API (remote-safe
#     server-side pane). Mirrors launcher.sh open_window.

# socket-path <TAB> session of the attached tmux client, if any. Scans every tmux
# socket and takes the first hit (you're attached to at most one at a time). Fails
# (non-zero) when no tmux client is attached — i.e. you're in herdr, or nothing.
attached_tmux() {
  local sockdir="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)" s sess
  for s in "$sockdir"/*; do
    [ -S "$s" ] || continue
    sess=$(tmux -S "$s" list-clients -F '#{client_session}' 2>/dev/null | head -1) || true
    [ -n "$sess" ] && { printf '%s\t%s' "$s" "$sess"; return 0; }
  done
  return 1
}

if [ -n "${TMUX:-}" ]; then
  tmux new-window -n '🌳' -c "$BARE_REPO_PATH" "$TUI_CMD"
elif tmux_hit=$(attached_tmux); then
  tmux -S "${tmux_hit%%$'\t'*}" new-window -t "${tmux_hit#*$'\t'}" \
    -n '🌳' -c "$BARE_REPO_PATH" "$TUI_CMD"
elif command -v herdr >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  pane=$(herdr tab create --label '🌳' --cwd "$BARE_REPO_PATH" --focus 2>/dev/null |
    jq -r '.result.root_pane.pane_id // empty')
  if [ -n "$pane" ]; then
    herdr pane run "$pane" "$TUI_CMD"
  else
    echo "herdr: could not open tab for treekanga tui" >&2
    exit 1
  fi
else
  echo "No attached tmux client and no herdr available — cannot open treekanga tui" >&2
  exit 1
fi
