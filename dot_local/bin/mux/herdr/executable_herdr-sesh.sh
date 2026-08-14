#!/usr/bin/env bash
# herdr-sesh.sh — sesh-style session picker for herdr (the ctrl+t navigator, the
# herdr-native replacement for the tmux sesh popup). Runs as a herdr `type = "pane"`
# command (zoom overlay like ctrl+g/prefix+y) → server-side, so it works local AND
# over --remote.
#
# It reuses `sesh list -c -z --icons` verbatim, so config entries come straight from
# sesh.toml (⚙️ gear) and recent dirs from the zoxide DB (📁 folder) — LIVE, no
# re-authoring. On top it pins herdr's OPEN workspaces (🌳/🌿/📁 glyph, else ⚡), queried fresh
# each open. Theme matches the tmux sesh popup (dot_config/tmux/sesh-popup.sh).
# Agents hang under their workspace as "state · activity · harness", claude/<account> when the harness is claude.
#
# The cursor starts on the row you are currently in (see focus_row), not on row 1.
#
#   enter   → focus an open workspace, else open the dir with the sesh dev layout
#             (herdr-sesh-layout.sh: pen nvim + fish shells; attaches if already open)
#   ctrl-d  → delete the highlighted item WITHOUT closing the picker: close a workspace (⚡), one agent's pane, or a zoxide dir (📁). ⚙️ config is left alone (it lives in sesh.toml); the list reloads in place.
#   ctrl-f  → fast-forward the highlighted row's repo from its upstream, ctrl-p pushes it. These are lazygit's f and P: f is its fastForward(), so it is "pull --ff-only" where there is a work tree and a ref-only "fetch remote up:branch" on a bare treekanga container, NOT a bare fetch. Works in the full list as well as the ctrl-g git view, and costs no search key since both are unbound in herdr, ghostty and fzf. Agent/tab rows act on their workspace's repo, so any row of a tree hits the same checkout.
#   ctrl-g  → INSIDE the git view, open the highlighted row's repo in lazygit (a bare container opens the checkout holding its branch). From the full list it still toggles the git view on.
#   esc     → close the popup, from ANY view: the git filter and the ctrl-w worktree menu close outright rather than stepping back to the full list. ctrl-b does the same.
#   ctrl-b  → abort
#
# Subcommands (used by fzf's reload/execute binds, not called directly):
#   --list            print the merged rows ("<display>\t<kind>:<target>")
#   --delete <target> delete one "<kind>:<target>"
#   --git <act> <dir> run pull/push/lazygit against <dir>, then forget its cached git symbols so the rebuild recomputes them
#   --view <rows> <view> <q> [--rebuild]   filter <rows> into <view>, print an fzf action
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
. "$HOME/.local/bin/mux/shared/mux-env.sh"
export _ZO_DATA_DIR="${_ZO_DATA_DIR:-$HOME/.config/zshrc}"
SELF="$HOME/.local/bin/mux/herdr/herdr-sesh.sh"

# Detaching the warm pass is not enough - its ~9 CPU-seconds land while you scroll the picker that spawned it; taskpolicy -b throttles CPU and I/O, nice is the Linux fallback.
if command -v taskpolicy >/dev/null 2>&1; then
  BG=(taskpolicy -b)
else
  BG=(nice -n 19)
fi

build_list() {
  # Keep gitmux off the render path: fire a detached background pass to refresh the git
  # cache (deduped via flock inside), so THIS open renders instantly from whatever is
  # cached and the NEXT open is fresh. Skipped when we already are that warm pass (WARM set).
  [ -n "${WARM:-}" ] || ( "${BG[@]}" "$SELF" --warm >/dev/null 2>&1 & )
  # Probes fan out into files, not command substitution: a subshell cannot hand a variable back.
  local src
  src="$(mktemp -d "${TMPDIR:-/tmp}/herdr-sesh-src.XXXXXX")" || return 1
  "$herdr" workspace list >"$src/ws" 2>/dev/null &
  "$herdr" pane list >"$src/pn" 2>/dev/null &
  "$herdr" agent list >"$src/ag" 2>/dev/null &
  "$herdr" tab list >"$src/tb" 2>/dev/null &
  sesh list -c -z -j >"$src/en" 2>/dev/null &
  # `sesh list` omits aliases in every output mode, so read them straight from sesh.toml.
  "$HOME/.config/sesh/sesh-aliases.sh" >"$src/al" 2>/dev/null &
  wait
  SRC="$src" \
  FG="${gnohj_color02:-}" DIM="${gnohj_color09:-}" ACCENT="${gnohj_color04:-}" \
  WORKING="${gnohj_color04:-}" BLOCKED="${gnohj_color11:-}" \
  DONE="${gnohj_color11:-}" IDLING="${gnohj_color05:-}" \
  WORKACCT="${gnohj_color04:-}" PERSONALACCT="${gnohj_color01:-}" \
  HOME="$HOME" python3 -c '
import os, json, re

def load(name):
    try:
        with open(os.path.join(os.environ["SRC"], name)) as fh: return json.load(fh)
    except Exception: return None

home = os.environ.get("HOME", "")
def short(p): return "~" + p[len(home):] if home and p.startswith(home) else p

# A pane reports the RESOLVED cwd, so a symlinked config path only matches once both sides are resolved.
def real(p):
    try: return os.path.realpath(p).rstrip("/") or p
    except Exception: return p

# Two indexes over the sesh-aliases.sh rows "<alias>\t<name>\t<path>": by NAME, the only field two
# entries sharing one path still differ on, and by PATH, the fallback that keeps an OPEN workspace
# showing its config alias. Path stays last-write-wins; the name lookup is what twins read.
def load_aliases():
    by_name, by_path = {}, {}
    try:
        with open(os.path.join(os.environ["SRC"], "al")) as fh:
            for line in fh:
                f = line.rstrip("\n").split("\t")
                if len(f) == 3 and f[0] and f[2]:
                    p = f[2].rstrip("/")
                    if f[1]: by_name.setdefault(f[1], f[0])
                    by_path[p] = f[0]
                    by_path.setdefault(real(p), f[0])
    except Exception: pass
    return by_name, by_path
alias_by_name, alias_by_path = load_aliases()
# Chips pad to the widest alias so a one-letter one does not pull its name a column left.
ALIAS_W = max([len(a) for a in list(alias_by_name.values()) + list(alias_by_path.values())] or [0])

def tc(hexs):  # hex "#rrggbb" -> truecolor SGR (matches the popup palette)
    h = (hexs or "").lstrip("#")
    if len(h) != 6: return ""
    return "\033[38;2;%d;%d;%dm" % (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))

