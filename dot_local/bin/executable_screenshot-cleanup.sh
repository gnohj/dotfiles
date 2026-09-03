#!/bin/bash

# The screenshot folder is also the real downloads folder, so this matches exact names, never sweeps the directory.

set -uo pipefail

SHOT_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Downloads"
LOG_DIR="$HOME/.logs/screenshot-cleanup"
LOG_FILE="$LOG_DIR/screenshot-cleanup_$(date '+%Y%m').log"

# macshot/hyper+x "Screenshot-2026-09-02 at 19-56-33.png" and native "Screenshot 2026-09-02 at 19.56.33.png"; .mov recordings share the template and stay.
STAMP='[0-9]{4}-[0-9]{2}-[0-9]{2}'
DUPE='( \([0-9]+\))?'
EXT='\.(png|jpg|jpeg|heic)(\.icloud)?$'
NAME_RE="^\.?Screenshot(-${STAMP} at [0-9]{2}-[0-9]{2}-[0-9]{2}| ${STAMP} at [0-9]{1,2}\.[0-9]{2}\.[0-9]{2}( (AM|PM))?)${DUPE}${EXT}"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

mkdir -p "$LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" | tee -a "$LOG_FILE"
}

if [[ ! -d "$SHOT_DIR" ]]; then
  log "SKIP: $SHOT_DIR is not present"
  exit 0
fi

deleted=0
skipped=0

while IFS= read -r -d '' file; do
  name="${file##*/}"
  if [[ ! "$name" =~ $NAME_RE ]]; then
    skipped=$((skipped + 1))
    continue
  fi
  if (( DRY_RUN )); then
    log "WOULD DELETE: $name"
  else
    if rm -f "$file"; then
      log "DELETE: $name"
    else
      log "WARN: could not delete $name"
      continue
    fi
  fi
  deleted=$((deleted + 1))
done < <(find "$SHOT_DIR" -maxdepth 1 -type f -print0 2>/dev/null)

log "Done: $deleted screenshot(s) $( ((DRY_RUN)) && echo matched || echo deleted ), $skipped other file(s) left untouched"

find "$LOG_DIR" -type f -name 'screenshot-cleanup_*.log' ! -name "screenshot-cleanup_$(date '+%Y%m').log" -delete 2>/dev/null
