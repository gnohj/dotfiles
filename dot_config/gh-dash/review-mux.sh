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
  review_mux_rex_target "$label"
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

# An inherited pane workspace is not a choice; only REVIEW_PLACED=1 is.
review_mux_adopt() {
  local target
  [ "${REVIEW_PLACED:-}" = 1 ] && return 0
  if target="$(review_mux_target "$1")"; then
    unset REX_SESSION
    review_mux_env "$target"
    export "${review_env[@]}"
  fi
}

review_origin_account() {
  local name dir
  case "$1" in iheartradio/inferno-monorepo) name=inferno ;; *) name="${1#*/}" ;; esac
  for dir in "$HOME/Developer/$name/review" "$HOME/Developer/$name" "$HOME"; do [ -d "$dir" ] && break; done
  (cd "$dir" && env -u CLAUDE_ACCOUNT "$HOME/.local/bin/claude-account" resolve 2>/dev/null)
}

review_mux_env() {
  local ws
  ws="$(printf '%s' "$1" | jq -r '.workspace')"
  review_env=(MUX_FORCE_KIND=rex REX_SESSION="$ws")
}

review_mux_has_pr() {
  printf '%s' "$1" | jq -e --arg pr "$2" \
    'any(.tabs[]?; (.label // "") | test("#" + $pr + "([^0-9]|$)"))' >/dev/null
}
