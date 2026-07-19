#!/usr/bin/env bash
# Re-balance panes after a split. Called via run-shell on the split binds, so it
# works identically over SSH / Tailscale (pure tmux-server op). Always exits 0 so
# tmux never dumps a copy-mode pager.
#   $1 orientation: "h" (v / | side-by-side), "v" (- / = stacked), or "auto"
#                   (after prefix x / kill-pane - re-even whichever pure axis is
#                    left, or restore the nvim 75/25 main-pane when it drops to 2)
#   $2 window id   (passed in to stay unambiguous in the run-shell context)
#
# Dropping to a single side-by-side row (1->2 via split, or 3->2 via kill-pane)
# keeps a big main pane on the LEFT (75%) with the other pane narrow on the right
# ([75%][25%]) -- but ONLY when that left pane is running nvim (editor wants the
# room). For a plain shell it falls through to even-horizontal like every other
# split. Beyond that we only rebalance a PURE single axis, so nested stay local:
#   h + single row    -> even-horizontal (equal-width columns | | |, never stacks)
#   v + single column -> even-vertical   (equal-height rows)
#   nested / mixed     -> leave the raw split alone (splits only within that pane)

orient="${1:-h}"
win="${2:-}"
target=()
[ -n "$win" ] && target=(-t "$win")

npanes=$(tmux list-panes "${target[@]}" 2>/dev/null | wc -l | tr -d ' ')
[ -z "$npanes" ] || [ "$npanes" -lt 2 ] && exit 0

tops=$(tmux list-panes "${target[@]}" -F '#{pane_top}' | sort -u | wc -l | tr -d ' ')
lefts=$(tmux list-panes "${target[@]}" -F '#{pane_left}' | sort -u | wc -l | tr -d ' ')

# Is the left-most (original) pane running nvim? After a `-h` split the new pane
# is on the right, so the editor sits at the smallest pane_left; same holds for
# the surviving side-by-side pair after a kill-pane.
left_cmd=$(tmux list-panes "${target[@]}" -F '#{pane_left} #{pane_current_command}' \
  | sort -n | head -1 | cut -d' ' -f2-)
case "$left_cmd" in
  nvim | vim) left_is_nvim=1 ;;
  *) left_is_nvim=0 ;;
esac

# 2 panes in one side-by-side row (tops==1) + nvim on the left -> 75/25 main-pane.
# Fires on both the first split (h) and dropping 3->2 (auto).
if { [ "$orient" = "h" ] || [ "$orient" = "auto" ]; } \
  && [ "$npanes" -eq 2 ] && [ "$tops" -eq 1 ] && [ "$left_is_nvim" -eq 1 ]; then
  tmux set-window-option "${target[@]}" main-pane-width 75%
  tmux select-layout "${target[@]}" main-vertical
  exit 0
fi

if { [ "$orient" = "h" ] || [ "$orient" = "auto" ]; } && [ "$tops" -eq 1 ]; then
  tmux select-layout "${target[@]}" even-horizontal
elif { [ "$orient" = "v" ] || [ "$orient" = "auto" ]; } && [ "$lefts" -eq 1 ]; then
  tmux select-layout "${target[@]}" even-vertical
fi

exit 0