RESET, BOLD = "\033[0m", "\033[1m"
fg, dim, accent = tc(os.environ.get("FG")), tc(os.environ.get("DIM")), tc(os.environ.get("ACCENT"))
TAB = "\t"
rows = []

# ---- git columns -----------------------------------------------------------------
# Reuse the SAME gitmux config as the tmux status line and herdr'"'"'s sidebar token so all
# three agree. Parsing (tmux "#[fg=...]" codes -> SGR, since fzf --ansi speaks SGR) and
# the on-disk cache live in herdr_gitmux.py, shared with the sidebar poller that writes
# this cache. Only the gitmux SYMBOLS are shown, on the workspace-name line; the branch
# is dropped. Degrades gracefully: no gitmux/git -> just name + path.
#
# Layout: ⚡ name+symbols │ path. Glyphs sit INLINE in the name column (name clips to NAME_W - sw - 1 so status stays visible); they are ambiguous-width, so a row measured wrong now shifts ITS path cell.
import sys as _sys
_sys.dont_write_bytecode = True                                    # keep __pycache__ out of the scripts dir
_sys.path.insert(0, os.path.expanduser("~/.local/bin/mux/herdr"))
import herdr_gitmux as hg   # gitmux parsing + the status cache, shared with herdr-git-status.sh
NAME_W, PATH_W = 38, 40  # per-section clip thresholds (columns); NAME_W now holds name + inline symbols
SYM_W, dwidth = hg.SYM_W, hg.dwidth

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

import time
SEP = "❯"

# Representative cwd per open workspace (from its panes); the same walk picks up the focused ids.
wscwd = {}
focus = ("", "", "")
for pn in (load("pn") or {}).get("result", {}).get("panes", []):
    w = pn.get("workspace_id"); c = (pn.get("foreground_cwd") or pn.get("cwd") or "").rstrip("/")
    if w and c and w not in wscwd: wscwd[w] = c
    if pn.get("focused"):
        focus = (pn.get("pane_id") or "", pn.get("tab_id") or "", w or "")

# All width N/Na so columns hold; working is steady (fzf is static, a spinner would sit frozen) and blocked is ! since ❯ is the column separator.
AGENT_GLYPH = {"working": "➤", "blocked": "!", "done": "✔", "idle": "✓"}
# The four herdr state colours ([theme.custom] green/yellow/red/teal, mirrored by the $si_* sidebar slots) - keep in sync or the picker and sidebar disagree.
AGENT_COLOR = {
    "working": tc(os.environ.get("WORKING")), "blocked": tc(os.environ.get("BLOCKED")),
    "done":    tc(os.environ.get("DONE")),    "idle":    tc(os.environ.get("IDLING")),
}
work_col, personal_col = tc(os.environ.get("WORKACCT")), tc(os.environ.get("PERSONALACCT"))
agents_by_tab = {}
for ag in (load("ag") or {}).get("result", {}).get("agents", []):
    t = ag.get("tab_id")
    if t: agents_by_tab.setdefault(t, []).append(ag)
for lst in agents_by_tab.values():
    lst.sort(key=lambda a: a.get("pane_id") or "")

# Only tabs that actually hold an agent - a plain shell tab would just pad the picker.
tabs_by_ws = {}
for tb in (load("tb") or {}).get("result", {}).get("tabs", []):
    if agents_by_tab.get(tb.get("tab_id")):
        tabs_by_ws.setdefault(tb.get("workspace_id"), []).append(tb)
for lst in tabs_by_ws.values():
    lst.sort(key=lambda t: (t.get("number") or 0, t.get("tab_id") or ""))

# Connectors live INSIDE the name column so the ❯ separator holds its screen column at any depth.
def tree_row(prefix, text, tcol, right, rcol, target, name=None, tail="", tailcol="", path=""):
    lab = dclip(prefix + text, NAME_W)
    nm = "%s%s%s%s%s%s" % (dim, prefix, tcol, lab[len(prefix):], RESET,
                           " " * max(NAME_W - dwidth(lab), 0))
    # `tail` rides inside the state cell rather than claiming a column of its own.
    r = dclip(right, PATH_W)
    t = dclip(tail, max(PATH_W - dwidth(r) - 3, 0)) if (tail and r) else ""
    cell = "%s%s%s" % (rcol, r, RESET)
    if t: cell += "%s · %s%s%s" % (dim, tailcol or dim, t, RESET)
    cell += " " * max(PATH_W - dwidth(r) - (dwidth(t) + 3 if t else 0), 0)
    body = "%s %s  %s  %s" % (" " * ICON_W, nm, sep, cell)
    return (name or text) + TAB + body + TAB + path + TAB + target

