#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT
test_home=$(cd "$test_home" && pwd -P)
mkdir -p "$test_home/bin" "$test_home/.claude-work" "$test_home/.local/state/claude" "$test_home/mate/sub" "$test_home/other"
printf '#!/usr/bin/env bash\n[ "$1" = which ] && echo "$HOME/bin/fake-claude"\n' >"$test_home/bin/mise"
printf '#!/usr/bin/env bash\nexit 44\n' >"$test_home/bin/security"
printf '#!/usr/bin/env bash\nprintf "%%s|%%s|%%s\\n" "${CLAUDE_CONFIG_DIR:-ordinary}" "${CLAUDE_ACCOUNT:-none}" "${CLAUDE_CODE_OAUTH_TOKEN:-none}"\n' >"$test_home/bin/fake-claude"
cp "$source_dir/dot_local/bin/executable_claude-account" "$test_home/bin/claude-account"
chmod +x "$test_home/bin/"*
export HOME="$test_home" PATH="$test_home/bin:$PATH"
state="$HOME/.local/state/claude"
printf 'test-work-token' >"$state/oauth-work"
printf 'test-personal-token' >"$state/oauth-personal"
wrapper="$source_dir/dot_local/bin/executable_claude"

run_in() {
  (cd "$1" && env -u CLAUDE_CONFIG_DIR -u CLAUDE_ACCOUNT -u CLAUDE_CODE_OAUTH_TOKEN -u FM_TASK_ID bash "$wrapper")
}

expect() {
  [ "$1" = "$2" ] || { printf 'expected %s, got %s (%s)\n' "$2" "$1" "$3" >&2; exit 1; }
}

claude-account pin work >/dev/null
expect "$(run_in "$HOME/mate")" "$HOME/.claude-work|work|test-work-token" 'no store pin keeps the account default'

rm -f "$HOME/.claude.json" "$HOME/.claude-work/.claude.json"
claude-account store-pin "$HOME/mate/" ordinary >/dev/null
expect "$(claude-account store-pin "$HOME/mate")" ordinary 'trailing slash is normalized'
expect "$(run_in "$HOME/mate")" 'ordinary|work|test-work-token' 'ordinary store pin keeps the native store and bills work'
[ -f "$HOME/.claude.json" ] || { echo 'trust was not seeded into the native store' >&2; exit 1; }
[ ! -f "$HOME/.claude-work/.claude.json" ] || { echo 'trust leaked into the billing store' >&2; exit 1; }
expect "$(run_in "$HOME/mate/sub")" "$HOME/.claude-work|work|test-work-token" 'store pin is exact, not a prefix'
expect "$(run_in "$HOME/other")" "$HOME/.claude-work|work|test-work-token" 'unrelated path is untouched'

expect "$(cd "$HOME/mate" && env -u CLAUDE_ACCOUNT -u CLAUDE_CODE_OAUTH_TOKEN CLAUDE_CONFIG_DIR="$HOME/.claude-work" bash "$wrapper")" \
  "$HOME/.claude-work|work|test-work-token" 'an exported store still wins'

claude-account pin personal >/dev/null
claude-account store-pin "$HOME/mate" "$HOME/.claude-work" >/dev/null
expect "$(run_in "$HOME/mate")" "$HOME/.claude-work|personal|test-personal-token" 'a store pin never changes billing'

claude-account pin auto >/dev/null
expect "$(run_in "$HOME/mate")" "$HOME/.claude-work|personal|test-personal-token" 'a store pin never feeds account inference'

claude-account path-pin "$HOME/mate" work >/dev/null
claude-account store-pin "$HOME/mate" ordinary >/dev/null
expect "$(run_in "$HOME/mate")" 'ordinary|work|test-work-token' 'billing path pin and store pin combine'

claude-account store-pin "$HOME/mate" auto >/dev/null
expect "$(claude-account store-pin "$HOME/mate")" '' 'auto removes the mapping'
expect "$(run_in "$HOME/mate")" "$HOME/.claude-work|work|test-work-token" 'removed pin falls back to the account default'

for bad in "relative ordinary" "$HOME/mate $HOME/missing" "$HOME/mate bogus" "/ ordinary"; do
  # shellcheck disable=SC2086
  if claude-account store-pin $bad >/dev/null 2>&1; then
    printf 'store-pin accepted invalid input: %s\n' "$bad" >&2
    exit 1
  fi
done
ln -s "$HOME/.claude-work" "$HOME/link-store"
if claude-account store-pin "$HOME/mate" "$HOME/link-store" >/dev/null 2>&1; then
  echo 'store-pin accepted a symlinked store' >&2
  exit 1
fi
[ "$(stat -c %a "$state/store-by-path" 2>/dev/null || stat -f %Lp "$state/store-by-path")" = 600 ] || { echo 'store-by-path is not private' >&2; exit 1; }

echo 'store pin tests passed'
