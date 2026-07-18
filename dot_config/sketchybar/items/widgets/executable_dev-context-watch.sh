#!/bin/bash
# Auto-drive dev-context from a bare `ssh <host>` the `vps` wrapper didn't open: adopt the most-recently-opened box, hand off to the next on disconnect, revert to local only when none remain (a manual picker pick still wins). Per-branch logic noted inline.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

MARKER="${XDG_STATE_HOME:-$HOME/.local/state}/dev-context.auto"
TS="$(command -v tailscale || echo /Applications/Tailscale.app/Contents/MacOS/Tailscale)"
TSJSON="$([ -x "$TS" ] && "$TS" status --json 2>/dev/null)"

# Peer name for a Tailscale IP (100.x / fd7a:), or "" if not a tailnet address.
ts_name_for_ip() {
  [ -n "$TSJSON" ] || return 0
  printf '%s' "$TSJSON" | jq -r --arg ip "$1" \
    '.Peer[]? | select(any(.TailscaleIPs[]?; . == $ip)) | (.DNSName // "" | split(".")[0]) | select(. != "")' \
    2>/dev/null | head -1
}

# Destination host of an ssh process (first non-option arg), user@ stripped.
ssh_dest_for_pid() {
  local args need_arg=0 tok
  args="$(ps -p "$1" -o args= 2>/dev/null)"
  # shellcheck disable=SC2086
  set -- $args
  shift # drop "ssh"
  for tok in "$@"; do
    if [ "$need_arg" = 1 ]; then need_arg=0; continue; fi
    case "$tok" in
      -b | -c | -D | -E | -e | -F | -I | -i | -J | -L | -l | -m | -O | -o | -p | -Q | -R | -S | -W | -w) need_arg=1 ;;
      -*) : ;;
      *) printf '%s\n' "${tok##*@}"; return 0 ;;
    esac
  done
}

# Map an established ssh session (ip + typed dest) to a dev-context token.
token_for() { # ip dest
  local name="$(ts_name_for_ip "$1")"
  [ -z "$name" ] && case "$2" in *.ts.net) name="${2%%.*}" ;; esac
  if [ -n "$name" ]; then printf 'ts:%s\n' "$name"
  elif [ -n "$2" ]; then printf 'ssh:%s\n' "$2"
  fi
}

# Live dev-context tokens, most-recently-opened first, de-duplicated.
ACTIVE=()
while IFS=$'\t' read -r pid ip; do
  [ -z "$pid" ] && continue
  tok="$(token_for "$ip" "$(ssh_dest_for_pid "$pid")")"
  [ -z "$tok" ] && continue
  dup=0
  for x in "${ACTIVE[@]}"; do [ "$x" = "$tok" ] && dup=1 && break; done
  [ "$dup" = 0 ] && ACTIVE+=("$tok")
done < <(lsof -nP -iTCP:22 -sTCP:ESTABLISHED 2>/dev/null \
  | awk '$1 ~ /^ssh/ { name=$9; sub(/.*->\[?/, "", name); sub(/\]?:22$/, "", name); print $2 "\t" name }' \
  | sort -rn -k1) # highest pid (most recent) first

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