# Account = which config root owns the session.
CLAUDE_ROOTS = [(os.path.join(home, ".claude-work"), "work"), (os.path.join(home, ".claude"), "personal")]

def claude_account(sess, cwd):
    kind, val = sess.get("kind"), sess.get("value") or ""
    if not val: return ""
    if kind == "path":
        return next((a for root, a in CLAUDE_ROOTS if val.startswith(root + os.sep)), "")
    if kind != "id": return ""
    slug = cwd.replace("/", "-").replace(".", "-").replace("_", "-")   # the projects/ dir name claude derives from a cwd
    for root, acct in CLAUDE_ROOTS:
        if os.path.exists(os.path.join(root, "projects", slug, val + ".jsonl")): return acct
    import glob   # only reached when the session has since changed directory
    for root, acct in CLAUDE_ROOTS:
        # escape: an id carrying a glob metachar would otherwise match a stranger session and mislabel the row.
        if glob.glob(os.path.join(root, "projects", "*", glob.escape(val) + ".jsonl")): return acct
    return ""

# Colored blue (work) / purple (personal), the account convention.
def agent_identity(ag):
    harness = (ag.get("agent") or "").strip()
    if harness != "claude": return harness, dim
    acct = claude_account(ag.get("agent_session") or {}, (ag.get("cwd") or ag.get("foreground_cwd") or "").rstrip("/"))
    if not acct: return harness, dim
    return "%s/%s" % (harness, acct), (work_col if acct == "work" else personal_col)

def agent_rows(wid, pad=0):
    out = []
    # Clears the parent'"'"'s alias chip so the tree hangs off its name, not the chip.
    sp = " " * pad
    # Children inherit the workspace cwd, so a git action fires on the same repo from any row of the tree.
    wpath = (wscwd.get(wid) or "").rstrip("/")
    tabs = tabs_by_ws.get(wid, [])
    for ti, tb in enumerate(tabs):
        tlast = ti == len(tabs) - 1
        kids = agents_by_tab.get(tb.get("tab_id"), [])
        label = (tb.get("label") or ("t%s" % (tb.get("number") or "?"))).strip()
        out.append(tree_row(sp + "%s " % ("└─" if tlast else "├─"), label, fg, "", dim,
                            "tab:" + (tb.get("tab_id") or ""), path=wpath))
        stem = sp + ("   " if tlast else "│  ")
        for ai, ag in enumerate(kids):
            st = ag.get("agent_status") or "unknown"
            col = AGENT_COLOR.get(st) or dim
            title = (ag.get("title") or ag.get("terminal_title_stripped") or ag.get("pane_id") or "?").strip()
            act = ((ag.get("tokens") or {}).get("act") or "").strip()
            state = ("%s · %s" % (st, act)) if act else st
            branch = "└─" if ai == len(kids) - 1 else "├─"
            ident, icol = agent_identity(ag)
            out.append(tree_row("%s%s " % (stem, branch),
                                "%s %s" % (AGENT_GLYPH.get(st, "✧"), title), col,
                                state, col, "agent:" + (ag.get("pane_id") or ""), name=title,
                                tail=ident, tailcol=icol, path=wpath))
    return out

def split_label(s):  # "🌿 chezmoi" -> ("🌿", "chezmoi"); "chezmoi" -> ("", "chezmoi")
    i = 0
    while i < len(s) and not (s[i].isalnum() or s[i] in "._-/~"): i += 1
    return s[:i].strip(), (s[i:] or s)

# Mirrors the herdr-sesh-layout.sh naming rule - keep in sync; full keeps the ticket tail, else the bare number.
def derive_name(cwd, full):
    d = (cwd or "").rstrip("/")
    hm = home.rstrip("/")
    if hm and d.startswith(hm + "/Developer/"):
        segs = [s for s in d[len(hm) + 11:].split("/") if s][:3]
        if len(segs) == 3:
            m = re.match(r"^([A-Z]+)-([0-9]+)", segs[2])
            if m: segs[2] = segs[2][len(m.group(1)) + 1:] if full else m.group(2)
        return "/".join(segs)
    if hm and d.startswith(hm + "/"):
        segs = [s for s in d[len(hm) + 1:].split("/") if s]
        return segs[-1] if len(segs) >= 3 else "/".join(segs)
    return os.path.basename(d)

# sesh already tags each row config/zoxide, so a second probe for the curated paths is redundant.
sesh_entries = load("en") or []
cfg_paths = {(e.get("Path", "") or "").rstrip("/") for e in sesh_entries if e.get("Src") == "config"}
# The identity map: Name -> Path, and Path -> every Name sitting at it. A path holding two names
# (the firstmate personal/work pair) can no longer name a session on its own - that is the whole
# reason resolve_entry asks the label first.
cfg_names, names_by_path = {}, {}
for e in sesh_entries:
    if e.get("Src") != "config": continue
    nm, p = (e.get("Name") or "").strip(), (e.get("Path") or "").rstrip("/")
    if not nm: continue
    cfg_names.setdefault(nm, p)
    # Keyed on the RAW Path, never the realpath: `~/.` (yazi) and `~` (gnohj) are one directory but
    # two deliberate entries, and folding them together would read as a twin and stop suppressing both.
    if p: names_by_path.setdefault(p, []).append(nm)

