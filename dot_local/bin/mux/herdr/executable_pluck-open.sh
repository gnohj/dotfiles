#!/usr/bin/env bash
# Usage: pluck-open.sh <picker-pid> <token> - from the pbcopy/wl-copy shims: URL → browser, file → nvim tab.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"
herdr="${HERDR_BIN_PATH:-herdr}"

open_url() {
  if [ "$(uname)" = Darwin ]; then open "$1"; else to-desktop open "$1"; fi
}

resolve_file() {
  local p=$1 cwd=$2 base
  case "$p" in "~/"*) p="$HOME/${p#\~/}" ;; esac
  if [[ $p == /* ]]; then
    [ -f "$p" ] && printf '%s' "$p"
    return
  fi
  for base in "$cwd" "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"; do
    [ -n "$base" ] && [ -f "$base/$p" ] && { printf '%s' "$base/$p"; return; }
  done
}

open_in_nvim() {
  local file=$1 line=$2 out root tab num
  out=$("$herdr" tab create ${ws:+--workspace "$ws"} --cwd "$(dirname "$file")" --label "nvim" --focus 2>/dev/null)
  root=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id // empty')
  tab=$(printf '%s' "$out" | jq -r '.result.tab.tab_id // empty')
  [ -n "$root" ] || return 1
  ws=$(printf '%s' "$out" | jq -r '.result.tab.workspace_id // empty')
  num=$("$herdr" tab list 2>/dev/null \
    | jq -r --arg ws "$ws" --arg id "$tab" \
        '([.result.tabs[] | select(.workspace_id == $ws) | .tab_id] | index($id) // empty) | if . == null then empty else . + 1 end')
  "$herdr" tab rename "$tab" "${num:+$num.}$(basename "$file")" >/dev/null 2>&1
  "$herdr" pane run "$root" "nvim ${line:++$line} $(printf %q "$file"); exit" >/dev/null 2>&1
}

dispatch() {
  # Wait for the picker to exit: its cleanup refocuses the source tab and would steal focus from a new tab.
  for _ in $(seq 1 100); do
    kill -0 "$picker_pid" 2>/dev/null || break
    sleep 0.05
  done

  case "$token" in
    http://* | https://*) open_url "$token"; return ;;
    file://*)
      local target=${token#file://}
      [ -f "$target" ] && [ ! -x "$target" ] && open_url "$token"
      return
      ;;
  esac

  [ -n "$pane" ] || return 0
  local cwd path=$token line="" file
  cwd=$("$herdr" pane get "$pane" 2>/dev/null | jq -r '.result.pane | (.foreground_cwd // .cwd) // empty')
  file=$(resolve_file "$path" "$cwd")
  if [ -z "$file" ] && [[ $token =~ ^(.+):([0-9]+)(:[0-9]+)?:?$ ]]; then
    path=${BASH_REMATCH[1]} line=${BASH_REMATCH[2]}
    file=$(resolve_file "$path" "$cwd")
  fi
  [ -n "$file" ] && open_in_nvim "$file" "$line"
}

if [ "${1:-}" = --dispatch ]; then
  picker_pid=$2 token=$3 pane=$4 ws=$5
  dispatch
  exit
fi

picker_pid=${1:?picker pid}
token=${2:?token}

# Read the snapshot now: pluck deletes it during cleanup, which starts as soon as the shim returns.
snapshot=$(ps -o args= -p "$picker_pid" 2>/dev/null | sed -n 's/.* --snapshot \([^ ]*\).*/\1/p')
pane="" ws=""
if [ -r "$snapshot" ]; then
  IFS=$'\t' read -r pane ws < <(jq -r '[.source.target_pane_id, .source.workspace_id] | @tsv' "$snapshot" 2>/dev/null)
fi

# Detach synchronously into a new session: herdr kills the picker pane's process group as soon as the shim returns.
perl -MPOSIX=setsid -e 'my $p = fork // exit 1; if ($p) { waitpid($p, 0); exit } setsid; fork and exit; exec @ARGV' -- \
  "$0" --dispatch "$picker_pid" "$token" "$pane" "$ws" </dev/null >/dev/null 2>&1
