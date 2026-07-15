#!/usr/bin/env bash
# herdr-sesh.sh — sesh-style session picker for herdr (the ctrl+t navigator, the
# herdr-native replacement for the tmux sesh popup). Runs as a herdr `type = "pane"`
# command (zoom overlay like ctrl+g/ctrl+y) → server-side, so it works local AND
# over --remote.
#
# It reuses `sesh list -c -z --icons` verbatim, so config entries come straight from
# sesh.toml (⚙ gear) and recent dirs from the zoxide DB (📁 folder) — LIVE, no
# re-authoring. On top it pins herdr's currently-OPEN workspaces (⚡), queried fresh
# each open. Theme matches the tmux sesh popup (dot_config/tmux/sesh-popup.sh).
#
#   enter   → focus an open workspace, else open the dir with the sesh dev layout
#             (herdr-sesh-layout.sh: pen nvim + fish shells; attaches if already open)
#   ctrl-d  → delete the highlighted item WITHOUT closing the picker: close an open
#             workspace (⚡), remove a zoxide dir (📁); ⚙ config is left alone (it
#             lives in sesh.toml). The list reloads in place.
#   ctrl-b  → abort
#
# Subcommands (used by fzf's reload/execute binds, not called directly):
#   --list            print the merged rows ("<display>\t<kind>:<target>")
#   --delete <target> delete one "<kind>:<target>"
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
export _ZO_DATA_DIR="${_ZO_DATA_DIR:-$HOME/.config/zshrc}"
SELF="$HOME/.local/bin/herdr-sesh.sh"

build_list() {
  # Keep gitmux off the render path: fire a detached background pass to refresh the git
  # cache (deduped via flock inside), so THIS open renders instantly from whatever is
  # cached and the NEXT open is fresh. Skipped when we already are that warm pass (WARM set).
  [ -n "${WARM:-}" ] || ( "$SELF" --warm >/dev/null 2>&1 & )
  ACTIVE_WS="$("$herdr" workspace list 2>/dev/null)" \
  PANES="$("$herdr" pane list 2>/dev/null)" \
  ENTRIES="$(sesh list -c -z -j 2>/dev/null)" \
  CFGPATHS="$(sesh list -c -j 2>/dev/null)" \
  FG="${gnohj_color02:-}" DIM="${gnohj_color09:-}" ACCENT="${gnohj_color04:-}" \
  HOME="$HOME" python3 -c '
import os, json

def load(env):
    try: return json.loads(os.environ.get(env, "") or "null")
    except Exception: return None

home = os.environ.get("HOME", "")
def short(p): return "~" + p[len(home):] if home and p.startswith(home) else p

def tc(hexs):  # hex "#rrggbb" -> truecolor SGR (matches the popup palette)
    h = (hexs or "").lstrip("#")
    if len(h) != 6: return ""
    return "\033[38;2;%d;%d;%dm" % (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))

RESET, BOLD = "\033[0m", "\033[1m"
fg, dim, accent = tc(os.environ.get("FG")), tc(os.environ.get("DIM")), tc(os.environ.get("ACCENT"))
TAB = "\t"
rows = []

# ---- git columns for active workspaces ----------------------------------------
# Reuse the SAME gitmux config as the tmux status line so the symbols match. gitmux
# emits tmux "#[fg=...]" codes; those are converted to SGR (fzf --ansi speaks SGR, not
# tmux codes) so the picker keeps gitmux'"'"'s colors. Only the gitmux SYMBOLS are shown
# (the branch is dropped by request); they sit on the workspace-name line, and only for
# the ACTIVE workspace (⚡) rows — never the ~100 zoxide/config rows (running gitmux on
# all of them would stall the picker). Degrades gracefully: no gitmux/git -> just name + path.
#
# Layout: ⚡ name │ path │ symbols. name + path are pure ASCII (exact width), so padding
# them aligns the columns perfectly; the git glyphs (wide emoji + ambiguous-width nerd
# symbols whose rendered width is terminal-dependent) go LAST, where their width can'"'"'t
# throw off any column. Each section is clipped to a fixed DISPLAY width with "…".
import re as _re, subprocess, unicodedata
GITMUX_CFG = os.path.expanduser("~/.config/gitmux/gitmux.yml")
TMUX_CODE = _re.compile(r"(#\[[^]]*\])")
NAME_W, PATH_W, SYM_W = 16, 40, 28  # per-section clip thresholds (columns)
NAMED = {"black":30,"red":31,"green":32,"yellow":33,"blue":34,"magenta":35,"cyan":36,"white":37}

