"""gitmux rendering shared by the herdr sidebar poller and the ctrl+t session picker.

Both surfaces answer the same question - "what is this repo's working tree doing?" -
and used to answer it independently: herdr-git-status.sh polls every few seconds to
feed the sidebar `$git` token, while herdr-sesh.sh built its own colored column at
picker-open time and cached it. The two drifted apart whenever the picker's cache was
older than the last poll, which is always: the picker's refresh is a detached pass
whose result only lands on the NEXT open. Now the poller writes the picker's cache
entries from the same gitmux run that produces the token, so an open workspace shows
one answer on both surfaces, at most one poll interval old.

The cache stays the picker's own file. Inactive zoxide/config rows (~100 of them) have
no poller visiting them, so those are still filled lazily by the picker's warm pass.

Status is carried as (char, sgr) pairs - one per rendered character - because gitmux
emits tmux "#[fg=…]" codes mid-string and fzf --ansi only speaks SGR.

Cache entry: {path: [unix_ts, sgr_string, display_width, has_real_changes]}.
"""

import fcntl
import json
import os
import re
import time
import unicodedata

# subprocess is imported inside run(): the picker's warm-cache render never shells out.

RESET = "\033[0m"
SYM_W = 28
GITMUX_CFG = os.path.expanduser("~/.config/gitmux/gitmux.yml")
CACHE = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
    "herdr", "sesh-git-cache.json")

_TMUX_CODE = re.compile(r"(#\[[^]]*\])")
_NAMED = {"black": 30, "red": 31, "green": 32, "yellow": 33,
          "blue": 34, "magenta": 35, "cyan": 36, "white": 37}
# Stash is dropped (not a working-tree change); ahead/behind deliberately are not - unpushed/unpulled is worth sorting on. Codepoint so no literal glyph lives here.
_NOISE = re.compile("[" + chr(0xEA98) + r"]\s*\d*")


def dwidth(s):
    n = 0
    for ch in s:
        if unicodedata.combining(ch):
            continue
        n += 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
    return n


def sgr(inner):
    """tmux "#[...]" body -> SGR (fg only; none/default -> reset)."""
    if inner in ("none", "") or "default" in inner:
        return RESET
    codes = []
    for part in inner.split(","):
        if not part.startswith("fg="):
            continue
        v = part[3:]
        if v.startswith("#") and len(v) == 7:
            codes.append("38;2;%d;%d;%d" % (int(v[1:3], 16), int(v[3:5], 16), int(v[5:7], 16)))
        elif v in _NAMED:
            codes.append(str(_NAMED[v]))
    return "\033[" + ";".join(codes) + "m" if codes else RESET


def run(cwd, cfg=GITMUX_CFG, timeout=1.2):
    """Raw gitmux stdout for cwd (tmux color codes intact), "" on any failure."""
    import subprocess
    try:
        env = dict(os.environ, PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:"
                   + os.environ.get("PATH", ""))
        return subprocess.run(["gitmux", "-cfg", cfg], cwd=cwd, capture_output=True,
                              text=True, timeout=timeout, env=env).stdout or ""
    except Exception:
        return ""


def parse(raw):
    """Raw gitmux stdout -> (branch_pairs, symbol_pairs)."""
    pairs, cur = [], RESET
    for tok in _TMUX_CODE.split(raw):
        if not tok:
            continue
        if tok.startswith("#["):
            cur = sgr(tok[2:-1])
        else:
            for ch in tok:
                pairs.append((ch, cur))
    # Trim and collapse whitespace so widths and the branch/symbols split are stable.
    trimmed, prev_sp = [], False
    for ch, c in pairs:
        if ch.isspace():
            if prev_sp or not trimmed:
                continue
            trimmed.append((" ", c))
            prev_sp = True
        else:
            trimmed.append((ch, c))
            prev_sp = False
    while trimmed and trimmed[-1][0] == " ":
        trimmed.pop()
    sp = next((i for i, (c, _) in enumerate(trimmed) if c == " "), None)
    if sp is None:
        return trimmed, []
    return trimmed[:sp], trimmed[sp + 1:]


def git_pairs(cwd, cfg=GITMUX_CFG, roots_only=True):
    """(branch_pairs, symbol_pairs) for cwd; ([], []) when it isn't worth asking.

    roots_only skips the gitmux subprocess for anything that isn't a checkout root -
    only a root carries a ".git" entry (dir for a main repo, file for a worktree). The
    picker uses it to stay fast over ~100 zoxide dirs, mostly nested subdirs; callers
    holding a handful of paths pass False so a workspace sitting deep inside a repo
    still reports, exactly as the sidebar poller does.
    """
    if not cwd:
        return [], []
    if roots_only and not os.path.exists(os.path.join(cwd, ".git")):
        return [], []
    return parse(run(cwd, cfg))


def plain(pairs):
    return "".join(c for c, _ in pairs)


def strip_noise(pairs):
    while True:
        m = _NOISE.search(plain(pairs))
        if not m:
            break
        pairs = pairs[:m.start()] + pairs[m.end():]
    while pairs and pairs[0][0] == " ":
        pairs.pop(0)
    while pairs and pairs[-1][0] == " ":
        pairs.pop()
    return pairs


def has_changes(pairs):
    return bool(_NOISE.sub("", plain(pairs)).strip())


def clip_colored(pairs, w=SYM_W):
    """(sgr_string, used_display_width), clipped to w columns with a trailing "…"."""
    plain_w = sum(dwidth(c) for c, _ in pairs)
    limit = w if plain_w <= w else w - 1
    out, cur, used = [], None, 0
    for ch, c in pairs:
        cw = dwidth(ch)
        if used + cw > limit:
            break
        if c != cur:
            out.append(c)
            cur = c
        out.append(ch)
        used += cw
    if plain_w > w:
        out.append(RESET + "…")
        used += 1
    out.append(RESET)
    return "".join(out), used


def entry(symbol_pairs, ts=None, w=SYM_W):
    """Symbol pairs -> one cache entry."""
    spairs = strip_noise(symbol_pairs)
    scol, sw = clip_colored(spairs, w)
    return [time.time() if ts is None else ts, scol, sw, has_changes(spairs)]


def load():
    try:
        with open(CACHE) as f:
            return json.load(f)
    except Exception:
        return {}


def _save(cache):
    tmp = CACHE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cache, f)
    os.replace(tmp, CACHE)


def drop(paths):
    """Forget paths, so the next render recomputes them instead of showing stale symbols.

    Used after the picker runs a git action on a row: rather than recompute here (which
    would have to re-derive the roots_only rule and could disagree with the poller), the
    entry is removed and build_list's own "missing" pass fills it back in.
    """
    try:
        with open(CACHE + ".wlock", "a+") as lk:
            fcntl.flock(lk, fcntl.LOCK_EX)
            cache = load()
            hits = [p for p in paths if cache.pop(p, None) is not None]
            if hits:
                _save(cache)
    except Exception:
        pass


def update(entries, keep=None):
    """Merge entries into the cache under a write lock, optionally pruning to keep.

    Read-modify-write, so the sidebar poller and a picker warm pass can both write
    without clobbering each other. Its own lock file, NOT the warm pass's dedupe lock:
    the poller must never look like a second warm and make one bail out.
    """
    try:
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        with open(CACHE + ".wlock", "a+") as lk:
            fcntl.flock(lk, fcntl.LOCK_EX)
            cache = load()
            cache.update(entries)
            if keep is not None:
                cache = {k: v for k, v in cache.items() if k in keep}
            _save(cache)
    except Exception:
        pass
