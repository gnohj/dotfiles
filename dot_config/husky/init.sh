export PATH="$HOME/.local/share/mise/shims:$PATH"

# Repos with a local core.hooksPath (web -> .husky/_) shadow ~/.config/git/hooks entirely.
case "$(basename "${0:-}")" in
  post-commit)
    # Guarded: husky sources this file for every hook that has a .husky/<hook> script.
    _ghook="${XDG_CONFIG_HOME:-$HOME/.config}/git/hooks/post-commit"
    if [ -x "$_ghook" ]; then
      "$_ghook" || true
    fi
    unset _ghook
    ;;
esac

# .husky/post-commit is untracked, so a fresh worktree has none and silently stops logging.
if [ -d .husky/_ ] && [ ! -e .husky/post-commit ]; then
  # Sourced before husky's HUSKY=0 bail and on any hook, so pre-commit bootstraps it.
  printf '#!/usr/bin/env sh\n# Untracked no-op so husky reaches init.sh, which chains the global ticket-log hook.\nexit 0\n' \
    > .husky/post-commit 2>/dev/null || true
fi
