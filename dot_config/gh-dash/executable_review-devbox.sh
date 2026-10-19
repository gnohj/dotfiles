#!/usr/bin/env bash
# review-devbox.sh <mode> <pr-number> <repo-name> - run review-open.sh on the dev box, resolving its herdr socket and workspace there.

set -euo pipefail

mode="${1:?review-devbox: missing <mode>}"
pr="${2:?review-devbox: missing <pr-number>}"
repo="${3:?review-devbox: missing <repo-name>}"
case "$pr" in '' | *[!0-9]*) echo "review-devbox: PR must be numeric" >&2; exit 2 ;; esac
[[ "$mode" =~ ^[a-z]+$ ]] || { echo "review-devbox: invalid mode" >&2; exit 2; }
[[ "$repo" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || { echo "review-devbox: invalid repository" >&2; exit 2; }

LOG="${XDG_STATE_HOME:-$HOME/.local/state}/gh-review-open.log"
mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
echo "=== $(date '+%Y-%m-%d %H:%M:%S') devbox mode=$mode PR $pr ($repo) ==="

notify_fail() {
  local rc=$?
  [ "$rc" -eq 0 ] && return 0
  "$HOME/.local/bin/mux/mux" notify --title "dev box review" "review-devbox: $mode PR $pr failed (exit $rc) - see $LOG" || true
}
trap notify_fail EXIT

host="$(cat "$HOME/.config/devbox-host" 2>/dev/null || true)"
if [ -z "$host" ] && [ "$(uname -s)" = Darwin ]; then
  echo "review-devbox: ~/.config/devbox-host is missing"
  exit 1
fi

read -r -d '' remote <<'EOF' || true
set -euo pipefail
mode="$1" pr="$2" repo="$3"
case "$repo" in
  iheartradio/web) repo_path="$HOME/Developer/web/review" ;;
  iheartradio/inferno-monorepo) repo_path="$HOME/Developer/inferno/review" ;;
  *) repo_path="$HOME/Developer/${repo#*/}" ;;
esac
sock="$("$HOME/.local/bin/mux/shared/herdr-socket-path" 2>/dev/null || true)"
ws=""
envs=()
if [ -n "$sock" ]; then
  ws="$(HERDR_SOCKET_PATH="$sock" herdr pane list 2>/dev/null | jq -r --arg path "$repo_path" '
    first(.result.panes[]? | select((.foreground_cwd // .cwd // "") == $path) | .workspace_id) // empty')"
  envs=(HERDR_SOCKET_PATH="$sock" HERDR_WORKSPACE_ID="$ws")
fi
# setsid -f so the review outlives this ssh session; no herdr socket leaves mux detection to review-open.sh.
env ${envs[@]+"${envs[@]}"} setsid -f bash "$HOME/.config/gh-dash/review-open.sh" "$mode" "$pr" "$repo" "$repo_path" </dev/null >/dev/null 2>&1
echo "review-devbox: started $mode PR $pr on $(hostname -s) in workspace ${ws:-<active>}"
EOF

if [ -z "$host" ] || [ "$(hostname -s)" = "$host" ]; then
  bash -c "$remote" _ "$mode" "$pr" "$repo"
else
  ssh -o BatchMode=yes -o ConnectTimeout=5 -o ClearAllForwardings=yes "$host" bash -s -- "$mode" "$pr" "$repo" <<<"$remote"
fi
