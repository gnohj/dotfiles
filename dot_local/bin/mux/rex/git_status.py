"""Git status symbols and their cache for the ctrl+t session picker (rex-session-picker.sh).

The picker answers "what is this repo's working tree doing?" for every row it lists. Its
warm pass fills the cache lazily, so a freshly opened picker reads symbols from disk
instead of running git per row.

Status is carried as (char, sgr) pairs - one per rendered character - so the picker can
clip by display width without cutting an escape sequence.

Cache entry: {path: [unix_ts, sgr_string, display_width, has_real_changes]}.
"""

import fcntl
import json
import os
import time
import unicodedata

# subprocess is imported inside status(): the picker's warm-cache render never shells out.

RESET = "\033[0m"
SYM_W = 28
CACHE = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
    "rex-picker", "git-cache.json")

# Codepoints so no literal glyph lives here.
BEHIND, AHEAD = chr(0x1F447), chr(0x1F446)
STAGED, CONFLICT, MODIFIED = chr(0x25CF), chr(0x2716), chr(0x271A)
UNTRACKED = chr(0xF1036) + " "
INSERTIONS, DELETIONS = chr(0xF457) + " ", chr(0xF458) + " "

STYLES = {"divergence": "05", "staged": "02", "conflict": "11", "modified": "04", "untracked": "05"}
GREEN, RED = "\033[32m", "\033[31m"


def dwidth(s):
    n = 0
    for ch in s:
        if unicodedata.combining(ch):
            continue
        n += 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
    return n


def tc(hexs):
    h = (hexs or "").lstrip("#")
    if len(h) != 6:
        return RESET
    return "\033[38;2;%d;%d;%dm" % (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def style(role):
    return tc(os.environ.get("gnohj_color" + STYLES[role]))


def _git(cwd, args, timeout):
    import subprocess
    env = dict(os.environ, GIT_OPTIONAL_LOCKS="0", LC_ALL="C",
               PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:" + os.environ.get("PATH", ""))
    r = subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True, timeout=timeout, env=env)
    if r.returncode != 0:
        raise RuntimeError(r.stderr)
    return r.stdout


def status(cwd, timeout=1.2):
    """Symbol pairs for cwd: divergence, unstaged diff stats, then staged/conflict/modified/untracked counts."""
    deadline = time.time() + timeout
    try:
        porcelain = _git(cwd, ["status", "--porcelain=v2", "--branch"], timeout)
        shortstat = _git(cwd, ["diff", "--shortstat"], max(deadline - time.time(), 0.1))
    except Exception:
        return []
    ahead = behind = staged = conflict = modified = untracked = 0
    for line in porcelain.splitlines():
        if line.startswith("# branch.ab "):
            parts = line.split()
            ahead, behind = int(parts[2].lstrip("+")), int(parts[3].lstrip("-"))
        elif line.startswith(("1 ", "2 ")):
            xy = line[2:4]
            staged += xy[0] != "."
            modified += xy[1] != "."
        elif line.startswith("u "):
            conflict += 1
        elif line.startswith("? "):
            untracked += 1
    ins = dels = 0
    for part in shortstat.split(","):
        words = part.split()
        if len(words) >= 2 and words[0].isdigit():
            if words[1].startswith("insertion"):
                ins = int(words[0])
            elif words[1].startswith("deletion"):
                dels = int(words[0])

    sections = []
    div = (BEHIND + str(behind) if behind else "") + (AHEAD + str(ahead) if ahead else "")
    if div:
        sections.append([(div, style("divergence"))])
    stats = []
    if ins:
        stats.append((INSERTIONS + str(ins), GREEN))
    if dels:
        stats.append((DELETIONS + str(dels), RED))
    if stats:
        sections.append(stats)
    flags = []
    for n, sym, role in ((staged, STAGED, "staged"), (conflict, CONFLICT, "conflict"),
                         (modified, MODIFIED, "modified"), (untracked, UNTRACKED, "untracked")):
        if n:
            flags.append((sym + str(n), style(role)))
    if flags:
        sections.append(flags)

    pairs = []
    for section in sections:
        for text, sgr in section:
            if pairs:
                pairs.append((" ", RESET))
            pairs.extend((ch, sgr) for ch in text)
    return pairs


def git_pairs(cwd, roots_only=True):
    """Symbol pairs for cwd; [] when it isn't worth asking.

    roots_only skips the git subprocess for anything that isn't a checkout root -
    only a root carries a ".git" entry (dir for a main repo, file for a worktree). The
    picker uses it to stay fast over ~100 zoxide dirs, mostly nested subdirs; it passes
    False for open sessions so one sitting deep inside a repo still reports.
    """
    if not cwd:
        return []
    if roots_only and not os.path.exists(os.path.join(cwd, ".git")):
        return []
    return status(cwd)


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


def entry(pairs, ts=None, w=SYM_W):
    """Symbol pairs -> one cache entry."""
    scol, sw = clip_colored(pairs, w)
    return [time.time() if ts is None else ts, scol, sw, bool(pairs)]


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
    would have to re-derive the roots_only rule and could disagree with build_list), the
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

    Read-modify-write, so a warm pass and a git action's drop() can both write
    without clobbering each other. Its own lock file, NOT the warm pass's dedupe lock:
    a drop() must never look like a second warm and make one bail out.
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