# Which config entry a workspace IS. Name first, since twins differ only by the label they were
# created with; path second, so every entry alone at its path resolves exactly as it always has.
# A hand-renamed workspace falls back to the path rule, ambiguous again for a twin - the stated
# limit of carrying identity on a label, and it degrades to showing both rows, not to a crash.
def resolve_entry(lname, cwd):
    if lname and lname in cfg_names: return lname
    for k in (cwd, real(cwd) if cwd else ""):
        got = names_by_path.get(k) if k else None
        if got and len(got) == 1: return got[0]
    return ""

# Collect every entry uniformly: (kind, icon, name, path, target, active, entry).
#   ws  ⚡ open herdr workspaces      cfg ⚙️ sesh config dirs      zox 📁 zoxide dirs
entries = []
active_paths, active_names = set(), set()
for w in (load("ws") or {}).get("result", {}).get("workspaces", []):
    wid = w.get("workspace_id")
    # This picker builds its own git column from the cwd, so strip any " · <symbols>"
    # suffix a workspace label may carry to avoid a doubled/clipped name.
    label = (w.get("label", "?") or "?").split(" · ", 1)[0].rstrip()
    cwd = wscwd.get(wid, "").rstrip("/")
    deco, lname = split_label(label)
    # No second row here, so re-expand the ticket tail - but only if the label is still the derived short form.
    if cwd:
        if lname == derive_name(cwd, False):
            label = ("%s %s" % (deco, derive_name(cwd, True))).strip()
        active_paths.update((cwd, real(cwd)))
    ent = resolve_entry(lname, cwd)
    if ent: active_names.add(ent)
    entries.append(("ws", "🖥️" if cwd == home.rstrip("/") else "⚡", label, cwd, "ws:" + wid, True, ent))

seen_names, seen_paths = set(), set()
for e in sesh_entries:
    p = (e.get("Path", "") or "").rstrip("/")
    if not p: continue
    nm = (e.get("Name") or "").strip()
    if e.get("Src") == "config":
        if not nm or nm in seen_names: continue
        # Suppress a config entry only when an open workspace resolved to THAT entry, so one twin
        # being open stops hiding the other. The path test still covers entries no workspace
        # resolved to, but never a shared path - that collapse is what this change undoes.
        if nm in active_names: continue
        if len(names_by_path.get(p, [nm])) == 1 and (p in active_paths or real(p) in active_paths): continue
        seen_names.add(nm); seen_paths.add(p)
        kind, icon, name, ent = "cfg", "⚙️", nm, nm                             # nice config name
    else:
        if p in seen_paths or p in active_paths or real(p) in active_paths: continue
        seen_paths.add(p)
        nms = names_by_path.get(p, [])
        # A zoxide row on a curated path still reads ⚙️, but can only carry an entry target when that path names exactly one.
        if p in cfg_paths and len(nms) == 1:
            kind, icon, name, ent = "cfg", "⚙️", nms[0], nms[0]
        else:
            kind, icon, name, ent = "zox", "📁", (os.path.basename(p) or p), ""  # dir basename, not full path
    # The target IS the identity: a path repeats across twins, so config rows key on Name and only zoxide rows stay path-keyed.
    entries.append((kind, icon, name, p, ("cfg:" + ent) if ent else (kind + ":" + p), False, ent))

# gitmux symbols for EVERY path so non-active repos show status too. Two problems this
# guards against: (1) running gitmux serially on ~100 dirs would freeze the picker, so
# compute in a thread pool (subprocess releases the GIL); (2) a fresh compute on every
# open / ctrl-d reload is wasteful, so cache per-path with a short TTL. Slightly stale
# symbols (< TTL) are fine for a picker.
#
# The ⚡ ACTIVE rows are not on that lazy path at all: herdr-git-status.sh already runs
# gitmux over every open workspace every few seconds for the sidebar `$git` token, and
# writes those same entries into this cache. So active rows are <= one poll old and read
# identically here and in the sidebar. What follows only has to cover the rest.
TTL = 30.0
now = time.time()
cache = hg.load()
paths = [en[3] for en in entries if en[3]]

# roots_only off for active paths: only a handful, and a workspace sitting in a subdir of
# a repo must still report, the way the sidebar poller does for the very same cwd.
def compute(p):
    return p, hg.entry(hg.git_pairs(p, roots_only=p not in active_paths)[1], now)

# WARM pass (spawned detached by build_list): refresh entries older than TTL and drop paths no
# longer listed, then exit WITHOUT rendering. Runs off the render path so opening stays instant;
# it is what keeps the shown (possibly stale) symbols fresh. flock => only one warm at a time.
if os.environ.get("WARM") == "1":
    import fcntl
    lock = open(hg.CACHE + ".lock", "a+")
    try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError: raise SystemExit(0)      # another warm already running
    todo = [p for p in dict.fromkeys(paths) if not (cache.get(p) and now - cache[p][0] < TTL)]
    if todo:
        from concurrent.futures import ThreadPoolExecutor
        # Smaller pool than the render path below: this refresh has no deadline, so trade wall clock for staying out of the way of the picker you are scrolling.
        with ThreadPoolExecutor(max_workers=6) as ex:
            fresh = dict(ex.map(compute, todo))
        hg.update(fresh, keep=set(paths))    # merge under the write lock; prune vanished paths
    raise SystemExit(0)

