#!/usr/bin/env bash
# context7 HTTP API wrapper for pi skill
# Free tier works without auth. Set CONTEXT7_API_KEY for higher rate limits.
set -euo pipefail

API_BASE="https://context7.com/api/v2"
AUTH_HEADER=()
if [[ -n "${CONTEXT7_API_KEY:-}" ]]; then
  AUTH_HEADER=(-H "Authorization: Bearer ${CONTEXT7_API_KEY}")
fi

usage() {
  cat >&2 <<EOF
Usage:
  $(basename "$0") search <library-name>
  $(basename "$0") docs   <library-id> <query>

Examples:
  $(basename "$0") search react
  $(basename "$0") docs /vercel/next.js "how to set up middleware"
EOF
  exit 1
}

cmd="${1:-}"
shift || usage

case "$cmd" in
  search)
    [[ $# -ge 1 ]] || usage
    curl -fsSL -G "${API_BASE}/libs/search" \
      --data-urlencode "libraryName=$1" \
      "${AUTH_HEADER[@]}"
    ;;
  docs)
    [[ $# -ge 2 ]] || usage
    library_id="$1"
    shift
    query="$*"
    curl -fsSL -G "${API_BASE}/context" \
      --data-urlencode "libraryId=${library_id}" \
      --data-urlencode "query=${query}" \
      --data-urlencode "type=json" \
      "${AUTH_HEADER[@]}"
    ;;
  *)
    usage
    ;;
esac