def dwidth(s):
    n = 0
    for ch in s:
        if unicodedata.combining(ch): continue
        n += 2 if unicodedata.east_asian_width(ch) in ("W","F") else 1
    return n

def dclip(s, w, left=False):  # plain-text clip to display width w, "…" on the clipped end
    if dwidth(s) <= w: return s
    out = ""
    if left:
        for ch in reversed(s):
            if dwidth(ch) + dwidth(out) > w - 1: break
            out = ch + out
        return "…" + out
    for ch in s:
        if dwidth(ch) + dwidth(out) > w - 1: break
        out += ch
    return out + "…"

def dpad(s, w):
    p = w - dwidth(s)
    return s + " " * p if p > 0 else s

def sgr(inner):  # tmux "#[...]" body -> SGR (fg only; none/default -> reset)
    if inner in ("none", "") or "default" in inner: return RESET
    codes = []
    for part in inner.split(","):
        if part.startswith("fg="):
            v = part[3:]
            if v.startswith("#") and len(v) == 7:
                codes.append("38;2;%d;%d;%d" % (int(v[1:3],16), int(v[3:5],16), int(v[5:7],16)))
            elif v in NAMED:
                codes.append(str(NAMED[v]))
    return "\033[" + ";".join(codes) + "m" if codes else RESET

def git_pairs(cwd):  # (branch_pairs, symbol_pairs) of (char, sgr); ([],[]) unless cwd is a checkout ROOT
    # Only a repo/worktree ROOT carries a ".git" entry (a dir for a main repo, a file for a
    # worktree). Nested subdirs have none — so this both honors "root only, not nested" AND
    # skips the gitmux subprocess for every nested dir (the bulk of the ~100 entries -> fast).
    if not cwd or not os.path.exists(os.path.join(cwd, ".git")): return [], []
    try:
        env = dict(os.environ, PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:" + os.environ.get("PATH",""))
        raw = subprocess.run(["gitmux","-cfg",GITMUX_CFG], cwd=cwd, capture_output=True,
                              text=True, timeout=1.2, env=env).stdout or ""
    except Exception:
        return [], []
    pairs, cur = [], RESET
    for tok in TMUX_CODE.split(raw):
        if not tok: continue
        if tok.startswith("#["): cur = sgr(tok[2:-1])
        else:
            for ch in tok: pairs.append((ch, cur))
    trimmed, prev_sp = [], False   # trim + collapse whitespace so widths + the split are stable
    for ch, c in pairs:
        if ch.isspace():
            if prev_sp or not trimmed: continue
            trimmed.append((" ", c)); prev_sp = True
        else:
            trimmed.append((ch, c)); prev_sp = False
    while trimmed and trimmed[-1][0] == " ": trimmed.pop()
    sp = next((i for i,(c,_) in enumerate(trimmed) if c == " "), None)
    if sp is None: return trimmed, []          # branch only (clean repo)
    return trimmed[:sp], trimmed[sp+1:]

def clip_colored(pairs, w):  # -> (sgr_string, used_display_width)
    plain_w = sum(dwidth(c) for c,_ in pairs)
    limit = w if plain_w <= w else w - 1
    out, cur, used = [], None, 0
    for ch, c in pairs:
        cw = dwidth(ch)
        if used + cw > limit: break
        if c != cur: out.append(c); cur = c
        out.append(ch); used += cw
    if plain_w > w:
        out.append(RESET + "…"); used += 1
    out.append(RESET)
    return "".join(out), used

# Glyphs stripped from the shown symbols AND ignored for the "has real changes" sort: the
# stash bucket and ahead/behind divergence -- none are working-tree changes. Codepoints, so no
# literal glyphs live here. gitmux.yml is untouched, so the tmux status line keeps them all.
NOISE_RE = _re.compile("[" + chr(0xEA98) + chr(0x1F446) + chr(0x1F447) + r"]\s*\d*")
def has_changes(spairs):
    plain = "".join(c for c, _ in spairs)
    return bool(NOISE_RE.sub("", plain).strip())
def strip_noise(pairs):
    # Remove every noise token (glyph + count) from the symbol pairs, then trim edge spaces.
    while True:
        m = NOISE_RE.search("".join(c for c, _ in pairs))
        if not m: break
        pairs = pairs[:m.start()] + pairs[m.end():]
    while pairs and pairs[0][0] == " ": pairs.pop(0)
    while pairs and pairs[-1][0] == " ": pairs.pop()
    return pairs

import time
SEP = "❯"

# Representative cwd per open workspace (from its panes).
wscwd = {}
for pn in (load("PANES") or {}).get("result", {}).get("panes", []):
    w = pn.get("workspace_id"); c = (pn.get("foreground_cwd") or pn.get("cwd") or "").rstrip("/")
    if w and c and w not in wscwd: wscwd[w] = c

# Collect every entry uniformly: (kind, icon, name, path, target, active).
#   ws  ⚡ open herdr workspaces      cfg ⚙ sesh config dirs      zox 📁 zoxide dirs
entries = []
active_paths = set()
for w in (load("ACTIVE_WS") or {}).get("result", {}).get("workspaces", []):
    wid = w.get("workspace_id")
    # This picker builds its own git column from the cwd, so strip any " · <symbols>"
    # suffix a workspace label may carry to avoid a doubled/clipped name.
    label = (w.get("label", "?") or "?").split(" · ", 1)[0].rstrip()
    cwd = wscwd.get(wid, "").rstrip("/")
    if cwd: active_paths.add(cwd)
    entries.append(("ws", "⚡", label, cwd, "ws:" + wid, True))

cfg_paths = {(e.get("Path", "") or "").rstrip("/") for e in (load("CFGPATHS") or [])}
seen = set()
for e in (load("ENTRIES") or []):
    p = (e.get("Path", "") or "").rstrip("/")
    if not p or p in active_paths or p in seen: continue
    seen.add(p)
    if p in cfg_paths:
        kind, icon, name = "cfg", "⚙", (e.get("Name") or os.path.basename(p))  # nice config name
    else:
        kind, icon, name = "zox", "📁", (os.path.basename(p) or p)              # dir basename, not full path
    entries.append((kind, icon, name, p, kind + ":" + p, False))

# gitmux symbols for EVERY path so non-active repos show status too. Two problems this
# guards against: (1) running gitmux serially on ~100 dirs would freeze the picker, so
# compute in a thread pool (subprocess releases the GIL); (2) a fresh compute on every
# open / ctrl-d reload is wasteful, so cache per-path with a short TTL. Slightly stale
# symbols (< TTL) are fine for a picker.
CACHE = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
                     "herdr", "sesh-git-cache.json")
