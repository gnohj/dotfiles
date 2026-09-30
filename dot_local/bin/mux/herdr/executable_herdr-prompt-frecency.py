#!/usr/bin/env python3
"""Global frecency for herdr-prompt-picker.sh: `rank [--stream <dir>]` floats frecent rows up with a star, `bump <key>` records a pick."""
import json
import os
import sys
import tempfile
import time
from pathlib import Path

sys.dont_write_bytecode = True

STORE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "herdr-prompt-picker/frecency.json"
STAR, DIM, RESET, BLANK = "⭐", "\033[2m", "\033[0m", "      "


def load():
    try:
        return json.loads(STORE.read_text())
    except (OSError, ValueError):
        return {}


def score(entry, now):
    # zoxide's aging: recent picks weigh more, so an old favourite slowly yields to what you use now.
    age = now - entry.get("last", 0)
    factor = 4 if age < 3600 else 2 if age < 86400 else 0.5 if age < 604800 else 0.25
    return entry.get("count", 0) * factor


def rank():
    data, now = load(), time.time()
    scored, rest = [], []
    for line in sys.stdin:
        cols = line.rstrip("\n").split("\t")
        if len(cols) < 4:
            continue
        s = score(data[cols[3]], now) if cols[3] in data else 0
        (scored if s else rest).append((s, cols))
    scored.sort(key=lambda r: -r[0])
    for s, cols in scored:
        sys.stdout.write(row(star(s), cols))
    for _, cols in rest:
        sys.stdout.write(row(BLANK, cols))


def row(star, cols):
    return f"{cols[0]}\t{star}\t" + "\t".join(cols[1:]) + "\n"


def star(s):
    return f"{STAR}{DIM}{max(1, round(s)):>3}{RESET}"


def rank_stream(root):
    # Frecent files come straight from the store, the rest pass through as fd yields them, minus the ones already shown.
    data, now, prefix, out = load(), time.time(), root.rstrip("/") + "/", sys.stdout
    shown = set()
    hits = [(score(e, now), k) for k, e in data.items() if k.startswith(prefix) and os.path.isfile(k)]
    for s, key in sorted(hits, reverse=True):
        rel = key[len(prefix):]
        out.write(row(star(s), [f"@{rel} ", rel, key, key]))
        shown.add(key)
    out.flush()
    for line in sys.stdin:
        cols = line.rstrip("\n").split("\t")
        if len(cols) >= 4 and cols[3] not in shown:
            out.write(row(BLANK, cols))


def bump(key):
    data = load()
    entry = data.setdefault(key, {"count": 0, "last": 0})
    entry["count"] += 1
    entry["last"] = int(time.time())
    STORE.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=STORE.parent)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f)
    os.replace(tmp, STORE)


if __name__ == "__main__":
    if sys.argv[1:3] == ["rank", "--stream"] and len(sys.argv) == 4:
        rank_stream(sys.argv[3])
    elif sys.argv[1:] == ["rank"]:
        rank()
    elif sys.argv[1:2] == ["bump"] and len(sys.argv) == 3:
        bump(sys.argv[2])
    else:
        sys.exit("usage: herdr-prompt-frecency.py rank [--stream <dir>] | bump <key>")
