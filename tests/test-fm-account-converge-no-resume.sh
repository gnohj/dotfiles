#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT
mkdir -p "$test_home/bin" "$test_home/fm/state" "$test_home/root/bin" "$test_home/.local/bin"
printf 'kind=secondmate\nherdr_pane_id=test-pane\n' >"$test_home/fm/state/sm-test.meta"
printf '#!/usr/bin/env bash\ncase "$1" in pin) echo work ;; token) echo work-token ;; dir) echo "$HOME/.claude-work" ;; esac\n' >"$test_home/bin/claude-account"
printf '#!/usr/bin/env bash\n[ "$*" = "pane process-info --pane test-pane" ] && echo '\''{"result":{"process_info":{"foreground_processes":[{"argv0":"claude","pid":12345}]}}}'\''\n' >"$test_home/bin/herdr"
printf '#!/usr/bin/env bash\necho Darwin\n' >"$test_home/bin/uname"
printf '#!/usr/bin/env bash\ncat "$HOME/proc-env"\n' >"$test_home/bin/ps"
printf '#!/usr/bin/env bash\ntouch "$HOME/restarted"\n' >"$test_home/root/bin/fm-secondmate-restart.sh"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >"$HOME/delegated"\n' >"$test_home/.local/bin/fm-fleet-converge"
chmod +x "$test_home/bin/"* "$test_home/root/bin/fm-secondmate-restart.sh" "$test_home/.local/bin/fm-fleet-converge"
export HOME="$test_home" FM_HOME="$test_home/fm" FIRSTMATE_DIR="$test_home/root" PATH="$test_home/bin:$PATH"
script="$source_dir/dot_local/bin/executable_fm-account-converge"

echo "claude CLAUDE_CODE_OAUTH_TOKEN=personal-token" >"$HOME/proc-env"
output=$(bash "$script" check)
[[ "$output" == *'would restart: sm-test'* ]]
[[ "$output" == *'resumes the mate'* ]]

echo "claude CLAUDE_CODE_OAUTH_TOKEN=work-token" >"$HOME/proc-env"
output=$(bash "$script" check)
[[ "$output" == *'reads another state store'* ]] || { echo "store drift was not detected: $output" >&2; exit 1; }

echo "claude CLAUDE_CODE_OAUTH_TOKEN=work-token CLAUDE_CONFIG_DIR=$HOME/.claude-work" >"$HOME/proc-env"
output=$(bash "$script" check)
[[ "$output" == *'already on'*'paired store'* ]] || { echo "a paired mate was reported as drift: $output" >&2; exit 1; }

echo "claude" >"$HOME/proc-env"
output=$(bash "$script" apply)
[[ "$output" == *'bypasses the claude wrapper'* ]]
[ ! -e "$HOME/delegated" ] || { echo 'a mate without the wrapper was sent for relaunch' >&2; exit 1; }

echo "claude CLAUDE_CODE_OAUTH_TOKEN=personal-token" >"$HOME/proc-env"
bash "$script" apply
[ "$(cat "$HOME/delegated")" = 'secondmate-account apply' ] || { echo 'apply did not delegate to the exact-resume path' >&2; exit 1; }
[ ! -e "$HOME/restarted" ] || { echo 'account convergence restarted a mate outside the exact-resume path' >&2; exit 1; }
echo 'Claude account convergence tests passed'
