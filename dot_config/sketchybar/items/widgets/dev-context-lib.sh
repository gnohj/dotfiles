# Shared helpers to detect live outbound SSH sessions and map each to a dev-context token (ts:<name> for tailnet peers, ssh:<host> otherwise); sourced by both the watcher and the picker so they agree on what "live" means.

_DC_TS="$(command -v tailscale || echo /Applications/Tailscale.app/Contents/MacOS/Tailscale)"
_DC_TSJSON=""
_DC_TSJSON_DONE=""

_dc_ts_json() { # lazy: one `tailscale status` per process, reused across peers
  [ -n "$_DC_TSJSON_DONE" ] || {
    _DC_TSJSON="$([ -x "$_DC_TS" ] && "$_DC_TS" status --json 2>/dev/null)"
    _DC_TSJSON_DONE=1
  }
  printf '%s' "$_DC_TSJSON"
}

# Peer name for a Tailscale IP (100.x / fd7a:), or "" if not a tailnet address.
dc_ts_name_for_ip() {
  local j
  j="$(_dc_ts_json)"
  [ -n "$j" ] || return 0
  printf '%s' "$j" | jq -r --arg ip "$1" \
    '.Peer[]? | select(any(.TailscaleIPs[]?; . == $ip)) | (.DNSName // "" | split(".")[0]) | select(. != "")' \
    2>/dev/null | head -1
}

# Destination host of an ssh process (first non-option arg), user@ stripped.
dc_ssh_dest_for_pid() {
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

# Map an established ssh session (peer ip + typed dest) to a dev-context token.
dc_token_for() { # ip dest
  local name
  name="$(dc_ts_name_for_ip "$1")"
  [ -z "$name" ] && case "$2" in *.ts.net) name="${2%%.*}" ;; esac
  if [ -n "$name" ]; then printf 'ts:%s\n' "$name"
  elif [ -n "$2" ]; then printf 'ssh:%s\n' "$2"
  fi
}

# Live dev-context tokens, most-recently-opened first, de-duplicated.
dc_active_tokens() {
  local pid ip tok seen="|"
  while IFS=$'\t' read -r pid ip; do
    [ -z "$pid" ] && continue
    tok="$(dc_token_for "$ip" "$(dc_ssh_dest_for_pid "$pid")")"
    [ -z "$tok" ] && continue
    case "$seen" in *"|$tok|"*) continue ;; esac
    seen="$seen$tok|"
    printf '%s\n' "$tok"
  done < <(lsof -nP -iTCP:22 -sTCP:ESTABLISHED 2>/dev/null \
    | awk '$1 ~ /^ssh/ { name=$9; sub(/.*->\[?/, "", name); sub(/\]?:22$/, "", name); print $2 "\t" name }' \
    | sort -rn -k1) # highest pid (most recent) first
}
