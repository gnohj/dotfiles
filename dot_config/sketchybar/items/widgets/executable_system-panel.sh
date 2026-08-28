#!/bin/bash
# Top consumers behind the cpu / memory / disk widgets, as TSV the Lua side turns into popup rows.
#
#   system-panel.sh cpu      # top processes by %CPU
#   system-panel.sh memory   # top processes by resident size
#   system-panel.sh disk     # mounted volumes as used / free
#
# Rows are `row<TAB>name<TAB>value`; the headline stays with the widget (ps sums %CPU across cores).

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

LIMIT="${SYSTEM_PANEL_LIMIT:-5}"

# comm, not command: the full argv of an Electron app is hundreds of characters of flags.
top_cpu() {
  ps -Aceo pcpu,comm -r 2>/dev/null | awk -v n="$LIMIT" '
    NR > 1 && $1 > 0 {
      pct = $1
      $1 = ""
      sub(/^[ \t]+/, "")
      printf "row\t%s\t%.1f%%\n", $0, pct
      if (++c >= n) exit
    }'
}

top_memory() {
  ps -Aceo rss,comm -m 2>/dev/null | awk -v n="$LIMIT" '
    NR > 1 && $1 > 0 {
      kb = $1
      $1 = ""
      sub(/^[ \t]+/, "")
      unit = "MB"; val = kb / 1024
      if (val >= 1024) { val /= 1024; unit = "GB" }
      printf "row\t%s\t%.1f %s\n", $0, val, unit
      if (++c >= n) exit
    }'
}

# The Data volume, not /: that is where user data lives and what the widget's own badge measures.
# Everything else under /System/Volumes is a nullfs/devfs mount reporting the same container.
top_disk() {
  df -H 2>/dev/null | awk -v n="$LIMIT" '
    NR > 1 && $1 ~ /^\/dev\// {
      used = $3; avail = $4; mount = $9
      for (i = 10; i <= NF; i++) mount = mount " " $i
      if (mount != "/System/Volumes/Data" && mount !~ /^\/Volumes\//) next
      if (seen[mount]++) next
      name = (mount == "/System/Volumes/Data") ? "Macintosh HD" : mount
      sub(/^\/Volumes\//, "", name)
      printf "row\t%s\t%s / %s\n", name, used, avail
      if (++c >= n) exit
    }'
}

case "${1:-}" in
  cpu) top_cpu ;;
  memory) top_memory ;;
  disk) top_disk ;;
esac