# Render path. Show cached symbols REGARDLESS of age — stale is fine (the poller keeps the
# active rows current and the bg warm refreshes the rest), and never hiding them is what
# stops the picker rendering blank after a short idle. Only entries genuinely MISSING from
# the cache are computed synchronously; that is just the first open (they then persist), and
# non-roots resolve instantly (git_pairs skips them). So: never blank, and fast afterwards.
missing = [p for p in dict.fromkeys(paths) if p not in cache]
if missing:
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=16) as ex:
        fresh = dict(ex.map(compute, missing))
    cache.update(fresh)
    hg.update(fresh)
sym = {}
for p in paths:
    hit = cache.get(p)
    if hit: sym[p] = (hit[1], hit[2], hit[3] if len(hit) > 3 else False)

# Sort: active, repos with git activity (hg.has_changes - working tree plus ahead/behind), sesh.toml config, rest — fzf tiebreaks on this input index.
# NOTE: this python block is inside a single-quoted bash string, so an apostrophe here ends it - keep comments apostrophe-free.
def prio(ie):
    i, en = ie
    if en[5]: return (0, i)                                     # active
    if sym.get(en[3], ("", 0, False))[2]: return (1, i)         # dirty / unpushed / unpulled
    if en[0] == "cfg": return (2, i)                            # curated sesh.toml entries
    return (3, i)

# Render: <emoji> name ❯ path ❯ symbols — one emoji per row (label glyph else kind icon), DISPLAY-width padded so columns align.
sep = "%s%s%s" % (dim, SEP, RESET)
ICON_W = 2   # one emoji, 2 display columns

# What the git view watches, mirroring compute(): active rows count from anywhere inside a checkout, the rest only at its root.
def in_repo(p):
    d = p
    while d and d != "/":
        if os.path.exists(os.path.join(d, ".git")): return True
        d = os.path.dirname(d)
    return False

def watched(p, active):
    if not p: return False
    return in_repo(p) if active else os.path.exists(os.path.join(p, ".git"))

# ctrl-g filters HERE rather than in fzf so --view matching, the cursor file and the target dispatch all keep working on a smaller ROWS file.
ordered = [en for _, en in sorted(enumerate(entries), key=prio)]
if os.environ.get("SESH_GIT_ONLY") == "1":
    dirty = [en for en in ordered if sym.get(en[3], ("", 0, False))[2]]
    # Nothing dirty lists every repo watched instead of a blank screen; the count rides CLEAN_FILE out to the header.
    ordered = dirty if dirty else [en for en in ordered if watched(en[3], en[5])]
    cpath = os.environ.get("CLEAN_FILE")
    if cpath:
        try:
            with open(cpath, "w") as fh: fh.write("" if dirty else str(len(ordered)))
        except Exception: pass

for kind, icon, label, path0, target, active, ent in ordered:
    scol, sw = sym.get(path0, ("", 0, False))[:2]
    deco, name = split_label(label)
    # Name lookup first, so twins show their own chip instead of whichever the shared path last wrote.
    al = (alias_by_name.get(ent) if ent else "") or alias_by_path.get(path0, "")
    chip = ("[%s]" % al).ljust(ALIAS_W + 2) if al else ""
    cw = dwidth(chip) + 1 if chip else 0
    icol = accent if active else dim
    ncol = (BOLD + fg) if active else fg
    ic = "%s%s%s" % (icol, dpad(deco or icon, ICON_W), RESET)
    # Symbols and the alias chip claim their width first; the name clips into what is left so neither is cut.
    budget = NAME_W - (sw + 1 if sw else 0) - cw
    lab = dclip(name, max(budget, 1))
    used = dwidth(lab) + (sw + 1 if sw else 0) + cw
    nm = "%s%s%s%s%s%s" % ((accent + chip + RESET + " ") if chip else "", ncol, lab, RESET,
                          (" " + scol) if sw else "", " " * max(NAME_W - used, 0))
    pth = "%s%s%s" % (dim, dpad(dclip(short(path0), PATH_W, left=True), PATH_W), RESET)
    # Field 1 (plain name) is what --view matches against, so queries never hit the path column. Field 3 is the raw path ctrl-f/ctrl-p act on; the target stays LAST so fzf {-1} and the awk $NF still find it.
    # The alias rides in field 1 too, so typing it narrows THIS row rather than surfacing a second one.
    rows.append((name + " " + al if al else name) + TAB + ("%s %s  %s  %s" % (ic, nm, sep, pth)) + TAB + path0 + TAB + target)
    if kind == "ws":
        rows.extend(agent_rows(target[3:], cw))

# Guarded: joining an empty list still prints a newline, which fzf counts as one blank row.
if rows:
    print("\n".join(rows))

# Cursor row: focused pane'"'"'s agent row, else its tab, else its workspace - a popup overlays a pane, so the walk above still sees it (as in herdr-scrollback.sh); HERDR_* env is the fallback.
fpath = os.environ.get("FOCUS_FILE")
if fpath:
    pane, tab, ws = (a or os.environ.get(b, "") for a, b in
                     zip(focus, ("HERDR_PANE_ID", "HERDR_TAB_ID", "HERDR_WORKSPACE_ID")))
    at = {}
    for n, r in enumerate(rows, 1): at.setdefault(r.rsplit(TAB, 1)[-1], n)
    want = [k + ":" + v for k, v in (("agent", pane), ("tab", tab), ("ws", ws)) if v]
    with open(fpath, "w") as fh:
        fh.write("%d\n" % next((at[t] for t in want if t in at), 1))
