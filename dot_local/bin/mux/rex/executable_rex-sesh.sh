#!/usr/bin/env bash
# Sesh picker for Rex (init.lua ctrl+t); the final switch is a CLI-requested app action, so Remote Control must be on.
set -uo pipefail

rex="${REX_BIN_DIR:+$REX_BIN_DIR/}rex"
export _ZO_DATA_DIR="${_ZO_DATA_DIR:-$HOME/.config/zshrc}"

rows() {
  local open
  open=$("$rex" ls --json 2>/dev/null | jq -c '[.sessions[] | {id: .session_id, label}]')
  [ -n "$open" ] || open='[]'
  printf '%s' "$open" | jq -r '.[] | "⚡ \(.label)\tsession\t\(.id)"'
  sesh list -c -j 2>/dev/null | jq -r --argjson open "$open" '
    ($open | map(.label)) as $labels
    | .[] | select(.Name as $n | $labels | index($n) | not)
    | "⚙ \(.Name)\(if .Alias != "" then " (\(.Alias))" else "" end)\tconfig\t\({label: .Name, dir: (.Path | rtrimstr("/") | if . == "" then "/" else . end), startup: .StartupCommand} | tojson)"'
  local config_paths
  config_paths=$(sesh list -c -j 2>/dev/null | jq -r '.[].Path | rtrimstr("/")')
  zoxide query -l 2>/dev/null | grep -vxF -f <(printf '%s\n' "$config_paths") | while IFS= read -r dir; do
    printf '📁 %s\tdir\t%s\n' "${dir/#$HOME/\~}" "$(jq -cn --arg d "$dir" '{label: ($d | split("/") | last), dir: $d}')"
  done
}

preview() {
  if [ "$1" = session ]; then
    local view block
    view=$("$rex" api call -s "$2" session.view 2>/dev/null)
    jq -r '"tabs: " + ([.windows[].label] | join("  "))' <<<"$view"
    block=$(jq -r '(.active_window_id) as $a | .windows[] | select(.window_id == $a) | .layers[] | select(.kind == "tiled") | .blocks[0].block_id' <<<"$view")
    [ -n "$block" ] && "$rex" capture -b "$block" --trim 2>/dev/null
  else
    eza --all --git --icons --color=always "$(jq -r .dir <<<"$2")"
  fi
}

if [ "${1:-}" = --preview ]; then
  preview "$2" "$3"
  exit 0
fi

app_client() {
  "$rex" client ls --json 2>/dev/null | jq -r '[.clients[] | select(.info.kind == "app")][0].client_id // empty'
}

pick=$(rows | fzf --ansi --delimiter '\t' --with-nth 1 --no-sort --layout reverse \
  --border rounded --border-label ' rex sesh ' --prompt '⚡ ' \
  --preview "$0 --preview {2} {3}" \
  --preview-window 'right,55%')
[ -n "$pick" ] || exit 0

kind=$(cut -f2 <<<"$pick")
payload=$(cut -f3 <<<"$pick")
client=$(app_client)

if [ "$kind" = session ]; then
  out=$("$rex" do -C "$client" session.select session_id="$payload" 2>&1)
  rc=$?
else
  out=$("$rex" do -C "$client" sesh_open --args "$payload" 2>&1)
  rc=$?
fi

if [ "$rc" -ne 0 ]; then
  printf '\n%s\n\nPress any key to close.' "$out"
  read -rsn1
fi
