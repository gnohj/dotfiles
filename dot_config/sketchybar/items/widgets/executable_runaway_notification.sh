#!/bin/bash
# Runaway-process monitor -> sketchybar badge + one-time banner + log: a "runaway" is a high-CPU process (per-core % > THRESHOLD, btop's per-core cputime-delta method, sampled ~2s apart) that escaped its tmux pane (no pane ancestor) and isn't a GUI .app or system daemon - the stranded `claude --resume` node pattern; zombies (state Z) use no CPU so are counted/logged separately.
# Env: RUNAWAY_DRYRUN=1 prints findings and skips the UI; RUNAWAY_THRESHOLD sets the per-core %% cutoff (default 70).
shopt -s nullglob
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

NAME="${NAME:-widgets.runaway_notification}"
THRESHOLD="${RUNAWAY_THRESHOLD:-70}"
SAMPLE_SECS=2

STATE_DIR="$HOME/.local/state/runaway"
LOG_DIR="$HOME/.logs/runaway"
mkdir -p "$STATE_DIR" "$LOG_DIR"

# Single-flight lock: sketchybar fires this on update_freq AND on events (can overlap); mkdir is atomic (no flock on macOS) and a stale lock >30s is reclaimed so a crashed run can't wedge the monitor.
LOCK="$STATE_DIR/lock.d"
if ! mkdir "$LOCK" 2>/dev/null; then
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +0.5 2>/dev/null)" ] || exit 0
  rmdir "$LOCK" 2>/dev/null && mkdir "$LOCK" 2>/dev/null || exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

CURRENT="$STATE_DIR/current"
MISSES="$STATE_DIR/misses"
LOG="$LOG_DIR/runaway_$(date '+%Y%m').log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >>"$LOG"; }
dry() { [[ -n "$RUNAWAY_DRYRUN" ]]; }

# cputime "MM:SS.cc" / "HH:MM:SS" -> seconds, done in one awk pass over all procs.
declare -A t0
while read -r pid s; do t0[$pid]=$s; done < <(
  ps -axo pid=,time= | awk '{n=split($2,a,":");s=0;for(i=1;i<=n;i++)s=s*60+a[i];print $1,s}'
)
sleep "$SAMPLE_SECS"

declare -A ppid stat comm cput
while IFS='|' read -r pid pp st s cmd; do
  ppid[$pid]=$pp; stat[$pid]=$st; cput[$pid]=$s; comm[$pid]=$cmd
done < <(
  ps -axo pid=,ppid=,stat=,time=,command= |
    awk '{pid=$1;pp=$2;st=$3;n=split($4,a,":");s=0;for(i=1;i<=n;i++)s=s*60+a[i];
          $1=$2=$3=$4="";sub(/^ +/,"");print pid"|"pp"|"st"|"s"|"$0}'
)

# tmux pane shell PIDs — a process is pane-owned if any ancestor is one of these.
declare -A pane
while read -r pp; do [[ -n "$pp" ]] && pane[$pp]=1; done < <(
  tmux list-panes -a -F '#{pane_pid}' 2>/dev/null
)
under_pane() {
  local p=$1
  while [[ -n "$p" && "$p" != 0 && "$p" != 1 ]]; do
    [[ -n "${pane[$p]}" ]] && return 0
    p=${ppid[$p]}
  done
  return 1
}

runaways=()
zombies=0
for pid in "${!cput[@]}"; do
  st=${stat[$pid]}
  if [[ "$st" == *Z* ]]; then
    zombies=$((zombies + 1))
    log "ZOMBIE pid=$pid ppid=${ppid[$pid]} comm=${comm[$pid]}"
    continue
  fi
  prev=${t0[$pid]}
  [[ -z "$prev" ]] && continue
  percore=$(awk -v a="${cput[$pid]}" -v b="$prev" -v s="$SAMPLE_SECS" \
    'BEGIN{printf "%.0f",((a-b)/s)*100}')
  ((percore < THRESHOLD)) && continue
  cmd=${comm[$pid]}
  [[ "$cmd" == *.app/Contents/MacOS/* ]] && continue
  case "$cmd" in /System/* | /usr/libexec/* | /usr/sbin/* | /Library/Apple/*) continue ;; esac
  under_pane "$pid" && continue
  cwd=$(lsof -a -d cwd -p "$pid" -Fn 2>/dev/null | awk '/^n/{print substr($0,2);exit}')
  short=${cmd%% *}; short=${short##*/}
  runaways+=("$pid|$percore|$short|${cwd:--}")
done

# Sticky-clear: keep a runaway "active" for up to 2 further misses so a single-sample CPU dip can't flicker the badge off or re-fire the banner; new pids badge+banner immediately, a pid that fully clears and later returns re-banners.
declare -A prev_line prev_miss detected
[[ -f "$CURRENT" ]] && while IFS='|' read -r p pc cm cw; do
  [[ -n "$p" ]] && prev_line[$p]="$p|$pc|$cm|$cw"
done <"$CURRENT"
[[ -f "$MISSES" ]] && while read -r p m; do prev_miss[$p]=$m; done <"$MISSES"
for r in "${runaways[@]}"; do detected[${r%%|*}]="$r"; done

: >"$CURRENT"; : >"$MISSES"
new=(); count=0
for pid in "${!detected[@]}"; do
  r=${detected[$pid]}
  echo "$r" >>"$CURRENT"; echo "$pid 0" >>"$MISSES"
  count=$((count + 1)); log "RUNAWAY $r"
  [[ -z "${prev_line[$pid]}" ]] && new+=("$r")
done
for pid in "${!prev_line[@]}"; do
  [[ -n "${detected[$pid]}" ]] && continue
  m=$((${prev_miss[$pid]:-0} + 1))
  ((m >= 2)) && continue
  kill -0 "$pid" 2>/dev/null || continue
  echo "${prev_line[$pid]}" >>"$CURRENT"; echo "$pid $m" >>"$MISSES"
  count=$((count + 1))
done

if dry; then
  echo "threshold=${THRESHOLD}%  runaways=$count  zombies=$zombies"
  printf '%s\n' "${runaways[@]}"
  exit 0
fi

for r in "${new[@]}"; do
  IFS='|' read -r pid pc short cwd <<<"$r"
  mac-notify -t "⚠️ Runaway process" \
    -m "$short (pid $pid) — ${pc}% of a core, no tmux pane · $cwd" \
    -g "runaway-$pid" -s Basso -T "${RUNAWAY_BANNER_SECS:-60}" \
    -e "$HOME/.config/sketchybar/items/widgets/runaway-click.sh" 2>/dev/null || true
done

source "$HOME/.config/sketchybar/config/colors.sh" 2>/dev/null
if ((count > 0)); then
  sketchybar --set "$NAME" drawing=on label="$count" label.color="${RED:-0xffed8796}" \
    icon.color="${RED:-0xffed8796}"
else
  sketchybar --set "$NAME" drawing=off
fi