'
  rm -rf "$src"
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
  --view)
    # fzf matches line by line and cannot keep a hierarchy, so the picker runs --disabled and routes every keystroke here: fzf still MATCHES, we re-emit in order and borrow a hit's ancestors.
    ROWS="${2:-}"
    VIEW="${3:-}"
    Q="${4:-}"
    if [ "${5:-}" = --rebuild ]; then
      [ -f "$HOME/.config/colorscheme/active/active-colorscheme.sh" ] &&
        source "$HOME/.config/colorscheme/active/active-colorscheme.sh"
      build_list >"$ROWS"
    fi
    if [ ! -s "$ROWS" ]; then
      : >"$VIEW"
      POS=1
    elif [ -z "$Q" ]; then
      cp "$ROWS" "$VIEW"
      POS=1
    else
      # No --with-nth: --nth binds to the transform when one is set, so dropping it aims --nth=1 at raw field 1 (plain name) and leaves the path column unsearchable.
      # $ROWS is read first (guaranteed non-empty above) so FNR==NR still means "first file" when nothing matched.
      POS=$(fzf --ansi --delimiter='\t' --nth=1 --no-sort --filter="$Q" <"$ROWS" \
        | awk -F'\t' -v out="$VIEW" -v q="$Q" '
FNR == NR {
  line[FNR] = $0; tgt[FNR] = $NF; n = FNR
  # An exactly-typed alias parks the cursor on its row whatever else fuzzy-matched.
  nw = split($1, w, " ")
  if (nw > 1 && w[nw] == q) aliasrow[FNR] = 1
  # Ancestors come from POSITION not from parsing ids: rows are emitted parent-first, so a row belongs to the nearest preceding ws:/tab: row.
  if ($NF ~ /^ws:/)         { ws = FNR; tab = 0 }
  else if ($NF ~ /^tab:/)   { tab = FNR; up1[FNR] = ws }
  else if ($NF ~ /^agent:/) { up1[FNR] = ws; up2[FNR] = tab }
  next
}
{ sel[$NF] = 1 }
END {
  for (i = 1; i <= n; i++)
    if (tgt[i] in sel) { keep[i] = 1; if (up1[i]) keep[up1[i]] = 1; if (up2[i]) keep[up2[i]] = 1 }
  printf "" >out                 # truncate even when nothing matched
  pos = 1
  for (i = 1; i <= n; i++) {
    if (!(i in keep)) continue
    print line[i] >out
    # 1-based cursor position of the first genuine hit; borrowed ancestors are context, not hits.
    k++
    if (!hit && (tgt[i] in sel)) { pos = k; hit = 1 }
    if (i in aliasrow) apos = k
  }
  if (apos) pos = apos
  close(out)
  print pos
}' "$ROWS" -)
    fi
    # pos() is UNCONDITIONAL: reload-sync keeps the old cursor index, so without it the cursor drifts as the query narrows.
    printf 'reload-sync(cat %s)+pos(%s)\n' "$VIEW" "${POS:-1}"
    exit 0
    ;;
  --git)
    # Runs in the path field 3 carries; fzf already trims that field, but a stray tab is stripped so it can never reach git as part of a path.
    ACTION="${2:-}"
    GPATH="${3:-}"
    GPATH="${GPATH%%$'\t'*}"
    # Only reached on a failure, so the message survives fzf redrawing over this screen.
    pause() { printf '\n[press any key] '; read -rsn1 -t 30 _ 2>/dev/null; echo; }

    [ -n "$GPATH" ] || { echo "no directory on this row"; pause; exit 0; }
    git -C "$GPATH" rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo: $GPATH"; pause; exit 0; }
    # A treekanga container (.bare + worktrees) is a BARE repo, where --show-toplevel fatals - falling back to the dir itself keeps those rows working.
    ROOT=$(git -C "$GPATH" rev-parse --show-toplevel 2>/dev/null)
    [ -n "$ROOT" ] || ROOT="$GPATH"
    BRANCH=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
    # Which worktree holds the branch, so a bare container acts on its checkout instead of a ref git refuses to touch.
    WT=$(git -C "$ROOT" worktree list --porcelain 2>/dev/null |
      awk -v b="branch refs/heads/$BRANCH" '/^worktree /{p=substr($0,10)} $0==b{print p; exit}')
    # Same reason lazygit-herdr.sh sets it: without this a pull fires web's post-merge `pnpm i` + build-packages on every keypress.
    export HUSKY=0
    printf '\033[1m%s\033[0m  %s\n\n' "${ROOT/#$HOME/\~}" "$BRANCH"

    rc=0
    case "$ACTION" in
      pull)
        # lazygit's f is fastForward(), not a bare fetch: pull --ff-only inside whichever worktree holds the branch, and a ref-only fast-forward only when no worktree does.
        UP=$(git -C "$ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
        AHEAD=$(git -C "$ROOT" rev-list --count "$UP..HEAD" 2>/dev/null)
        if [ -z "$UP" ]; then
          echo "no upstream for $BRANCH - nothing to fast-forward"; rc=1
        elif [ "${AHEAD:-0}" != 0 ]; then
          # lazygit refuses outright here; fetching anyway costs nothing and is what refreshes the row's counts.
          echo "❯ git fetch   (ahead $AHEAD, so no fast-forward - push or rebase first)"
          git -C "$ROOT" fetch || rc=$?
        elif [ -n "$WT" ]; then
          # Not necessarily $ROOT: a bare container's branch is checked out in a SIBLING worktree, and git refuses to fetch into a ref that is.
          echo "❯ git -C ${WT/#$HOME/\~} pull --ff-only"
          git -C "$WT" pull --ff-only || rc=$?
        else
          echo "❯ git fetch ${UP%%/*} ${UP#*/}:$BRANCH"
          git -C "$ROOT" fetch "${UP%%/*}" "${UP#*/}:$BRANCH" || rc=$?
        fi
        ;;
      push)
        if git -C "$ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
          echo "❯ git push"
          git -C "$ROOT" push || rc=$?
        elif [ -z "$BRANCH" ] || [ "$BRANCH" = HEAD ]; then
          echo "detached HEAD - nothing to push"; rc=1
        else
          # Creating the remote branch is the one outward-facing step here, so it asks first (as lazygit does).
          printf 'no upstream - push and set origin/%s? [y/N] ' "$BRANCH"
          read -r ANS
          case "$ANS" in
            [yY]*) echo "❯ git push -u origin $BRANCH"; git -C "$ROOT" push -u origin "$BRANCH" || rc=$? ;;
            *) echo "skipped" ;;
          esac
        fi
        ;;
      lazygit)
        # cd, not -p: lazygit's -p expands to --git-dir=<dir>/.git/, which fatals on a linked worktree where .git is a FILE. ${WT:-$ROOT} also keeps a bare container opening the checkout that holds its branch.
        if command -v lazygit >/dev/null 2>&1; then
          (cd "${WT:-$ROOT}" && lazygit) || true
        else
          echo "lazygit not found"; rc=1
        fi
        ;;
      *) echo "unknown git action: $ACTION"; rc=1 ;;
    esac

    # Forgetting beats recomputing here: the caller's --rebuild refills it under build_list's own roots_only rule.
    python3 -c '
