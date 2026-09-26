#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
test_home=$(mktemp -d)
test_home=$(cd "$test_home" && pwd -P)
pids=()
cleanup() {
  local p
  for p in ${pids[@]+"${pids[@]}"}; do kill "$p" 2>/dev/null || true; done
  rm -rf "$test_home"
}
trap cleanup EXIT

mkdir -p "$test_home/bin" "$test_home/.claude" "$test_home/.claude-work" "$test_home/.local/state/claude"
printf '#!/usr/bin/env bash\n[ "$1" = which ] && echo "$HOME/bin/fake-claude"\n' >"$test_home/bin/mise"
printf '#!/usr/bin/env bash\nexit 44\n' >"$test_home/bin/security"
printf '#!/usr/bin/env bash\nprintf "%%s|%%s|%%s|%%s\\n" "${CLAUDE_CONFIG_DIR:-ordinary}" "${CLAUDE_ACCOUNT:-none}" "${CLAUDE_CODE_OAUTH_TOKEN:-none}" "$*"\n' >"$test_home/bin/fake-claude"
cp "$source_dir/dot_local/bin/executable_claude-account" "$test_home/bin/claude-account"
cp "$source_dir/dot_local/bin/executable_claude-session-migrate" "$test_home/bin/claude-session-migrate"
chmod +x "$test_home/bin/"*
# macOS hides the environment of platform binaries from ps, so the stand-in session must be a non-platform one there.
if [ "$(uname)" = Darwin ]; then
  ln -s "$(command -v node)" "$test_home/bin/claude-sleeper"
  sleeper_args=(-e 'setTimeout(() => {}, 300000)')
else
  ln -s "$(command -v sleep)" "$test_home/bin/claude-sleeper"
  sleeper_args=(300)
fi
export HOME="$test_home" PATH="$test_home/bin:$PATH" CLAUDE_MIGRATE_WAIT=3
unset CLAUDE_ACCOUNT CLAUDE_CONFIG_DIR CLAUDE_CODE_OAUTH_TOKEN FM_TASK_ID FM_HOME
state="$HOME/.local/state/claude"
printf 'test-work-token' >"$state/oauth-work"
printf 'test-personal-token' >"$state/oauth-personal"
wrapper="$source_dir/dot_local/bin/executable_claude"
migrate=claude-session-migrate
native="$HOME/.claude"
work="$HOME/.claude-work"

fail() { echo "FAIL: $*" >&2; exit 1; }
expect() { [ "$1" = "$2" ] || fail "expected '$2', got '$1' ($3)"; }
refuses() { # <pattern> <command>...
  local pattern=$1
  shift
  if "$@" >"$HOME/out" 2>"$HOME/err"; then fail "'$*' should have refused"; fi
  rg -q "$pattern" "$HOME/err" || fail "'$*' refused without '$pattern': $(cat "$HOME/err")"
}
launch_in() { (cd "$1" && shift && env -u CLAUDE_CONFIG_DIR -u CLAUDE_ACCOUNT -u CLAUDE_CODE_OAUTH_TOKEN bash "$wrapper" "$@"); }
slug() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }

LIVE_PID=
live() { # <path> <store> <session-id> [env assignments...]
  local path=$1 store=$2 id=$3
  shift 3
  cd "$path"
  env "$@" "$HOME/bin/claude-sleeper" "${sleeper_args[@]}" &
  LIVE_PID=$!
  cd "$HOME"
  pids+=("$LIVE_PID")
  mkdir -p "$store/sessions"
  printf '{"pid":%s,"sessionId":"%s","cwd":"%s","kind":"interactive"}\n' "$LIVE_PID" "$id" "$path" >"$store/sessions/$LIVE_PID.json"
}
stop() { kill "$1" 2>/dev/null || true; wait "$1" 2>/dev/null || true; }

