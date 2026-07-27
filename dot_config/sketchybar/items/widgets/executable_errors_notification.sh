#!/bin/bash
# errors monitor -> sketchybar "errors" badge: service-log errors + ppid-1 orphans (fff/treehouse/cpu) + unreaped zombies. Env: ERRORS_DRYRUN, ORPHAN_THRESHOLD (default 70), ZOMBIE_THRESHOLD, ZOMBIE_MIN_AGE.
shopt -s nullglob
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

NAME="${NAME:-widgets.errors_notification}"
THRESHOLD="${ORPHAN_THRESHOLD:-70}"
# A zombie costs only a pid slot, so badge a parent only once it leaks (count) or clearly hangs (age).
ZOMBIE_THRESHOLD="${ZOMBIE_THRESHOLD:-3}"
ZOMBIE_MIN_AGE="${ZOMBIE_MIN_AGE:-600}"
SAMPLE_SECS=2
TREEHOUSE="$HOME/.treehouse"
LOOKBACK_MIN=30
# cwd lookup is gated to nvim + dev-commands + high-CPU so idle launchd agents aren't lsof-probed.
DEV_RE='^(node|claude|python[0-9.]*|zsh|bash|sh|git|tsx|esbuild|deno|bun|ruby|go|cargo|rustc|make|npm|pnpm|yarn)$'

STATE_DIR="$HOME/.local/state/errors"
LOG_DIR="$HOME/.logs/errors"
mkdir -p "$STATE_DIR" "$LOG_DIR"

# Single-flight lock (mkdir atomic; reclaim stale >30s). No flock on macOS.
LOCK="$STATE_DIR/lock.d"
if ! mkdir "$LOCK" 2>/dev/null; then
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +0.5 2>/dev/null)" ] || exit 0
  rmdir "$LOCK" 2>/dev/null && mkdir "$LOCK" 2>/dev/null || exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

CURRENT="$STATE_DIR/current"   # popup state: "error|<src>" or "<cat>|pid|pc|comm|cwd"
ORPH="$STATE_DIR/orphans"      # orphan rows carried across runs (hysteresis)
MISSES="$STATE_DIR/misses"
LOG="$LOG_DIR/errors_$(date '+%Y%m').log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >>"$LOG"; }
dry() { [[ -n "$ERRORS_DRYRUN" ]]; }

