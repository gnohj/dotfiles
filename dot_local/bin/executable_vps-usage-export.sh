#!/usr/bin/env bash
# Export the sysstat (sar) time-series to CSV for the 16-vs-32 GB trial verdict.
# Linux/VPS only — no-ops loudly on macOS (there is no sar history there).
#
# Usage:
#   vps-usage-export.sh                 # today's sar file
#   vps-usage-export.sh 15 16 17        # specific days-of-month
#   vps-usage-export.sh --all           # every retained sar file
#
# Writes semicolon-delimited CSV (sadf -d, import-ready) to ~/vps-usage/:
#   <YYYYMMDD>-cpu.csv   (sar -u:  %user %system %iowait %idle ...)
#   <YYYYMMDD>-mem.csv   (sar -r:  kbmemused %memused kbbuffers kbcached ...)
#   <YYYYMMDD>-swap.csv  (sar -S:  kbswpused %swpused ...)
# then prints the verdict signals: peak %memused, any swap use, and OOM kills.
set -uo pipefail

if [ "$(uname -s)" != "Linux" ]; then
  echo "vps-usage-export: Linux/VPS only (no sar history on $(uname -s))." >&2
  exit 0
fi

if ! command -v sadf >/dev/null 2>&1; then
  echo "vps-usage-export: sysstat not installed (need 'sadf'). apt install sysstat." >&2
  exit 1
fi

# sar binaries live in /var/log/sysstat (Debian/Ubuntu) or /var/log/sa (RHEL).
SA_DIR="/var/log/sysstat"
[ -d "$SA_DIR" ] || SA_DIR="/var/log/sa"
OUT="$HOME/vps-usage"
mkdir -p "$OUT"

# Build the list of sar files to export.
files=()
if [ "${1:-}" = "--all" ]; then
  for f in "$SA_DIR"/sa[0-9][0-9]; do [ -f "$f" ] && files+=("$f"); done
elif [ "$#" -gt 0 ]; then
  for d in "$@"; do
    dd="$(printf '%02d' "$((10#$d))" 2>/dev/null)" || { echo "skip bad day: $d" >&2; continue; }
    f="$SA_DIR/sa$dd"
    [ -f "$f" ] && files+=("$f") || echo "no sar file for day $dd ($f)" >&2
  done
else
  f="$SA_DIR/sa$(date +%d)"
  [ -f "$f" ] && files+=("$f") || echo "no sar file for today ($f)" >&2
fi

if [ "${#files[@]}" -eq 0 ]; then
  echo "vps-usage-export: nothing to export (sysstat may not have collected yet)." >&2
  exit 1
fi

for f in "${files[@]}"; do
  dd="${f##*/sa}"
  stamp="$(date +%Y%m)$dd"
  sadf -d "$f" -- -u >"$OUT/${stamp}-cpu.csv"  2>/dev/null && echo "→ $OUT/${stamp}-cpu.csv"
  sadf -d "$f" -- -r >"$OUT/${stamp}-mem.csv"  2>/dev/null && echo "→ $OUT/${stamp}-mem.csv"
  sadf -d "$f" -- -S >"$OUT/${stamp}-swap.csv" 2>/dev/null && echo "→ $OUT/${stamp}-swap.csv"
done

echo
echo "== 16-vs-32 GB verdict signals =="

# Peak of a column looked up by NAME from the sadf CSV header - sar's text columns shift with 12h/24h timestamps, so the old fixed-index parse read raw kB as a percent.
csv_peak() {
  local csv="$1" name="$2" idx
  [ -f "$csv" ] || return 1
  idx="$(head -1 "$csv" | tr ';' '\n' | grep -nxF "$name" | head -1 | cut -d: -f1)"
  [ -n "$idx" ] || return 1
  awk -F';' -v c="$idx" 'NR>1 && $c ~ /^[0-9.]+$/ { if ($c+0 > m) m=$c+0 } END { if (m!="") printf "%.1f", m }' "$csv"
}

stamp0="$(date +%Y%m)${files[0]##*/sa}"
mem_peak="$(csv_peak "$OUT/${stamp0}-mem.csv" "%memused")"
swap_peak="$(csv_peak "$OUT/${stamp0}-swap.csv" "%swpused")"
echo "  peak %memused (first file): ${mem_peak:-n/a}%"
echo "  peak %swpused (first file): ${swap_peak:-n/a}%   (any sustained swap → lean 32 GB)"
echo "  memory pressure (live):     $(awk -F'[= ]' '/some/{print $3}' /proc/pressure/memory 2>/dev/null || echo n/a)"
echo "  OOM kills (the decider):"
if command -v journalctl >/dev/null 2>&1; then
  journalctl -k --no-pager 2>/dev/null | grep -iE "out of memory|killed process" | tail -10 \
    || echo "    none — no agent has been OOM-killed"
else
  dmesg -T 2>/dev/null | grep -iE "oom|killed process" | tail -10 || echo "    none (or dmesg restricted)"
fi
