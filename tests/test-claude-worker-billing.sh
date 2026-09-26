#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT
mkdir -p "$test_home/bin" "$test_home/firstmate/config" "$test_home/.claude-work"
printf '#!/usr/bin/env bash\n[ "$1" = which ] && echo "$HOME/bin/fake-claude"\n' >"$test_home/bin/mise"
printf '#!/usr/bin/env bash\ncase "$1" in\n  pin) <"$HOME/pin" tr -d "\\n" ;;\n  token) [ "${FM_TEST_TOKEN_MISSING:-}" = 1 ] || { acct="${CLAUDE_ACCOUNT:-$(tr -d "\\n" <"$HOME/pin")}"; printf "test-%%s-token" "$acct"; } ;;\n  resolve) printf "%%s" "${CLAUDE_ACCOUNT:-$(tr -d "\\n" <"$HOME/pin")}" ;;\n  dir) [ "${CLAUDE_ACCOUNT:-$(tr -d "\\n" <"$HOME/pin")}" = work ] && echo "$HOME/.claude-work" || true ;;\nesac\n' >"$test_home/bin/claude-account"
printf '#!/usr/bin/env bash\nprintf "%%s|%%s|%%s\\n" "${CLAUDE_CONFIG_DIR:-ordinary}" "${CLAUDE_ACCOUNT:-none}" "${CLAUDE_CODE_OAUTH_TOKEN:-none}"\n' >"$test_home/bin/fake-claude"
chmod +x "$test_home/bin/"*
export HOME="$test_home" FM_HOME="$test_home/firstmate" FM_TASK_ID=test PATH="$test_home/bin:$PATH"
wrapper="$source_dir/dot_local/bin/executable_claude"
run() { env -u CLAUDE_CONFIG_DIR -u CLAUDE_ACCOUNT -u CLAUDE_CODE_OAUTH_TOKEN bash "$wrapper"; }
refuse() {
  if "$@" >"$HOME/refusal-out" 2>"$HOME/refusal-error"; then
    echo 'a mismatched state/token combination started Claude' >&2
    exit 1
  fi
  [ ! -s "$HOME/refusal-out" ]
  rg -q 'state store does not match|no OAuth token|not a known account' "$HOME/refusal-error"
}

printf 'work\n' >"$HOME/pin"
[ "$(run)" = "$HOME/.claude-work|work|test-work-token" ]
printf 'ordinary\n' >"$FM_HOME/config/claude-account"
refuse run
printf 'personal\n' >"$HOME/pin"
[ "$(run)" = 'ordinary|personal|test-personal-token' ]
printf '%s\n' "$HOME/.claude-work" >"$FM_HOME/config/claude-account"
refuse run
rm "$FM_HOME/config/claude-account"
[ "$(env -u CLAUDE_ACCOUNT -u CLAUDE_CONFIG_DIR CLAUDE_CODE_OAUTH_TOKEN=test-work-token bash "$wrapper")" = "$HOME/.claude-work|work|test-work-token" ]
printf 'work\n' >"$HOME/pin"
refuse env -u CLAUDE_ACCOUNT -u CLAUDE_CODE_OAUTH_TOKEN CLAUDE_CONFIG_DIR="$HOME/.claude" bash "$wrapper"
[ "$(env -u CLAUDE_CODE_OAUTH_TOKEN CLAUDE_ACCOUNT=personal bash "$wrapper")" = 'ordinary|personal|test-personal-token' ]
refuse env -u CLAUDE_CONFIG_DIR -u CLAUDE_ACCOUNT -u CLAUDE_CODE_OAUTH_TOKEN FM_TEST_TOKEN_MISSING=1 bash "$wrapper"
refuse env -u CLAUDE_CONFIG_DIR -u CLAUDE_ACCOUNT CLAUDE_CODE_OAUTH_TOKEN=unrecognized bash "$wrapper"
echo 'worker state and billing tests passed'