proc_cwd() {
  if [[ -r /proc/$1/cwd ]]; then readlink "/proc/$1/cwd" 2>/dev/null
  else lsof -a -d cwd -p "$1" -Fn 2>/dev/null | awk '/^n/{print substr($0,2);exit}'; fi
}
etime_secs() { # ps etime "[[DD-]HH:]MM:SS" -> seconds
  local e="$1" d=0 rest h=0 m=0 s=0 parts
  if [[ "$e" == *-* ]]; then d=${e%%-*}; rest=${e#*-}; else rest="$e"; fi
  local IFS=:; read -ra parts <<<"$rest"; unset IFS
  case ${#parts[@]} in
    3) h=${parts[0]} m=${parts[1]} s=${parts[2]} ;;
    2) m=${parts[0]} s=${parts[1]} ;;
    *) s=${parts[0]:-0} ;;
  esac
  echo $((10#$d * 86400 + 10#$h * 3600 + 10#$m * 60 + 10#$s))
}
hms() { # seconds -> coarsest single unit
  local s=$1
  if ((s >= 86400)); then echo "$((s / 86400))d"
  elif ((s >= 3600)); then echo "$((s / 3600))h"
  elif ((s >= 60)); then echo "$((s / 60))m"
  else echo "${s}s"; fi
}

declare -A t0
while read -r pid s; do t0[$pid]=$s; done < <(
  ps -axo pid=,time= | awk '{n=split($2,a,":");s=0;for(i=1;i<=n;i++)s=s*60+a[i];print $1,s}')
sleep "$SAMPLE_SECS"
declare -A ppid stat comm cput etimes
while IFS='|' read -r pid pp st s et cmd; do
  ppid[$pid]=$pp; stat[$pid]=$st; cput[$pid]=$s; etimes[$pid]=$et; comm[$pid]=$cmd
done < <(ps -axo pid=,ppid=,stat=,time=,etime=,command= |
  awk '{pid=$1;pp=$2;st=$3;n=split($4,a,":");s=0;for(i=1;i<=n;i++)s=s*60+a[i];et=$5;$1=$2=$3=$4=$5="";sub(/^ +/,"");print pid"|"pp"|"st"|"s"|"et"|"$0}')

orphans=(); declare -A z_count z_age
for pid in "${!cput[@]}"; do
  st=${stat[$pid]}
  if [[ "$st" == *Z* ]]; then
    pp=${ppid[$pid]}
    z_count[$pp]=$((${z_count[$pp]:-0} + 1))
    age=$(etime_secs "${etimes[$pid]}")
    ((age > ${z_age[$pp]:-0})) && z_age[$pp]=$age
    continue
  fi
  [[ "${ppid[$pid]}" == 1 ]] || continue
  cmd=${comm[$pid]}
  [[ "$cmd" == *.app/Contents/MacOS/* ]] && continue
  case "$cmd" in /System/* | /usr/libexec/* | /usr/sbin/* | /Library/Apple/*) continue ;; esac
  prev=${t0[$pid]}
  if [[ -n "$prev" ]]; then
    percore=$(awk -v a="${cput[$pid]}" -v b="$prev" -v s="$SAMPLE_SECS" 'BEGIN{printf "%.0f",((a-b)/s)*100}')
  else percore=0; fi
  exe=${cmd%% *}; base=${exe##*/}
  cat=""; cwd=""
  if [[ "$base" == nvim ]]; then
    cat=fff
  elif [[ "$base" =~ $DEV_RE ]]; then
    cwd=$(proc_cwd "$pid")
    if [[ "$cwd" == "$TREEHOUSE"/* ]]; then cat=treehouse
    elif ((percore >= THRESHOLD)); then cat=cpu; fi
  elif ((percore >= THRESHOLD)); then
    cat=cpu
  fi
  [[ -z "$cat" ]] && continue
  [[ -z "$cwd" ]] && cwd=$(proc_cwd "$pid")
  orphans+=("$cat|$pid|$percore|$base|${cwd:-n/a}")
done

# Sticky-clear: keep a detected orphan active for 2 misses so a CPU dip cannot flicker the badge / re-banner.
declare -A prev_line prev_miss detected
[[ -f "$ORPH" ]] && while IFS='|' read -r ct p pc cm cw; do
  [[ -n "$p" ]] && prev_line[$p]="$ct|$p|$pc|$cm|$cw"
done <"$ORPH"
[[ -f "$MISSES" ]] && while read -r p m; do prev_miss[$p]=$m; done <"$MISSES"
for r in "${orphans[@]}"; do IFS='|' read -r _ p _ <<<"$r"; detected[$p]="$r"; done

orphan_rows=(); new=()
: >"$ORPH"; : >"$MISSES"
for pid in "${!detected[@]}"; do
  r=${detected[$pid]}
  echo "$r" >>"$ORPH"; echo "$pid 0" >>"$MISSES"
  orphan_rows+=("$r"); log "ORPHAN $r"
  [[ -z "${prev_line[$pid]}" ]] && new+=("$r")
done
for pid in "${!prev_line[@]}"; do
  [[ -n "${detected[$pid]}" ]] && continue
  m=$((${prev_miss[$pid]:-0} + 1)); ((m >= 2)) && continue
  kill -0 "$pid" 2>/dev/null || continue
  echo "${prev_line[$pid]}" >>"$ORPH"; echo "$pid $m" >>"$MISSES"
  orphan_rows+=("${prev_line[$pid]}")
done

# Zombies group by parent: the leaking parent is the actionable unit, the individual <defunct> pid is not.
zombie_rows=()
for pp in "${!z_count[@]}"; do
  n=${z_count[$pp]}; age=${z_age[$pp]:-0}
  ((n >= ZOMBIE_THRESHOLD || age >= ZOMBIE_MIN_AGE)) || continue
  # ps comm= keeps names with spaces intact ("Raycast Helper (Extensions)"); splitting the argv would truncate them.
  pname=$(ps -o comm= -p "$pp" 2>/dev/null); pname=${pname##*/}
  zombie_rows+=("zombie|$pp|$n|${pname:-gone}|$(hms "$age")")
  log "ZOMBIE parent=$pp comm=${pname:-gone} count=$n oldest=${age}s"
done

CUTOFF=$(date -v-${LOOKBACK_MIN}M '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d "-${LOOKBACK_MIN} min" '+%Y-%m-%d %H:%M:%S')
MONTH=$(date '+%Y%m')
error_sources=()
scan_log() { # file source
  local file="$1" src="$2" line ts
  [ -f "$file" ] || return
  while IFS= read -r line; do
    ts=$(echo "$line" | grep -oE '^\[?[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]?' | tr -d '[]')
    [ -z "$ts" ] && continue
    if [[ "$ts" > "$CUTOFF" || "$ts" == "$CUTOFF" ]]; then error_sources+=("$src"); return; fi
  done < <(grep -E '\[ERROR\]|ERROR:|FATAL|FAIL[^_]' "$file" 2>/dev/null |
    grep -iv 'KEEP:.*error.log\|NOTIFY.*Error\|already focused\|non-zero\|socket read timeout')
}
for dir in "$HOME/.logs"/*/; do
  d=$(basename "$dir")
  [[ "$d" == errors || "$d" == health-check ]] && continue
  for f in "$dir"*"$MONTH"*.log; do scan_log "$f" "$d"; done
done
if ((${#error_sources[@]})); then
  IFS=$'\n' error_sources=($(printf '%s\n' "${error_sources[@]}" | sort -u)); unset IFS
fi

: >"$CURRENT"
for s in "${error_sources[@]}"; do echo "error|$s" >>"$CURRENT"; done
for r in "${orphan_rows[@]}"; do echo "$r" >>"$CURRENT"; done
for r in "${zombie_rows[@]}"; do echo "$r" >>"$CURRENT"; done
err_n=${#error_sources[@]}; orph_n=${#orphan_rows[@]}; zomb_n=${#zombie_rows[@]}
count=$((err_n + orph_n + zomb_n))

if dry; then
  echo "errors=$err_n  orphans=$orph_n  zombie-parents=$zomb_n (of ${#z_count[@]} with any)"
  cat "$CURRENT"
  exit 0
fi

for r in "${new[@]}"; do
  IFS='|' read -r ct pid pc short cwd <<<"$r"
  [[ "$ct" == cpu ]] || continue
  mac-notify -t "⚠️ Orphan process" \
    -m "$short (pid $pid) — ${pc}% of a core, orphaned (ppid 1) · $cwd" \
    -g "orphan-$pid" -s Basso -T 0 --sender com.gnohj.orphan-alert \
    -e "$HOME/.config/sketchybar/items/widgets/errors-click.sh" 2>/dev/null || true
done

if command -v sketchybar >/dev/null 2>&1; then
  source "$HOME/.config/sketchybar/config/colors.sh" 2>/dev/null
  if ((count > 0)); then
    sketchybar --set "$NAME" icon.color="${RED:-0xffed8796}" label="$count" label.color="${RED:-0xffed8796}"
  else
    sketchybar --set "$NAME" icon.color="${GREEN:-0xffa6da95}" label="􀆅" label.color="${GREEN:-0xffa6da95}"
  fi
fi
