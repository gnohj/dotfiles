#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT
mkdir -p "$test_home/bin" "$test_home/firstmate/config" "$test_home/.claude-work"
printf '#!/usr/bin/env bash\n[ "$1" = which ] && echo "$HOME/bin/fake-claude"\n' >"$test_home/bin/mise"
printf '#!/usr/bin/env bash\ncase "$1" in\n  pin) <"$HOME/pin" tr -d "\\n" ;;\n  token) [ "${FM_TEST_TOKEN_MISSING:-}" = 1 ] || { acct="${CLAUDE_ACCOUNT:-$(tr -d "\\n" <"$HOME/pin")}"; printf "test-%%s-token" "$acct"; } ;;\n  resolve) <"$HOME/pin" tr -d "\\n" ;;\n  dir) [ "${CLAUDE_ACCOUNT:-$(tr -d "\\n" <"$HOME/pin")}" = work ] && echo "$HOME/.claude-work" || true ;;\nesac\n' >"$test_home/bin/claude-account"
printf '#!/usr/bin/env bash\nprintf "%%s|%%s|%%s\\n" "${CLAUDE_CONFIG_DIR:-ordinary}" "${CLAUDE_ACCOUNT:-none}" "${CLAUDE_CODE_OAUTH_TOKEN:-none}"\n' >"$test_home/bin/fake-claude"
chmod +x "$test_home/bin/"*
export HOME="$test_home" FM_HOME="$test_home/firstmate" FM_TASK_ID=test PATH="$test_home/bin:$PATH"
printf 'work\n' >"$HOME/pin"
printf 'ordinary\n' >"$FM_HOME/config/claude-account"
output=$(env -u CLAUDE_CONFIG_DIR -u CLAUDE_ACCOUNT -u CLAUDE_CODE_OAUTH_TOKEN bash "$source_dir/dot_local/bin/executable_claude")
[ "$output" = 'ordinary|work|test-work-token' ]
printf 'personal\n' >"$HOME/pin"
printf '%s\n' "$HOME/.claude-work" >"$FM_HOME/config/claude-account"
output=$(env -u CLAUDE_CONFIG_DIR -u CLAUDE_ACCOUNT -u CLAUDE_CODE_OAUTH_TOKEN bash "$source_dir/dot_local/bin/executable_claude")
[ "$output" = "$HOME/.claude-work|personal|test-personal-token" ]
output=$(env -u CLAUDE_CODE_OAUTH_TOKEN CLAUDE_ACCOUNT=work bash "$source_dir/dot_local/bin/executable_claude")
[ "$output" = "$HOME/.claude-work|work|test-work-token" ]
printf 'ordinary\n' >"$FM_HOME/config/claude-account"
output=$(env -u CLAUDE_CODE_OAUTH_TOKEN -u CLAUDE_ACCOUNT CLAUDE_CONFIG_DIR="$HOME/.claude-work" bash "$source_dir/dot_local/bin/executable_claude")
[ "$output" = 'ordinary|personal|test-personal-token' ]
if env -u CLAUDE_CONFIG_DIR -u CLAUDE_ACCOUNT -u CLAUDE_CODE_OAUTH_TOKEN FM_TEST_TOKEN_MISSING=1 bash "$source_dir/dot_local/bin/executable_claude" >"$HOME/missing-out" 2>"$HOME/missing-error"; then
  echo 'worker started without a billing token' >&2
  exit 1
fi
[ ! -s "$HOME/missing-out" ]
rg -q "refusing to use the state store's credential" "$HOME/missing-error"
mkdir -p "$HOME/.local/state/claude"
printf 'test-work-token\n' >"$HOME/.local/state/claude/oauth-work"
CLAUDE_ACCOUNT=work bash "$source_dir/dot_local/bin/executable_claude-account" seed-config --dir ordinary
[ -f "$HOME/.claude.json" ]
[ ! -f "$HOME/.claude-work/.claude.json" ]
CLAUDE_ACCOUNT=work bash "$source_dir/dot_local/bin/executable_claude-account" seed-config --dir "$HOME/.claude-work"
[ -f "$HOME/.claude-work/.claude.json" ]
echo 'worker state and billing tests passed'