import sys, os
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.expanduser("~/.local/bin/mux/herdr"))
import herdr_gitmux as hg
hg.drop(sys.argv[1:])
' "$GPATH" "$ROOT" 2>/dev/null

    [ "$rc" = 0 ] || pause
    exit 0
    ;;
  --delete)
    case "${2:-}" in
      ws:* | agent:*)
        # Closing a workspace (or the last pane in one) shifts herdr's focus even when it wasn't focused, and the picker overlays the current workspace — so capture focus first and restore it unless it is the one being deleted.
        target="${2#*:}"
        wid="${target%%:*}" # both ids read "<wid>[:<inner>]", so the workspace is the first field
        focused=""
        if command -v jq >/dev/null 2>&1; then
          focused=$("$herdr" workspace list 2>/dev/null \
            | jq -r '.result.workspaces[] | select(.focused) | .workspace_id' 2>/dev/null)
        fi
        case "$2" in
          ws:*) "$herdr" workspace close "$target" >/dev/null 2>&1 ;;
          *)    "$herdr" pane close "$target" >/dev/null 2>&1 ;;
        esac
        [ -n "$focused" ] && [ "$focused" != "$wid" ] &&
          "$herdr" workspace focus "$focused" >/dev/null 2>&1
        ;;
      zox:*) zoxide remove "${2#zox:}" >/dev/null 2>&1 ;;
      cfg:*) : ;;  # config entries live in sesh.toml — not deletable from the picker
      tab:*) : ;;  # a whole tab of agents is too blunt for ctrl-d; kill its panes instead
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

# Built ONCE per open; --view re-reads this instead of re-querying herdr and gitmux. Per-PID so two open pickers cannot collide.
ROWS_FILE="${TMPDIR:-/tmp}/herdr-sesh-rows.$$"
VIEW_FILE="${TMPDIR:-/tmp}/herdr-sesh-view.$$"
# Set only for the interactive open, so --list/--warm/--rebuild skip the cursor lookup.
export FOCUS_FILE="${TMPDIR:-/tmp}/herdr-sesh-pos.$$"
# The watched-repo count when the git view found nothing dirty; the header reads it.
export CLEAN_FILE="${TMPDIR:-/tmp}/herdr-sesh-clean.$$"
trap 'rm -f "$ROWS_FILE" "$VIEW_FILE" "$FOCUS_FILE" "$CLEAN_FILE"' EXIT

