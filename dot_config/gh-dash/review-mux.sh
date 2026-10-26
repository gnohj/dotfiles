. "$HOME/.local/bin/mux/shared/mux-detect.sh"

review_mux_target() {
  local path="$1" remote="${2:-}" label host target
  label="${path#"$HOME/Developer/"}"
  # A Mac review runs on the dev box unless the Library picked this Mac.
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
  case "${MUX_FORCE_KIND:-}" in
    rex) review_mux_rex_target "$label" ;;
    herdr) review_mux_herdr_target "$path" ;;
    tmux) return 1 ;;
    *) review_mux_rex_target "$label" || review_mux_herdr_target "$path" ;;
  esac
}

review_mux_rex_target() {
  local label="$1" rex ws tabs
  rex="$(rex_bin)" || return 1
  ws="$("$rex" --autostart=false ls --json 2>/dev/null | jq -r --arg label "$label" \
    'first(.sessions[]? | select((.label // "" | sub("^[^A-Za-z0-9]+"; "")) == $label) | .session_id) // empty')" || return 1
  [ -n "$ws" ] || return 1
  tabs="$("$rex" --autostart=false window ls -s "$ws" --json 2>/dev/null)" || return 1
  printf '%s' "$tabs" | jq -c --arg ws "$ws" '{kind:"rex", workspace:$ws, tabs:[.windows[]?]}'
}

# Label first: any pane can cd into the checkout, so its cwd is only a fallback.
review_mux_herdr_target() {
  local path="$1" sock ws tabs
  local herdr="${HERDR_BIN_PATH:-herdr}"
  sock="$("$HOME/.local/bin/mux/shared/herdr-socket-path" 2>/dev/null || true)"
  [ -n "$sock" ] || return 1
  ws="$(HERDR_SOCKET_PATH="$sock" "$herdr" workspace list 2>/dev/null | jq -r --arg label "${path#"$HOME/Developer/"}" '
    first(.result.workspaces[]? | select((.label // "" | sub("^[^A-Za-z0-9]+"; "")) == $label) | .workspace_id) // empty' || true)"
  [ -n "$ws" ] || ws="$(HERDR_SOCKET_PATH="$sock" "$herdr" pane list 2>/dev/null | jq -r --arg path "$path" '
    first(.result.panes[]? | select((.foreground_cwd // .cwd // "") == $path) | .workspace_id) // empty' || true)"
  [ -n "$ws" ] || return 1
  tabs="$(HERDR_SOCKET_PATH="$sock" "$herdr" tab list 2>/dev/null)" || return 1
  printf '%s' "$tabs" | jq -c --arg ws "$ws" --arg sock "$sock" \
    '{kind:"herdr", workspace:$ws, socket:$sock, tabs:[.result.tabs[]? | select(.workspace_id == $ws)]}'
}

# An inherited pane workspace is not a choice; only REVIEW_PLACED=1 is.
review_mux_adopt() {
  local target
  [ "${REVIEW_PLACED:-}" = 1 ] && return 0
  if target="$(review_mux_target "$1")"; then
    unset HERDR_WORKSPACE_ID REX_SESSION
    review_mux_env "$target"
    export "${review_env[@]}"
  elif [ -n "${REVIEW_FALLBACK_HERDR_WORKSPACE:-}" ]; then
    unset REX_SESSION
    export MUX_FORCE_KIND=herdr HERDR_WORKSPACE_ID="$REVIEW_FALLBACK_HERDR_WORKSPACE"
  fi
}

review_origin_account() {
  local name dir
  case "$1" in iheartradio/inferno-monorepo) name=inferno ;; *) name="${1#*/}" ;; esac
  for dir in "$HOME/Developer/$name/review" "$HOME/Developer/$name" "$HOME"; do [ -d "$dir" ] && break; done
  (cd "$dir" && env -u CLAUDE_ACCOUNT "$HOME/.local/bin/claude-account" resolve 2>/dev/null)
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
