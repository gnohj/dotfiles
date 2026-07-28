#!/usr/bin/env bash
# Row source for the sesh picker (rows are "<icon> <name>"); `--kill <row>` is ctrl-d's handler.

export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
[ "$(uname)" = Linux ] && PATH="$HOME/.nix-profile/bin:/home/linuxbrew/.linuxbrew/bin:$PATH"

if [[ "${1:-}" == "--kill" ]]; then
  row="${2:-}"
  # Drop the leading sesh icon glyph (fzf has already stripped the ANSI).
  name="${row#* }"
  # ...then the alias chip, which is display only and would break the -t target.
  name="${name#\[*\] }"
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

[ -f "$HOME/.config/colorscheme/active/active-colorscheme.sh" ] &&
  source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

# The "[xx]" chip sits inside the row, between icon and name, so an alias narrows rather than duplicates.
sesh list "$@" --icons 2>/dev/null | awk -F'\t' -v ESC=$'\033' -v CHIP_HEX="${gnohj_color04:-}" '
function hex(s,   i, c, v, n) {
  n = 0
  for (i = 1; i <= length(s); i++) {
    v = index("0123456789abcdef", tolower(substr(s, i, 1))) - 1
    if (v < 0) return -1
    n = n * 16 + v
  }
  return n
}
# strtonum is gawk-only, so the palette hex is unpacked by hand into a truecolor SGR.
BEGIN {
  if (CHIP_HEX ~ /^#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$/)
    BLUE = ESC "[38;2;" hex(substr(CHIP_HEX, 2, 2)) ";" hex(substr(CHIP_HEX, 4, 2)) ";" hex(substr(CHIP_HEX, 6, 2)) "m"
  else
    BLUE = ESC "[94m"
}
# Alias lines are the only 3-field records, so input order never matters.
NF == 3 { alias[$2] = $1; if (length($1) > awide) awide = length($1); next }
{
  # No ANSI escape contains a space, so the first space is always the icon/name boundary.
  plain = $0
  gsub(ESC "\\[[0-9;]*m", "", plain)
  sp = index(plain, " ")
  name = sp ? substr(plain, sp + 1) : plain
  if (!(name in alias) || !sp) { print $0; next }
  # Pad to the widest alias so a one-letter chip does not pull its name a column left.
  pad = ""
  for (i = length(alias[name]); i < awide; i++) pad = pad " "
  cut = index($0, " ")
  print substr($0, 1, cut) BLUE "[" alias[name] "]" ESC "[39m" pad " " substr($0, cut + 1)
}
' "$ALIAS_CACHE" - 2>/dev/null
