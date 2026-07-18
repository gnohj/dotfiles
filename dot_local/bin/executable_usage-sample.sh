#!/usr/bin/env bash
# Sample CPU/mem ONCE and append a CSV row — the historical record behind the
# "can I downgrade the MacBook / how to size the dev-box" decision. A launchd
# agent (macOS) runs this every ~5 min; also fine to run by hand. uname-branched,
# same CSV schema on macOS + Linux so usage-report.sh reads either.
#
# macOS note: "free memory" is meaningless (the OS uses it all for cache +
# compression). The real downgrade signals are MEMORY PRESSURE + SWAP, so those
# are recorded here, not a misleading free-MB number.
#
# Output: ~/.local/state/usage/YYYY-MM.csv  (monthly file; ~9k rows/month, tiny)
# Columns: ts,load1,load5,load15,ncpu,mem_used_gb,mem_total_gb,mem_used_pct,swap_used_mb,pressure
#   pressure = macOS: normal|warn|critical   Linux: memory-PSI some-avg10 (%)
set -uo pipefail

OUT_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/usage"
mkdir -p "$OUT_DIR"
CSV="$OUT_DIR/$(date +%Y-%m).csv"
HEADER="ts,load1,load5,load15,ncpu,mem_used_gb,mem_total_gb,mem_used_pct,swap_used_mb,pressure"
[ -f "$CSV" ] || echo "$HEADER" >"$CSV"

ts="$(date +%FT%T)"

case "$(uname -s)" in
  Darwin)
    read -r l1 l5 l15 < <(sysctl -n vm.loadavg | awk '{print $2, $3, $4}')
    ncpu="$(sysctl -n hw.ncpu)"
    total_bytes="$(sysctl -n hw.memsize)"
    pagesize="$(sysctl -n hw.pagesize)"
    # Activity Monitor "Memory Used" ≈ (active + wired + compressed) pages.
    used_pages="$(vm_stat | awk -F':' '
      /Pages active/                 {gsub(/[ .]/,"",$2); a=$2}
      /Pages wired down/             {gsub(/[ .]/,"",$2); w=$2}
      /Pages occupied by compressor/ {gsub(/[ .]/,"",$2); c=$2}
      END {print a+w+c}')"
    used_bytes=$(( used_pages * pagesize ))
    mem_used_gb="$(awk -v b="$used_bytes"   'BEGIN{printf "%.2f", b/1073741824}')"
    mem_total_gb="$(awk -v b="$total_bytes" 'BEGIN{printf "%.2f", b/1073741824}')"
    mem_used_pct="$(awk -v u="$used_bytes" -v t="$total_bytes" 'BEGIN{printf "%.1f", 100*u/t}')"
    swap_used_mb="$(sysctl -n vm.swapusage | awk '{for(i=1;i<=NF;i++) if($i=="used"){v=$(i+2); gsub(/[MG]/,"",v); print v; exit}}')"
    case "$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null)" in
      1) pressure=normal ;; 2) pressure=warn ;; 4) pressure=critical ;; *) pressure=na ;;
    esac
    ;;
  Linux)
    read -r l1 l5 l15 _ </proc/loadavg
    ncpu="$(nproc 2>/dev/null || echo 1)"
    total_kb="$(awk '/^MemTotal:/{print $2}' /proc/meminfo)"
    avail_kb="$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)"
    used_kb=$(( total_kb - avail_kb ))
    mem_used_gb="$(awk -v k="$used_kb"   'BEGIN{printf "%.2f", k/1048576}')"
    mem_total_gb="$(awk -v k="$total_kb" 'BEGIN{printf "%.2f", k/1048576}')"
    mem_used_pct="$(awk -v u="$used_kb" -v t="$total_kb" 'BEGIN{printf "%.1f", 100*u/t}')"
    swt="$(awk '/^SwapTotal:/{print $2}' /proc/meminfo)"
    swf="$(awk '/^SwapFree:/{print $2}' /proc/meminfo)"
    swap_used_mb="$(awk -v u="$(( swt - swf ))" 'BEGIN{printf "%.0f", u/1024}')"
    pressure="$(awk -F'[= ]' '/some/{print $3}' /proc/pressure/memory 2>/dev/null || echo na)"
    ;;
  *) exit 0 ;;
esac

printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
  "$ts" "$l1" "$l5" "$l15" "$ncpu" "$mem_used_gb" "$mem_total_gb" "$mem_used_pct" "$swap_used_mb" "$pressure" \
  >>"$CSV"