# Looped so ctrl-g can re-enter with a different view, and so the picker comes back after lazygit exits. esc no longer returns here from a sub-menu: it closes the popup from wherever you are.
# GIT_ONLY rides the same loop: ctrl-g flips it and re-enters, so the filter is a rebuild rather than an fzf-side query.
GIT_ONLY=0
while true; do
  # Exported, not a prefix assignment: ctrl-d's --rebuild re-runs build_list in a CHILD $SELF.
  export SESH_GIT_ONLY="$GIT_ONLY"
  build_list >"$ROWS_FILE"
  # Nothing dirty says so in the header and lists what was watched, instead of a bare 0/0 or a silent revert to the full list.
  HEADER=()
  if [ "$GIT_ONLY" = 1 ]; then
    PROMPT='󰊢 '
    # The keys work in the full list too, but this is the view they are FOR, so only it spends a header line on them.
    HINT='ctrl-f pull · ctrl-p push · ctrl-g lazygit · esc close'
    CLEAN=$(cat "$CLEAN_FILE" 2>/dev/null) || CLEAN=""
    if [ -n "$CLEAN" ] && [ "$CLEAN" != 0 ]; then
      HEADER=(--header "󰊢 all clean - nothing to commit, push or pull · watching $CLEAN repos · $HINT")
    elif [ -n "$CLEAN" ]; then
      HEADER=(--header '󰊢 no git repos in this list')
    else
      HEADER=(--header "󰊢 $HINT")
    fi
  else
    PROMPT='⚡ '
  fi
  START_POS=$(cat "$FOCUS_FILE" 2>/dev/null) || START_POS=1
  [ -n "$START_POS" ] || START_POS=1
  # --disabled hands matching to $SELF --view so a hit can bring its ancestors; the trade is losing fzf's match highlighting.
  # --no-sort (as in sesh-popup.sh) keeps build_list's ⚡/⚙️ grouping under every query; tiebreak=index could not, since index only breaks SCORE ties.
  OUT=$(fzf <"$ROWS_FILE" \
    --no-border --ansi --layout=reverse --list-border --no-sort \
    --prompt "$PROMPT" --gutter=' ' --color "$color_string" \
    --input-border --header-border "${HEADER[@]}" \
    --delimiter='\t' --with-nth=2 --nth=1 \
    --disabled \
    --expect=ctrl-w,ctrl-g \
    --sync \
    --bind "start:pos($START_POS)" \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-j:down,ctrl-k:up' \
    --bind 'ctrl-b:abort' \
    --bind "change:transform($SELF --view $ROWS_FILE $VIEW_FILE {q})" \
    --bind "ctrl-d:execute-silent($SELF --delete {-1})+transform($SELF --view $ROWS_FILE $VIEW_FILE {q} --rebuild)" \
    --bind "ctrl-f:execute($SELF --git pull {3})+transform($SELF --view $ROWS_FILE $VIEW_FILE {q} --rebuild)" \
    --bind "ctrl-p:execute($SELF --git push {3})+transform($SELF --view $ROWS_FILE $VIEW_FILE {q} --rebuild)")

  # With --expect, line 1 is the pressed key (blank on plain enter) and line 2 the selection; on esc both come back empty.
  KEY=$(printf '%s' "$OUT" | head -1)
  SELECTED=$(printf '%s\n' "$OUT" | sed -n '2p')

  # ctrl-g means "git" in both views: turn the git filter on from the full list, open the row's lazygit once already in it.
  if [ "$KEY" = "ctrl-g" ]; then
    # Deliberately one-way: the git view is now a leaf, left by acting on a row or by esc closing the popup.
    if [ "$GIT_ONLY" = 1 ] && [ -n "$SELECTED" ]; then
      LGPATH=$(printf '%s' "$SELECTED" | cut -f3)
      [ -n "$LGPATH" ] && "$SELF" --git lazygit "$LGPATH"
      rm -f "$FOCUS_FILE"
      continue
    fi
    [ "$GIT_ONLY" = 1 ] && GIT_ONLY=0 || GIT_ONLY=1
    rm -f "$FOCUS_FILE"   # the cursor row is meaningless once the list changes shape
    continue
  fi

  if [ "$KEY" = "ctrl-w" ]; then
    # Worktrees scanned live from git; worktree-list emits "<glyph> <name>\t<abs-path>", 🌳 linked / 🌿 the repo's own checkout, grouped by repo.
    WT=$(worktree-list | fzf \
      --no-border --ansi --layout=reverse --list-border --tiebreak=begin \
      --prompt '🌳 ' --gutter=' ' --color "$color_string" \
      --input-border --header-border \
      --delimiter='\t' --with-nth=1 \
      --bind 'tab:down,btab:up' \
      --bind 'ctrl-j:down,ctrl-k:up' \
      --bind 'ctrl-b:abort')
    if [ -n "$WT" ]; then
      WT_PATH="${WT##*$'\t'}"
      # Seed zoxide on entry (_ZO_DATA_DIR is exported above) so the worktree shows in the default view immediately - the chpwd hook only fires on a later cd.
      zoxide add "$WT_PATH" 2>/dev/null
      rm -f "$ROWS_FILE" "$VIEW_FILE" "$FOCUS_FILE"   # exec replaces us, so the EXIT trap never runs
      exec "$HOME/.local/bin/mux/herdr/herdr-sesh-layout.sh" "$WT_PATH"
    fi
    # esc in the worktree view closes the popup outright rather than re-showing the picker behind it.
    exit 0
  fi

  # esc (and ctrl-b) closes the popup from every view, the git and worktree menus included.
  [ -z "$SELECTED" ] && exit 0

  TARGET="${SELECTED##*$'\t'}"
  rm -f "$ROWS_FILE" "$VIEW_FILE" "$FOCUS_FILE"   # every branch below execs or exits, and exec loses the EXIT trap
  case "$TARGET" in
    ws:*)          exec "$herdr" workspace focus "${TARGET#ws:}" ;;
    agent:* | tab:*)
      # Focus the workspace first (ids are "<wid>:<...>"); focusing an inner target alone is not guaranteed to carry the view across workspaces.
      inner="${TARGET#*:}"
      "$herdr" workspace focus "${inner%%:*}" >/dev/null 2>&1
      case "$TARGET" in
        tab:*) exec "$herdr" tab focus "$inner" ;;
        *) exec "$herdr" agent focus "$inner" ;;
      esac
      ;;
    cfg:*)         exec "$HOME/.local/bin/mux/herdr/herdr-sesh-layout.sh" --entry "${TARGET#cfg:}" ;;
    zox:*)         exec "$HOME/.local/bin/mux/herdr/herdr-sesh-layout.sh" "${TARGET#zox:}" ;;
    *)             exit 0 ;;
  esac
done
