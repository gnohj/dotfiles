. "$HOME/.local/bin/mux/shared/mux-detect.sh"

review_mux_target() {
  local path="$1" remote="${2:-}" sock ws rex tabs label host target
  local herdr="${HERDR_BIN_PATH:-herdr}"
  sock="$("$HOME/.local/bin/mux/shared/herdr-socket-path" 2>/dev/null || true)"
  ws=""
  if [ -n "$sock" ]; then
    ws="$(HERDR_SOCKET_PATH="$sock" "$herdr" pane list 2>/dev/null | jq -r --arg path "$path" '
      first(.result.panes[]? | select((.foreground_cwd // .cwd // "") == $path) | .workspace_id) // empty' || true)"
  fi
  if [ -n "$ws" ]; then
    tabs="$(HERDR_SOCKET_PATH="$sock" "$herdr" tab list 2>/dev/null)" || return 1
    printf '%s' "$tabs" | jq -c --arg ws "$ws" --arg sock "$sock" \
      '{kind:"herdr", workspace:$ws, socket:$sock, tabs:[.result.tabs[]? | select(.workspace_id == $ws)]}'
    return
  fi
  label="${path#"$HOME/Developer/"}"
  if [ "$remote" = remote ] && [ "$(uname -s)" = Darwin ] && [ "${REVIEW_RUN_HERE:-}" != 1 ]; then
    host="$(cat "$HOME/.config/devbox-host" 2>/dev/null || true)"
    [ -n "$host" ] || return 1
    [[ "$label" =~ ^[A-Za-z0-9._/-]+$ ]] || return 1
    target="$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o ClearAllForwardings=yes "$host" bash -s -- "$label" <<'EOF'
set -euo pipefail
. "$HOME/.config/gh-dash/review-mux.sh"
review_mux_target "$HOME/Developer/$1"
EOF
)" || return 1
    printf '%s' "$target" | jq -c '. + {remote:true}'
    return
  fi
  rex="$(rex_bin)" || return 1
  ws="$("$rex" --autostart=false ls --json 2>/dev/null | jq -r --arg label "$label" \
    'first(.sessions[]? | select(.label == $label) | .session_id) // empty')" || return 1
  [ -n "$ws" ] || return 1
  tabs="$("$rex" --autostart=false window ls -s "$ws" --json 2>/dev/null)" || return 1
  printf '%s' "$tabs" | jq -c --arg ws "$ws" '{kind:"rex", workspace:$ws, tabs:[.windows[]?]}'
}

review_mux_env() {
  local kind ws sock
  kind="$(printf '%s' "$1" | jq -r '.kind')"
  ws="$(printf '%s' "$1" | jq -r '.workspace')"
  if [ "$kind" = herdr ]; then
    sock="$(printf '%s' "$1" | jq -r '.socket')"
    review_env=(HERDR_SOCKET_PATH="$sock" HERDR_WORKSPACE_ID="$ws")
  else
    review_env=(MUX_FORCE_KIND=rex REX_SESSION="$ws")
  fi
}

review_mux_has_pr() {
  printf '%s' "$1" | jq -e --arg pr "$2" \
    'any(.tabs[]?; (.label // "") | test("#" + $pr + "([^0-9]|$)"))' >/dev/null
}