TTL = 30.0
def cache_load():
    try:
        with open(CACHE) as f: return json.load(f)
    except Exception: return {}
def cache_save(c):
    try:
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        tmp = CACHE + ".tmp"
        with open(tmp, "w") as f: json.dump(c, f)
        os.replace(tmp, CACHE)
    except Exception: pass

now = time.time()
cache = cache_load()
paths = [p for _, _, _, p, _, _ in entries if p]

def compute(p):
    _b, spairs = git_pairs(p)
    spairs = strip_noise(spairs)   # stash bucket is noise here; drop it from the display
    scol, sw = clip_colored(spairs, SYM_W)
    return p, [now, scol, sw, has_changes(spairs)]

# WARM pass (spawned detached by build_list): refresh entries older than TTL and drop paths no
# longer listed, then exit WITHOUT rendering. Runs off the render path so opening stays instant;
# it is what keeps the shown (possibly stale) symbols fresh. flock => only one warm at a time.
if os.environ.get("WARM") == "1":
    import fcntl
    lock = open(CACHE + ".lock", "a+")
    try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError: raise SystemExit(0)      # another warm already running
    todo = [p for p in dict.fromkeys(paths) if not (cache.get(p) and now - cache[p][0] < TTL)]
    if todo:
        from concurrent.futures import ThreadPoolExecutor
        with ThreadPoolExecutor(max_workers=16) as ex:
            for p, rec in ex.map(compute, todo): cache[p] = rec
        cache = {k: v for k, v in cache.items() if k in set(paths)}   # prune vanished paths
        cache_save(cache)
    raise SystemExit(0)

# Render path. Show cached symbols REGARDLESS of age — stale is fine (the bg warm refreshes
# them), and never hiding them is what stops the picker rendering blank after a short idle.
# Only entries genuinely MISSING from the cache are computed synchronously; that is just the
# first open (they then persist), and non-roots resolve instantly (git_pairs skips them). So:
# never blank, and fast on every subsequent open.
missing = [p for p in dict.fromkeys(paths) if p not in cache]
if missing:
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=16) as ex:
        for p, rec in ex.map(compute, missing): cache[p] = rec
    cache_save(cache)
sym = {}
for p in paths:
    hit = cache.get(p)
    if hit: sym[p] = (hit[1], hit[2], hit[3] if len(hit) > 3 else False)

# Sort: active workspaces first, then repos with REAL changes, then the rest. A stash-only repo
# does NOT count as changed (has_changes strips the stash bucket), so it stays in the base group.
def prio(ie):
    i, en = ie
    if en[5]: return (0, i)                                     # active
    return (1 if sym.get(en[3], ("", 0, False))[2] else 2, i)  # real working-tree changes else rest

