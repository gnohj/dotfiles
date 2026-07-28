#!/usr/bin/env bash
# Emits "<alias>\t<name>\t<path>" per aliased [[session]]; `sesh list` never exposes aliases itself.

CONFIG="${SESH_CONFIG:-$HOME/.config/sesh/sesh.toml}"
[ -f "$CONFIG" ] || exit 0
# Path kept in step with sesh-agents.sh, which reads this cache directly rather than forking here.
CACHE="${SESH_ALIAS_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/sesh/aliases.tsv}"

# awk, not python: on the popup's reload path an interpreter start-up outweighed the whole pipeline.
parse() {
  awk -v home="$HOME" -v SQ="'" '
function emit() {
  if (alias != "" && name != "" && path != "") {
    p = path
    # Bare leading-`~` swap with no normalising, matching how sesh builds its own Path field.
    if (p == "~") p = home
    else if (substr(p, 1, 2) == "~/") p = home substr(p, 2)
    sub(/\/+$/, "", p)
    print alias "\t" name "\t" (p == "" ? "/" : p)
  }
  alias = ""; name = ""; path = ""
}
/^[[:space:]]*\[\[session\]\][[:space:]]*$/ { emit(); insess = 1; next }
/^[[:space:]]*\[/                           { emit(); insess = 0; next }
insess && match($0, /^[[:space:]]*[A-Za-z_]+[[:space:]]*=/) {
  k = substr($0, 1, RLENGTH); gsub(/[[:space:]=]/, "", k)
  if (k == "name" || k == "path" || k == "alias") {
    v = substr($0, RLENGTH + 1)
    # SQ holds a literal quote, so the single-quoted-value branch needs no octal escape.
    if (match(v, /"[^"]*"/) || match(v, SQ "[^" SQ "]*" SQ)) {
      val = substr(v, RSTART + 1, RLENGTH - 2)
      if (k == "name") name = val; else if (k == "path") path = val; else alias = val
    }
  }
}
END { emit() }
' "$CONFIG"
}

if [ ! -s "$CACHE" ] || [ "$CONFIG" -nt "$CACHE" ]; then
  if mkdir -p "${CACHE%/*}" 2>/dev/null && parse >"$CACHE.$$" 2>/dev/null; then
    mv -f "$CACHE.$$" "$CACHE" 2>/dev/null || rm -f "$CACHE.$$"
  else
    rm -f "$CACHE.$$" 2>/dev/null
  fi
fi

# Unwritable cache dir is not fatal; fall back to parsing straight to stdout.
[ -s "$CACHE" ] && cat "$CACHE" || parse
