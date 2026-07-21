#!/usr/bin/env bash
# Daily CPU/mem summary from the usage-sample.sh log — the "what's my daily
# mem/cpu" view for the MacBook-downgrade / dev-box-sizing decision.
#
# Usage:
#   usage-report.sh              # last 14 days
#   usage-report.sh 30           # last N days
#   usage-report.sh --csv        # dump the merged raw CSV to stdout (for charting)
#   usage-report.sh --burst [N]  # top N (default 15) load spikes + the process behind each
#
# Downgrade read: if peakMem stays well under RAM, avg% is low, peakSwap ≈ 0, and
# pressEvt ≈ 0 across weeks → you have headroom to drop to a smaller machine.
# Uses only POSIX/BSD awk (no gawk-isms) since the target is macOS.
set -uo pipefail

DIR="${XDG_STATE_HOME:-$HOME/.local/state}/usage"
if [ ! -d "$DIR" ] || [ -z "$(ls -A "$DIR" 2>/dev/null)" ]; then
  echo "usage-report: no data yet at $DIR (usage-sample.sh hasn't run)." >&2
  exit 1
fi

if [ "${1:-}" = "--csv" ]; then
  awk 'FNR==1 && seen++ {next} {print}' "$DIR"/*.csv
  exit 0
fi

# Top load spikes + the process hogging CPU then; pre-logging rows show "-" (orphans/top_proc/top_cpu = cols 11-13).
if [ "${1:-}" = "--burst" ]; then
  n="${2:-15}"
  awk -F, 'FNR==1 { next } $1 == "ts" { next } { print $2"\t"$1"\t"$8"\t"$11"\t"$12"\t"$13 }' "$DIR"/*.csv |
    sort -rn | head -n "$n" |
    awk -F'\t' '
      BEGIN { printf "%-19s %8s %6s %8s  %-18s %8s\n", "TIMESTAMP", "load1", "mem%", "orphans", "topProc", "topCpu%" }
      { printf "%-19s %8.2f %5s%% %8s  %-18s %7s%%\n",
               $2, $1+0, $3, ($4 == "" ? "-" : $4), ($5 == "" ? "-" : $5), ($6 == "" ? "-" : $6) }'
  exit 0
fi

days="${1:-14}"

# Reduce every monthly CSV to one row per calendar day (extremes), emit unsorted,
# then let the shell sort chronologically (ISO dates sort lexically) + keep last N.
rows="$(
  awk -F, '
    FNR==1 { next }
    $1 == "ts" { next }
    {
      d = substr($1, 1, 10)
      n[d]++
      if ($6+0 > pm[d]) pm[d] = $6+0
      sump[d] += $8; if ($8+0 > pp[d]) pp[d] = $8+0
      if ($2+0 > pl[d]) pl[d] = $2+0
      if ($9+0 > ps[d]) ps[d] = $9+0
      if ($10 == "warn" || $10 == "critical" || ($10+0 > 0 && $10 != "na")) pc[d]++
      if ($11+0 > po[d]) po[d] = $11+0
    }
    END {
      for (d in n)
        printf "%s %.1f %.0f %.0f %.2f %.0f %d %d %d\n", \
               d, pm[d], pp[d], sump[d]/n[d], pl[d], ps[d], pc[d]+0, po[d]+0, n[d]
    }
  ' "$DIR"/*.csv | sort | tail -n "$days"
)"

printf '%-11s %8s %6s %6s %9s %9s %8s %8s %6s\n' \
  DATE peakMem "peak%" "avg%" peakLoad peakSwap pressEvt peakOrph n
printf '%s\n' "$rows" | awk '{ printf "%-11s %6.1fG %5d%% %5d%% %9.2f %7dM %8d %8d %6d\n", $1,$2,$3,$4,$5,$6,$7,$8,$9 }'

echo
echo "peakLoad vs cores: load above your core count = CPU saturation."
echo "pressEvt: samples at warn/critical mem pressure (macOS) or nonzero mem-PSI (Linux)."
echo "peakOrph: most problem-orphans (nvim leak / >=30% cpu) seen in one sample that day."
echo "Downgrade signal: weeks of low peakMem + ~0 peakSwap + ~0 pressEvt = room to shrink."
echo "Run 'usage-report.sh --burst' to see which process was behind the load spikes."
