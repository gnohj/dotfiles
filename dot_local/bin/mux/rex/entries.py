"""Session entries from ~/.config/rex/entries.toml, for rex-session-picker.sh and rex-session-ctl.

Run directly it prints them as a JSON list, one object per [[session]] with its raw keys.
"""

import json
import os
import re
import sys

ENTRIES = os.environ.get("REX_ENTRIES") or os.path.expanduser("~/.config/rex/entries.toml")
_KV = re.compile(r'^\s*([A-Za-z_]+)\s*=\s*"((?:[^"\\]|\\.)*)"\s*$')
_ESC = re.compile(r"\\(.)")


def read(path=ENTRIES):
    out, cur = [], None
    try:
        with open(path) as fh:
            lines = list(fh)
    except Exception:
        return out
    for line in lines:
        s = line.strip()
        if s == "[[session]]":
            cur = {}
            out.append(cur)
        elif s.startswith("["):
            cur = None
        elif cur is not None:
            m = _KV.match(line)
            if m:
                cur[m.group(1)] = _ESC.sub(r"\1", m.group(2))
    return [e for e in out if e.get("name") and e.get("path")]


def expand(path, home=os.path.expanduser("~")):
    if path == "~" or path.startswith("~/"):
        path = home + path[1:]
    return path.rstrip("/") or "/"


if __name__ == "__main__":
    json.dump(read(sys.argv[1] if len(sys.argv) > 1 else ENTRIES), sys.stdout)
    sys.stdout.write("\n")
