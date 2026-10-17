#!/bin/bash

# Mirrors recent screenshots to the dev-box /tmp/agent-clip so pasted Mac paths open for remote crewmates.

set -uo pipefail

SHOT_DIR="$HOME/Pictures/screenshots"
HOST="fleet-dev-box"
STAGE="/tmp/agent-clip"
LOG_DIR="$HOME/.logs/screenshot-mirror"
LOG_FILE="$LOG_DIR/screenshot-mirror_$(date '+%Y%m').log"

mkdir -p "$LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG_FILE"
}

[[ -d "$SHOT_DIR" ]] || exit 0

# A capture tool may still be writing when launchd fires on the directory change.
sleep 1

files=()
while IFS= read -r -d '' file; do
  files+=("$file")
done < <(find "$SHOT_DIR" -maxdepth 1 -type f -mmin -1440 -print0 2>/dev/null)

(( ${#files[@]} )) || exit 0

ssh_cmd="ssh -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=2 -o ServerAliveCountMax=2"
remote_prep="mkdir -p -m 700 $STAGE && chmod 700 $STAGE && find $STAGE -type f -mmin +1440 -delete 2>/dev/null; rsync"

rsync -t --ignore-existing -e "$ssh_cmd" --rsync-path="$remote_prep" "${files[@]}" "$HOST:$STAGE/" 2>>"$LOG_FILE"
status=$?
if (( status == 0 )); then
  log "OK: ${#files[@]} recent screenshot(s) present on $HOST:$STAGE"
else
  log "FAIL: rsync to $HOST exited $status"
fi

find "$LOG_DIR" -type f -name 'screenshot-mirror_*.log' ! -name "screenshot-mirror_$(date '+%Y%m').log" -delete 2>/dev/null
exit 0