# Render: <icon> name ❯ path ❯ symbols. icon/name/path padded to fixed DISPLAY widths so
# columns align; the wide git glyphs go last where their width cannot shift anything.
sep = "%s%s%s" % (dim, SEP, RESET)
for kind, icon, label, path0, target, active in [en for _, en in sorted(enumerate(entries), key=prio)]:
    scol, sw = sym.get(path0, ("", 0, False))[:2]
    icol = accent if active else dim
    ncol = (BOLD + fg) if active else fg
    ic = "%s%s%s" % (icol, dpad(icon, 2), RESET)
    nm = "%s%s%s" % (ncol, dpad(dclip(label, NAME_W), NAME_W), RESET)
    pth = "%s%s%s" % (dim, dpad(dclip(short(path0), PATH_W, left=True), PATH_W), RESET)
    tail = "  %s %s" % (sep, scol) if sw else ""
    rows.append("%s %s  %s  %s%s" % (ic, nm, sep, pth, tail) + TAB + target)

print("\n".join(rows))
'
}

# --- fzf reload/execute helpers -------------------------------------------------
case "${1:-}" in
  --list)
    [ -f "$HOME/.config/colorscheme/active/active-colorscheme.sh" ] &&
      source "$HOME/.config/colorscheme/active/active-colorscheme.sh"
    build_list
    exit 0
    ;;
  --warm)
    # Background git-cache refresh (spawned by build_list). Renders nothing; the python
    # exits after updating the cache. WARM=1 both selects that path and stops build_list
    # from spawning yet another warm.
    [ -f "$HOME/.config/colorscheme/active/active-colorscheme.sh" ] &&
      source "$HOME/.config/colorscheme/active/active-colorscheme.sh"
    WARM=1 build_list >/dev/null 2>&1
    exit 0
    ;;
  --delete)
    case "${2:-}" in
      ws:*)
        # Closing a workspace makes herdr shift focus to an adjacent one — even when
        # the closed workspace isn't the focused one. Since the picker overlays the
        # CURRENT workspace, deleting a different workspace would yank focus away.
        # Capture the focused workspace first and restore it after the close (unless
        # it's the one being deleted).
        target="${2#ws:}"
        focused=""
        if command -v jq >/dev/null 2>&1; then
          focused=$("$herdr" workspace list 2>/dev/null \
            | jq -r '.result.workspaces[] | select(.focused) | .workspace_id' 2>/dev/null)
        fi
        "$herdr" workspace close "$target" >/dev/null 2>&1
        [ -n "$focused" ] && [ "$focused" != "$target" ] &&
          "$herdr" workspace focus "$focused" >/dev/null 2>&1
        ;;
      zox:*) zoxide remove "${2#zox:}" >/dev/null 2>&1 ;;
      cfg:*) : ;;  # config entries live in sesh.toml — not deletable from the picker
    esac
    exit 0
    ;;
esac

# --- interactive picker ---------------------------------------------------------
[ -f "$HOME/.config/colorscheme/active/active-colorscheme.sh" ] &&
  source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

color_string="list-border:6,input-border:6,header-bg:-1,header-border:6,bg+:${gnohj_color13:-},fg+:${gnohj_color02:-},hl+:${gnohj_color04:-},fg:${gnohj_color02:-},info:${gnohj_color09:-},prompt:${gnohj_color04:-},pointer:${gnohj_color04:-},marker:${gnohj_color04:-},header:${gnohj_color09:-}"

command -v fzf     >/dev/null 2>&1 || { echo "fzf required";     sleep 1; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "python3 required"; sleep 1; exit 0; }

SELECTED=$(build_list | fzf \
  --no-border --ansi --layout=reverse --list-border --no-sort \
  --prompt '⚡ ' --gutter=' ' --color "$color_string" \
  --input-border --header-border \
  --delimiter='\t' --with-nth=1 \
  --bind 'tab:down,btab:up' \
  --bind 'ctrl-j:down,ctrl-k:up' \
  --bind 'ctrl-b:abort' \
  --bind "ctrl-d:execute-silent($SELF --delete {-1})+reload($SELF --list)")

[ -z "$SELECTED" ] && exit 0

TARGET="${SELECTED##*$'\t'}"
case "$TARGET" in
  ws:*)          exec "$herdr" workspace focus "${TARGET#ws:}" ;;
  cfg:*)         exec "$HOME/.local/bin/herdr-sesh-layout.sh" "${TARGET#cfg:}" ;;
  zox:*)         exec "$HOME/.local/bin/herdr-sesh-layout.sh" "${TARGET#zox:}" ;;
  *)             exit 0 ;;
esac
