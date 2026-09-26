#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT
fm="$test_home/fm"
crew_home="$test_home/sm-local"
mkdir -p "$test_home/bin" "$fm/state" "$fm/data" "$crew_home/state" "$test_home/root/bin" "$test_home/wt" "$test_home/remote-home/state"
printf '222\n' >"$test_home/remote-home/state/.lock"
log="$test_home/calls"

printf 'kind=secondmate\nharness=claude\nhome=%s\n' "$crew_home" >"$fm/state/sm-local.meta"
printf 'kind=secondmate\nharness=claude\nhome=%s\nworktree=%s\n' "$test_home/remote-home" "$test_home/remote-home" >"$fm/state/sm-remote.meta"
printf 'kind=ship\nharness=claude\nworktree=%s\n' "$test_home/wt" >"$crew_home/state/task-a.meta"
printf -- '- sm-remote - Remote lab mate. (host: lab-host; root: /remote/fm; home: %s; scope: tests)\n- sm-local - Local lab mate. (home: %s; scope: tests)\n' "$test_home/remote-home" "$crew_home" >"$fm/data/secondmates.md"

printf '#!/usr/bin/env bash\ncase "$1" in pin) echo work ;; *) ;; esac\n' >"$test_home/bin/claude-account"
cat >"$test_home/bin/claude-session-migrate" <<'EOF'
#!/usr/bin/env bash
echo "migrate $*" >>"$CALLS"
case "$1" in
sessions) [ -n "${LIVE_SESSIONS:-}" ] && printf '%b' "$LIVE_SESSIONS" ;;
settle) exit "${SETTLE_EXIT:-0}" ;;
esac
exit 0
EOF
cat >"$test_home/bin/ssh" <<'EOF'
#!/usr/bin/env bash
[ -z "${SSH_DOWN:-}" ] || exit 255
while [ "$1" = -o ]; do shift 2; done
host=$1
shift
echo "ssh $host $*" >>"$CALLS"
eval "set -- $*"
case "$1" in */claude-session-migrate) shift; exec claude-session-migrate "$@" ;; esac
exec "$@"
EOF
printf '#!/usr/bin/env bash\necho "control $FM_HOME $*" >>"$CALLS"\necho "${CLAUDE_CONFIG_DIR:-unset}" >"$HOME/control-store"\n' >"$test_home/root/bin/fm-control.sh"
printf '#!/usr/bin/env bash\necho "restart $*" >>"$CALLS"\n' >"$test_home/root/bin/fm-secondmate-restart.sh"
printf '#!/usr/bin/env bash\necho "send $1" >>"$CALLS"\n' >"$test_home/root/bin/fm-send.sh"
chmod +x "$test_home/bin/"* "$test_home/root/bin/"*
export FM_CONVERGE_LOCK_TRIES=3 FM_CONVERGE_LOCK_POLL=0 HOME="$test_home" FM_HOME="$fm" FIRSTMATE_DIR="$test_home/root" PATH="$test_home/bin:$PATH" CALLS="$log"
converge="$source_dir/dot_local/bin/executable_fm-fleet-converge"
fail() { echo "FAIL: $*" >&2; exit 1; }
calls() { cat "$log" 2>/dev/null; }
reset() { rm -f "$log"; }

reset
LIVE_SESSIONS="ordinary\t111\tsid-a\n" bash "$converge" mate-account task-a work apply >/dev/null
expected="migrate sessions $test_home/wt
migrate prepare $test_home/wt
control $crew_home task-a relaunch --note Relaunched to move onto the work account. If this conversation continues above, keep going from where it stopped; otherwise re-read the brief and the local copy before continuing.
migrate settle $test_home/wt"
[ "$(calls)" = "$expected" ] || fail "crew exact relaunch order: $(calls)"

reset
LIVE_SESSIONS="ordinary\t222\tsid-r\n" bash "$converge" mate-account sm-remote work apply >/dev/null
[ "$(sed -n 1p "$log")" = "ssh lab-host .local/bin/claude-session-migrate sessions $test_home/remote-home " ] || fail "remote sessions: $(calls)"
[ "$(grep -v '^ssh ' "$log" | tr '\n' '|')" = "migrate sessions $test_home/remote-home|migrate prepare $test_home/remote-home|restart sm-remote|migrate settle $test_home/remote-home|migrate sessions $test_home/remote-home|" ] ||
  fail "remote exact relaunch order: $(calls)"

reset
printf '999\n' >"$test_home/remote-home/state/.lock"
if LIVE_SESSIONS="ordinary\t222\tsid-r\n" FM_CONVERGE_LOCK_TRIES=3 FM_CONVERGE_LOCK_POLL=0 bash "$converge" secondmate-resume sm-remote apply >/dev/null 2>&1; then
  fail 'a resumed mate that never re-took its lock reported success'
fi
grep -qx 'send sm-remote' "$log" || fail "the stale lock was not nudged: $(calls)"
printf '222\n' >"$test_home/remote-home/state/.lock"
reset
LIVE_SESSIONS="ordinary\t222\tsid-r\n" bash "$converge" secondmate-resume sm-remote apply | grep -q 'holds its home lock as pid 222' || fail 'secondmate-resume did not confirm the lock'
grep -q '^send' "$log" && fail 'a mate holding its lock was nudged'

reset
if LIVE_SESSIONS="ordinary\t1\ta\nordinary\t2\tb\n" bash "$converge" mate-account task-a work apply >/dev/null 2>&1; then fail 'two live sessions were relaunched'; fi
grep -q 'control' "$log" && fail "relaunched despite two live sessions: $(calls)"

reset
if SSH_DOWN=1 bash "$converge" mate-account sm-remote work apply >/dev/null 2>&1; then fail 'an unreachable host was relaunched'; fi
[ ! -s "$log" ] || fail "touched a mate on an unreachable host: $(calls)"

reset
if LIVE_SESSIONS="ordinary\t111\tsid-a\n" SETTLE_EXIT=3 bash "$converge" mate-account task-a work apply >/dev/null 2>&1; then fail 'an unsettled relaunch reported success'; fi

reset
bash "$converge" mate-account task-a work apply >/dev/null
[ "$(calls | tr '\n' '|')" = "migrate sessions $test_home/wt|control $crew_home task-a relaunch --note Relaunched to move onto the work account. If this conversation continues above, keep going from where it stopped; otherwise re-read the brief and the local copy before continuing.|" ] ||
  fail "a mate with no live conversation was not relaunched plainly: $(calls)"

reset
CLAUDE_CONFIG_DIR=/elsewhere LIVE_SESSIONS="ordinary\t111\tsid-a\n" bash "$converge" mate-account task-a work apply >/dev/null
grep -q '^control' "$log" || fail 'relaunch did not run'
[ "$(cat "$HOME/control-store")" = unset ] || fail 'the caller store was forwarded onto the relaunch'
echo 'fm fleet converge exact-resume tests passed'
