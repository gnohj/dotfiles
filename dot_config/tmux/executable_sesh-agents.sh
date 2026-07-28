#!/usr/bin/env bash
# Row source for the sesh picker (rows are "<icon> <name>"); `--kill <row>` is ctrl-d's handler.

export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
[ "$(uname)" = Linux ] && PATH="$HOME/.nix-profile/bin:/home/linuxbrew/.linuxbrew/bin:$PATH"

if [[ "${1:-}" == "--kill" ]]; then
  row="${2:-}"
  # Drop the leading sesh icon glyph (fzf has already stripped the ANSI).
  name="${row#* }"
  # ...and the alias chip, which is display only and would break the -t target.
  name="${name% \[*\]}"
  [[ -n "$name" ]] && tmux kill-session -t "$name" 2>/dev/null
  exit 0
fi

ALIAS_CACHE="${SESH_ALIAS_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/sesh/aliases.tsv}"
SESH_TOML="${SESH_CONFIG:-$HOME/.config/sesh/sesh.toml}"
# Only a newer sesh.toml costs a fork; `[` is a builtin, so the steady state forks nothing.
[[ -s "$ALIAS_CACHE" && ! "$SESH_TOML" -nt "$ALIAS_CACHE" ]] ||
  "$HOME/.config/sesh/sesh-aliases.sh" >/dev/null 2>&1
# awk aborts on an unreadable input, which would cost the picker every row, not just the chips.
[[ -s "$ALIAS_CACHE" ]] || ALIAS_CACHE=/dev/null

# The "[xx]" chip rides inside the row, so typing an alias narrows it instead of adding a row.
sesh list "$@" --icons 2>/dev/null | awk -F'\t' -v ESC=$'\033' '
# Alias lines are the only 3-field records, so input order never matters.
NF == 3 { alias[$2] = $1; next }
{
  # Names are matched with the ANSI stripped; the icon is everything up to the first space.
  plain = $0
  gsub(ESC "\\[[0-9;]*m", "", plain)
  sp = index(plain, " ")
  name = sp ? substr(plain, sp + 1) : plain
  print (name in alias) ? $0 " " ESC "[90m[" alias[name] "]" ESC "[39m" : $0
}
' "$ALIAS_CACHE" - 2>/dev/null
