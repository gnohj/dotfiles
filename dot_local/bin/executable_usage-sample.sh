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
# Columns: ts,load1,load5,load15,ncpu,mem_used_gb,mem_total_gb,mem_used_pct,swap_used_mb,pressure,orphans,top_proc,top_cpu
#   pressure = macOS: normal|warn|critical   Linux: memory-PSI some-avg10 (%)
#   orphans  = PROBLEM orphans (ppid 1, non-.app/system) that `errors` flags: nvim (fff.nvim LMDB leak) or >=30% cpu (raw ppid-1 count is noise).
#   top_proc/top_cpu = heaviest process + its %cpu at sample time (>100% = multicore burst).
set -uo pipefail

OUT_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/usage"
mkdir -p "$OUT_DIR"
CSV="$OUT_DIR/$(date +%Y-%m).csv"
HEADER="ts,load1,load5,load15,ncpu,mem_used_gb,mem_total_gb,mem_used_pct,swap_used_mb,pressure,orphans,top_proc,top_cpu"
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

# Orphan + top-CPU snapshot (one portable `ps` pass). Orphans match `errors`: ppid 1, non-.app/system, only nvim-leak or >=30% cpu. top_cpu >100% = multicore burst.
read -r orphans top_proc top_cpu < <(
  ps -axo ppid=,%cpu=,command= 2>/dev/null | awk -v cpumin=30 '
    {
      ppid = $1; cpu = $2
      cmd = ""; for (i = 3; i <= NF; i++) cmd = cmd (i > 3 ? " " : "") $i
      first = $3; sub(/.*\//, "", first)
      if (cpu + 0 > mx) { mx = cpu + 0; top = first }
      if (ppid == 1) {
        if (cmd ~ /\.app\/Contents\/MacOS\//) next
        if (cmd ~ /^\/(System|usr\/libexec|usr\/sbin|sbin|Library\/Apple)\//) next
        if (first == "nvim" || cpu + 0 >= cpumin) orph++
      }
    }
    END { gsub(/,/, "", top); printf "%d %s %.1f", orph + 0, (top == "" ? "na" : top), mx + 0 }'
)
orphans="${orphans:-0}"; top_proc="${top_proc:-na}"; top_cpu="${top_cpu:-0}"

printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
  "$ts" "$l1" "$l5" "$l15" "$ncpu" "$mem_used_gb" "$mem_total_gb" "$mem_used_pct" "$swap_used_mb" "$pressure" \
  "$orphans" "$top_proc" "$top_cpu" \
  >>"$CSV"
