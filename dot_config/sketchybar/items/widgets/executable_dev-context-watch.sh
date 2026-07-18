#!/bin/bash
# Auto-drive dev-context from a bare `ssh <host>` the `vps` wrapper didn't open: adopt the most-recently-opened box, hand off to the next on disconnect, revert to local only when none remain (a manual picker pick still wins). Per-branch logic noted inline.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/items/widgets/dev-context-lib.sh"

MARKER="${XDG_STATE_HOME:-$HOME/.local/state}/dev-context.auto"

# Live dev-context tokens, most-recently-opened first, de-duplicated.
ACTIVE=()
while IFS= read -r tok; do [ -n "$tok" ] && ACTIVE+=("$tok"); done < <(dc_active_tokens)

first="${ACTIVE[0]:-}"
n="${#ACTIVE[@]}"
cur="$(dev-context get 2>/dev/null || echo local)"
auto="$(cat "$MARKER" 2>/dev/null || true)"

cur_active=0
for x in "${ACTIVE[@]}"; do [ "$x" = "$cur" ] && cur_active=1 && break; done

if [ "$n" -eq 0 ]; then
  # No live sessions: revert only what WE set, never a manual offline pick.
  [ -n "$auto" ] && [ "$cur" = "$auto" ] && dev-context set local
  : >"$MARKER"
elif [ "$cur_active" = 1 ]; then
  # Already pointed at a live box (adopted, handed off, or picker-chosen): own it.
  printf '%s\n' "$cur" >"$MARKER"
elif [ "$cur" = "local" ] || { [ -n "$auto" ] && [ "$cur" = "$auto" ]; }; then
  # At local, or the box we owned just disconnected: (re)adopt the most recent.
  dev-context set "$first"
  printf '%s\n' "$first" >"$MARKER"
fi
# else: cur is a manual non-local pick with no live session — leave it untouched.
