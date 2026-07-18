#!/usr/bin/env bash
# Re-balance panes after a split. Called via run-shell on the split binds, so it
# works identically over SSH / Tailscale (pure tmux-server op). Always exits 0 so
# tmux never dumps a copy-mode pager.
#   $1 orientation: "h" (v / | side-by-side), "v" (- / = stacked), or "auto"
#                   (after prefix x / kill-pane - re-even whichever pure axis is
#                    left, no split so no 75/25 main-pane and no orientation bias)
#   $2 window id   (passed in to stay unambiguous in the run-shell context)
#
# The FIRST horizontal split (1 -> 2 panes) keeps a big main pane on the LEFT
# (75%) with the new pane narrow on the right ([75%][25%]). After that we only
# rebalance while the layout is a PURE single axis, so nested splits stay local:
#   h + single row    -> even-horizontal (equal-width columns | | |, never stacks)
#   v + single column -> even-vertical   (equal-height rows)
#   nested / mixed     -> leave the raw split alone (splits only within that pane)

orient="${1:-h}"
win="${2:-}"
target=()
[ -n "$win" ] && target=(-t "$win")

npanes=$(tmux list-panes "${target[@]}" 2>/dev/null | wc -l | tr -d ' ')
[ -z "$npanes" ] || [ "$npanes" -lt 2 ] && exit 0

if [ "$orient" = "h" ] && [ "$npanes" -eq 2 ]; then
  tmux set-window-option "${target[@]}" main-pane-width 75%
  tmux select-layout "${target[@]}" main-vertical
  exit 0
fi

tops=$(tmux list-panes "${target[@]}" -F '#{pane_top}' | sort -u | wc -l | tr -d ' ')
lefts=$(tmux list-panes "${target[@]}" -F '#{pane_left}' | sort -u | wc -l | tr -d ' ')

if { [ "$orient" = "h" ] || [ "$orient" = "auto" ]; } && [ "$tops" -eq 1 ]; then
  tmux select-layout "${target[@]}" even-horizontal
elif { [ "$orient" = "v" ] || [ "$orient" = "auto" ]; } && [ "$lefts" -eq 1 ]; then
  tmux select-layout "${target[@]}" even-vertical
fi

exit 0