transcript_for() { printf '%s/projects/%s/%s.jsonl' "$1" "$(slug "$2")" "$3"; }
seed_session() { # <store> <path> <id>
  local t
  t=$(transcript_for "$1" "$2" "$3")
  mkdir -p "$(dirname "$t")" "$1/file-history/$3" "$1/session-env/$3" "${t%.jsonl}/subagents"
  printf '{"n":1,"text":"ALPHA"}\n{"n":2}\n' >"$t"
  printf 'edit\n' >"$1/file-history/$3/f@v1"
  printf 'sub\n' >"${t%.jsonl}/subagents/agent-1.jsonl"
}

# A legacy worktree: Work billing, native state, one live session.
wt="$HOME/wt"
mkdir -p "$wt"
id=11111111-2222-4333-8444-555555555555
claude-account path-pin "$wt" work >/dev/null
claude-account store-pin "$wt" ordinary >/dev/null
seed_session "$native" "$wt" "$id"
live "$wt" "$native" "$id"
refuses 'not started through the claude wrapper' $migrate prepare "$wt"
stop "$LIVE_PID"
live "$wt" "$native" "$id" CLAUDE_ACCOUNT=work CLAUDE_CODE_OAUTH_TOKEN=test-work-token
old=$LIVE_PID
expect "$($migrate sessions "$wt")" "ordinary$(printf '\t')$old$(printf '\t')$id" 'sessions lists the live one'

refuses 'state store does not match' launch_in "$wt"
refuses 'expected one live Claude session' $migrate prepare "$HOME"
refuses 'resolves to' $migrate prepare "$HOME/wt/../wt"

out=$($migrate prepare "$wt")
expect "$out" "prepared $wt session=$id pid=$old from=ordinary to=$work account=work" 'prepare names the move'
expect "$(stat -c %a "$state/resume-by-path" 2>/dev/null || stat -f %Lp "$state/resume-by-path")" 600 'markers are private'
refuses 'already has a pending migration' $migrate prepare "$wt"

refuses 'still runs as pid' launch_in "$wt"
[ ! -e "$(transcript_for "$work" "$wt" "$id")" ] || fail 'copied while the old session was alive'

elsewhere="$HOME/elsewhere"
mkdir -p "$elsewhere"
claude-account path-pin "$elsewhere" work >/dev/null
expect "$(launch_in "$elsewhere" --model x)" "$work|work|test-work-token|--model x" 'another path launches fresh'

stop "$old"
printf '{"n":3,"final":true}\n' >>"$(transcript_for "$native" "$wt" "$id")"
refuses 'conflicts with --resume' launch_in "$wt" --resume other
expect "$(launch_in "$wt" --model x brief)" "$work|work|test-work-token|--resume $id --system-prompt-snapshot off --model x brief" 'relaunch resumes the same id in the paired store'
cmp -s "$(transcript_for "$native" "$wt" "$id")" "$(transcript_for "$work" "$wt" "$id")" || fail 'the final transcript was not copied'
[ -f "$work/file-history/$id/f@v1" ] || fail 'file history was not copied'
[ -f "$(dirname "$(transcript_for "$work" "$wt" "$id")")/$id/subagents/agent-1.jsonl" ] || fail 'subagent transcripts were not copied'
[ -d "$work/session-env/$id" ] || fail 'session env was not copied'
expect "$(claude-account store-pin "$wt")" '' 'the legacy store pin is retired with the copy'
refuses 'already relaunched' $migrate cancel "$wt"

printf '{"n":4,"resumed":true}\n' >>"$(transcript_for "$work" "$wt" "$id")"
expect "$(launch_in "$wt" brief)" "$work|work|test-work-token|--resume $id --system-prompt-snapshot off brief" 'a retried relaunch still resumes'

