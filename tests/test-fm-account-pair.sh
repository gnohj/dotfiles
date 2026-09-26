#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT
mkdir -p "$test_home/Developer/firstmate/.git" "$test_home/.local/bin" "$test_home/bin"
printf '#!/usr/bin/env bash\nprintf "%%s|%%s\\n" "$CLAUDE_ACCOUNT" "${CLAUDE_CONFIG_DIR:-ordinary}"\n' >"$test_home/.local/bin/claude"
printf '#!/usr/bin/env bash\n[ "$1" = resolve ] && echo work\n' >"$test_home/bin/claude-account"
printf '#!/usr/bin/env bash\nprintf focused >"$HOME/focus"\nexit 0\n' >"$test_home/.local/bin/fm-goto"
chmod +x "$test_home/.local/bin/"* "$test_home/bin/"*
export HOME="$test_home" PATH="$test_home/bin:$PATH"
fm="$source_dir/dot_local/bin/executable_fm"
if bash "$fm" --claude --token=work --state=personal >"$HOME/output" 2>"$HOME/error"; then
  echo 'fm allowed mismatched account and state' >&2; exit 1
fi
[ ! -e "$HOME/focus" ] || { echo 'fm focused fleet before refusing mismatch' >&2; exit 1; }
rg -q 'must match' "$HOME/error"
rm "$HOME/.local/bin/fm-goto"
[ "$(env -u CLAUDE_CONFIG_DIR -u CLAUDE_ACCOUNT bash "$fm" --claude)" = "work|$HOME/.claude-work" ]
[ "$(env -u CLAUDE_CONFIG_DIR -u CLAUDE_ACCOUNT bash "$fm" --claude --token=personal)" = 'personal|ordinary' ]
[ "$(env -u CLAUDE_CONFIG_DIR -u CLAUDE_ACCOUNT bash "$fm" --claude --state=personal --token=personal)" = 'personal|ordinary' ]
echo 'fm account and state tests passed'