refuses 'expected one live process' $migrate verify "$wt"
live "$wt" "$work" "$id" CLAUDE_CONFIG_DIR="$work" CLAUDE_ACCOUNT=work CLAUDE_CODE_OAUTH_TOKEN=test-personal-token
refuses 'does not carry the work token' $migrate verify "$wt"
stop "$LIVE_PID"
live "$wt" "$work" "$id" CLAUDE_ACCOUNT=work CLAUDE_CODE_OAUTH_TOKEN=test-work-token
refuses "reads store 'native'" $migrate verify "$wt"
stop "$LIVE_PID"
live "$wt" "$work" "$id" CLAUDE_CONFIG_DIR="$work" CLAUDE_ACCOUNT=work CLAUDE_CODE_OAUTH_TOKEN=test-work-token
good=$LIVE_PID
live "$wt" "$native" 99999999-2222-4333-8444-555555555555
refuses "expected only pid $good" $migrate verify "$wt"
stop "$LIVE_PID"
expect "$($migrate verify "$wt")" "verified $wt session=$id pid=$good store=$work account=work" 'verify proves token, store and one process'
expect "$($migrate status "$wt")" '' 'a verified migration leaves no marker'
stop "$good"
expect "$(launch_in "$wt" brief)" "$work|work|test-work-token|brief" 'after verification launches are ordinary again'

# A divergent conversation under the same id in the target store is never overwritten.
wt2="$HOME/wt2"
mkdir -p "$wt2"
id2=22222222-2222-4333-8444-555555555555
claude-account path-pin "$wt2" work >/dev/null
seed_session "$native" "$wt2" "$id2"
mkdir -p "$(dirname "$(transcript_for "$work" "$wt2" "$id2")")"
printf '{"n":1,"text":"OTHER"}\n' >"$(transcript_for "$work" "$wt2" "$id2")"
live "$wt2" "$native" "$id2" CLAUDE_ACCOUNT=work CLAUDE_CODE_OAUTH_TOKEN=test-work-token
refuses 'different conversation' $migrate prepare "$wt2"
expect "$($migrate status "$wt2")" '' 'a refused prepare leaves no marker'

# A relaunch command that never stops the old session leaves it untouched.
out=$($migrate run "$wt2" -- true 2>&1 || true)
case "$out" in *'different conversation'*) ;; *) fail "run did not refuse the collision: $out" ;; esac
rm "$(transcript_for "$work" "$wt2" "$id2")"
if out=$($migrate run "$wt2" -- true 2>&1); then fail "run claimed success without a relaunch: $out"; fi
case "$out" in *untouched*) ;; *) fail "run did not report untouched: $out" ;; esac
expect "$($migrate status "$wt2")" '' 'an untouched run drops its marker'
kill -0 "$LIVE_PID" || fail 'the old session was stopped'

# run drives the whole transaction when the relaunch command replaces the session.
old2=$LIVE_PID
relaunch="$HOME/bin/relaunch"
cat >"$relaunch" <<EOF
#!/usr/bin/env bash
kill $old2
sleep 0.2
out=\$(cd "$wt2" && env -u CLAUDE_CONFIG_DIR -u CLAUDE_ACCOUNT -u CLAUDE_CODE_OAUTH_TOKEN bash "$wrapper" brief) || exit 1
case "\$out" in *"--resume $id2 --system-prompt-snapshot off brief") ;; *) exit 1 ;; esac
cd "$wt2"
CLAUDE_CONFIG_DIR="$work" CLAUDE_ACCOUNT=work CLAUDE_CODE_OAUTH_TOKEN=test-work-token nohup "$HOME/bin/claude-sleeper" ${sleeper_args[*]@Q} >/dev/null 2>&1 &
printf '{"pid":%s,"sessionId":"$id2","cwd":"$wt2"}\n' "\$!" >"$work/sessions/\$!.json"
echo "\$!" >"$HOME/relaunched"
EOF
chmod +x "$relaunch"
out=$($migrate run "$wt2" -- "$relaunch")
pids+=("$(cat "$HOME/relaunched")")
case "$out" in *"verified $wt2 session=$id2 pid=$(cat "$HOME/relaunched") store=$work account=work"*) ;; *) fail "run did not verify: $out" ;; esac

# Rollback bills the original store's account and resumes there with the grown transcript.
wt3="$HOME/wt3"
mkdir -p "$wt3"
id3=33333333-2222-4333-8444-555555555555
claude-account path-pin "$wt3" work >/dev/null
seed_session "$native" "$wt3" "$id3"
live "$wt3" "$native" "$id3" CLAUDE_ACCOUNT=work CLAUDE_CODE_OAUTH_TOKEN=test-work-token
$migrate prepare "$wt3" >/dev/null
stop "$LIVE_PID"
launch_in "$wt3" brief >/dev/null
printf '{"n":3,"on":"work"}\n' >>"$(transcript_for "$work" "$wt3" "$id3")"
live "$wt3" "$work" "$id3"
refuses 'runs as pid' $migrate rollback "$wt3"
stop "$LIVE_PID"
expect "$($migrate rollback "$wt3")" "rolled back $wt3 session=$id3: it bills personal and its next launch resumes in ordinary (path pin was work)" 'rollback names the new pairing'
expect "$(launch_in "$wt3" brief)" "ordinary|personal|test-personal-token|--resume $id3 --system-prompt-snapshot off brief" 'rollback resumes in the original store'
cmp -s "$(transcript_for "$work" "$wt3" "$id3")" "$(transcript_for "$native" "$wt3" "$id3")" || fail 'rollback did not carry the grown transcript back'
ls "$state/migrations/$id3"/backup-*/projects/*/"$id3.jsonl" >/dev/null 2>&1 || fail 'rollback did not back up the displaced transcript'

# cancel only undoes a marker whose copy has not started.
wt4="$HOME/wt4"
mkdir -p "$wt4"
id4=44444444-2222-4333-8444-555555555555
claude-account path-pin "$wt4" work >/dev/null
seed_session "$native" "$wt4" "$id4"
live "$wt4" "$native" "$id4" CLAUDE_ACCOUNT=work CLAUDE_CODE_OAUTH_TOKEN=test-work-token
$migrate prepare "$wt4" >/dev/null
expect "$($migrate cancel "$wt4")" "cancelled $wt4 session=$id4" 'cancel before copy'
expect "$($migrate status "$wt4")" '' 'cancel drops the marker'

# Rollback while the old session still runs only drops the marker.
wt5="$HOME/wt5"
mkdir -p "$wt5"
id5=55555555-2222-4333-8444-555555555555
claude-account path-pin "$wt5" work >/dev/null
claude-account store-pin "$wt5" ordinary >/dev/null
seed_session "$native" "$wt5" "$id5"
live "$wt5" "$native" "$id5" CLAUDE_ACCOUNT=work CLAUDE_CODE_OAUTH_TOKEN=test-work-token
$migrate prepare "$wt5" >/dev/null
expect "$($migrate rollback "$wt5")" "rolled back $wt5 session=$id5; pid $LIVE_PID still runs and nothing had moved" 'rollback of a live prepare'
expect "$($migrate status "$wt5")" '' 'that rollback drops the marker'

# Rollback after the old session stopped but before any copy resumes in place, never fresh.
$migrate prepare "$wt5" >/dev/null
stop "$LIVE_PID"
expect "$($migrate rollback "$wt5")" "rolled back $wt5 session=$id5: it bills personal and its next launch resumes in ordinary (path pin was work)" 'rollback before the copy'
expect "$(launch_in "$wt5" brief)" "ordinary|personal|test-personal-token|--resume $id5 --system-prompt-snapshot off brief" 'the conversation resumes where it lives'
[ ! -e "$(transcript_for "$work" "$wt5" "$id5")" ] || fail 'an in-place rollback copied the transcript'

echo 'claude session migration tests passed'
