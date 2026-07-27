#!/usr/bin/env bash
# herdr-sesh.sh — sesh-style session picker for herdr (the ctrl+t navigator, the
# herdr-native replacement for the tmux sesh popup). Runs as a herdr `type = "pane"`
# command (zoom overlay like ctrl+g/ctrl+y) → server-side, so it works local AND
# over --remote.
#
# It reuses `sesh list -c -z --icons` verbatim, so config entries come straight from
# sesh.toml (⚙️ gear) and recent dirs from the zoxide DB (📁 folder) — LIVE, no
# re-authoring. On top it pins herdr's OPEN workspaces (🌳/🌿/📁 glyph, else ⚡), queried fresh
# each open. Theme matches the tmux sesh popup (dot_config/tmux/sesh-popup.sh).
#
#   enter   → focus an open workspace, else open the dir with the sesh dev layout
#             (herdr-sesh-layout.sh: pen nvim + fish shells; attaches if already open)
#   ctrl-d  → delete the highlighted item WITHOUT closing the picker: close a workspace (⚡), one agent's pane, or a zoxide dir (📁). ⚙️ config is left alone (it lives in sesh.toml); the list reloads in place.
#   ctrl-b  → abort
#
# Subcommands (used by fzf's reload/execute binds, not called directly):
#   --list            print the merged rows ("<display>\t<kind>:<target>")
#   --delete <target> delete one "<kind>:<target>"
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
  ACTIVE_WS="$("$herdr" workspace list 2>/dev/null)" \
  PANES="$("$herdr" pane list 2>/dev/null)" \
  AGENTS="$("$herdr" agent list 2>/dev/null)" \
  TABS="$("$herdr" tab list 2>/dev/null)" \
  ENTRIES="$(sesh list -c -z -j 2>/dev/null)" \
  CFGPATHS="$(sesh list -c -j 2>/dev/null)" \
  FG="${gnohj_color02:-}" DIM="${gnohj_color09:-}" ACCENT="${gnohj_color04:-}" \
  WORKING="${gnohj_color04:-}" BLOCKED="${gnohj_color11:-}" \
  DONE="${gnohj_color11:-}" IDLING="${gnohj_color05:-}" \
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

# Representative cwd per open workspace (from its panes).
wscwd = {}
for pn in (load("PANES") or {}).get("result", {}).get("panes", []):
    w = pn.get("workspace_id"); c = (pn.get("foreground_cwd") or pn.get("cwd") or "").rstrip("/")
    if w and c and w not in wscwd: wscwd[w] = c

# All width N/Na so columns hold; working is steady (fzf is static, a spinner would sit frozen) and blocked is ! since ❯ is the column separator.
AGENT_GLYPH = {"working": "➤", "blocked": "!", "done": "✔", "idle": "✓"}
# The four palette tokens herdr paints state_icon with ([theme.custom] green/yellow/red/teal) - keep in sync or the picker and sidebar disagree.
AGENT_COLOR = {
    "working": tc(os.environ.get("WORKING")), "blocked": tc(os.environ.get("BLOCKED")),
    "done":    tc(os.environ.get("DONE")),    "idle":    tc(os.environ.get("IDLING")),
}
agents_by_tab = {}
for ag in (load("AGENTS") or {}).get("result", {}).get("agents", []):
    t = ag.get("tab_id")
    if t: agents_by_tab.setdefault(t, []).append(ag)
for lst in agents_by_tab.values():
    lst.sort(key=lambda a: a.get("pane_id") or "")

# Only tabs that actually hold an agent - a plain shell tab would just pad the picker.
tabs_by_ws = {}
for tb in (load("TABS") or {}).get("result", {}).get("tabs", []):
    if agents_by_tab.get(tb.get("tab_id")):
        tabs_by_ws.setdefault(tb.get("workspace_id"), []).append(tb)
for lst in tabs_by_ws.values():
    lst.sort(key=lambda t: (t.get("number") or 0, t.get("tab_id") or ""))

# Connectors live INSIDE the name column so the ❯ separator holds its screen column at any depth.
def tree_row(prefix, text, tcol, right, rcol, target, name=None):
    lab = dclip(prefix + text, NAME_W)
    nm = "%s%s%s%s%s%s" % (dim, prefix, tcol, lab[len(prefix):], RESET,
                           " " * max(NAME_W - dwidth(lab), 0))
    body = "%s %s  %s  %s%s%s" % (" " * ICON_W, nm, sep, rcol, dpad(dclip(right, PATH_W), PATH_W), RESET)
    return (name or text) + TAB + body + TAB + target

def agent_rows(wid):
    out = []
    tabs = tabs_by_ws.get(wid, [])
    for ti, tb in enumerate(tabs):
        tlast = ti == len(tabs) - 1
        kids = agents_by_tab.get(tb.get("tab_id"), [])
        label = (tb.get("label") or ("t%s" % (tb.get("number") or "?"))).strip()
        out.append(tree_row(" %s " % ("└─" if tlast else "├─"), label, fg, "", dim,
                            "tab:" + (tb.get("tab_id") or "")))
        stem = "    " if tlast else " │  "
        for ai, ag in enumerate(kids):
            st = ag.get("agent_status") or "unknown"
            col = AGENT_COLOR.get(st) or dim
            title = (ag.get("title") or ag.get("terminal_title_stripped") or ag.get("pane_id") or "?").strip()
            act = ((ag.get("tokens") or {}).get("act") or "").strip()
            state = ("%s · %s" % (st, act)) if act else st
            branch = "└─" if ai == len(kids) - 1 else "├─"
            out.append(tree_row("%s%s " % (stem, branch),
                                "%s %s" % (AGENT_GLYPH.get(st, "✧"), title), col,
                                state, col, "agent:" + (ag.get("pane_id") or ""), name=title))
    return out

# Collect every entry uniformly: (kind, icon, name, path, target, active).
#   ws  ⚡ open herdr workspaces      cfg ⚙️ sesh config dirs      zox 📁 zoxide dirs
entries = []
active_paths = set()
for w in (load("ACTIVE_WS") or {}).get("result", {}).get("workspaces", []):
    wid = w.get("workspace_id")
    # This picker builds its own git column from the cwd, so strip any " · <symbols>"
    # suffix a workspace label may carry to avoid a doubled/clipped name.
    label = (w.get("label", "?") or "?").split(" · ", 1)[0].rstrip()
    cwd = wscwd.get(wid, "").rstrip("/")
    if cwd: active_paths.add(cwd)
    entries.append(("ws", "🖥️" if cwd == home.rstrip("/") else "⚡", label, cwd, "ws:" + wid, True))

cfg_paths = {(e.get("Path", "") or "").rstrip("/") for e in (load("CFGPATHS") or [])}
seen = set()
for e in (load("ENTRIES") or []):
    p = (e.get("Path", "") or "").rstrip("/")
    if not p or p in active_paths or p in seen: continue
    seen.add(p)
    if p in cfg_paths:
        kind, icon, name = "cfg", "⚙️", (e.get("Name") or os.path.basename(p))  # nice config name
    else:
        kind, icon, name = "zox", "📁", (os.path.basename(p) or p)              # dir basename, not full path
    entries.append((kind, icon, name, p, kind + ":" + p, False))

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
paths = [p for _, _, _, p, _, _ in entries if p]

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

# Sort: active, sesh.toml config, repos with REAL changes (stash-only is not one), rest — fzf tiebreaks on this input index.
def prio(ie):
    i, en = ie
    if en[5]: return (0, i)                                     # active
    if en[0] == "cfg": return (1, i)                            # curated sesh.toml entries
    return (2 if sym.get(en[3], ("", 0, False))[2] else 3, i)  # real working-tree changes else rest

# Render: <emoji> name ❯ path ❯ symbols — one emoji per row (label glyph else kind icon), DISPLAY-width padded so columns align.
sep = "%s%s%s" % (dim, SEP, RESET)
ICON_W = 2   # one emoji, 2 display columns

def split_label(s):  # "🌿 chezmoi" -> ("🌿", "chezmoi"); "chezmoi" -> ("", "chezmoi")
    i = 0
    while i < len(s) and not (s[i].isalnum() or s[i] in "._-/~"): i += 1
    return s[:i].strip(), (s[i:] or s)

for kind, icon, label, path0, target, active in [en for _, en in sorted(enumerate(entries), key=prio)]:
    scol, sw = sym.get(path0, ("", 0, False))[:2]
    deco, name = split_label(label)
    icol = accent if active else dim
    ncol = (BOLD + fg) if active else fg
    ic = "%s%s%s" % (icol, dpad(deco or icon, ICON_W), RESET)
    # Symbols claim their width first; the name clips into what is left so status is never cut.
    budget = NAME_W - (sw + 1 if sw else 0)
    lab = dclip(name, max(budget, 1))
    used = dwidth(lab) + (sw + 1 if sw else 0)
    nm = "%s%s%s%s%s" % (ncol, lab, RESET, (" " + scol) if sw else "", " " * max(NAME_W - used, 0))
    pth = "%s%s%s" % (dim, dpad(dclip(short(path0), PATH_W, left=True), PATH_W), RESET)
    # Field 1 (plain name) is inert today: --nth applies to the --with-nth=2 transform, not raw fields. Field 3 stays last for fzf {-1}.
    rows.append(name + TAB + ("%s %s  %s  %s" % (ic, nm, sep, pth)) + TAB + target)
    if kind == "ws":
        rows.extend(agent_rows(target[3:]))

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
      POS=$(fzf --ansi --delimiter='\t' --with-nth=2 --nth=1 --no-sort --filter="$Q" <"$ROWS" \
        | ROWS="$ROWS" VIEW="$VIEW" python3 -c '
import os, sys
sel = {l.rsplit("\t", 1)[-1] for l in sys.stdin.read().splitlines() if l}
with open(os.environ["ROWS"]) as fh:
    lines = fh.read().splitlines()
targets = [l.rsplit("\t", 1)[-1] for l in lines]

# Ancestors come from POSITION not from parsing ids: rows are emitted parent-first, so a row belongs to the nearest preceding ws:/tab: row.
anc, ws, tab = {}, None, None
for i, t in enumerate(targets):
    if t.startswith("ws:"):
        ws, tab, anc[i] = i, None, ()
    elif t.startswith("tab:"):
        tab, anc[i] = i, (ws,) if ws is not None else ()
    elif t.startswith("agent:"):
        anc[i] = tuple(a for a in (ws, tab) if a is not None)
    else:
        anc[i] = ()

keep = set()
for i, t in enumerate(targets):
    if t in sel:
        keep.add(i)
        keep.update(anc[i])
order = sorted(keep)
with open(os.environ["VIEW"], "w") as fh:
    fh.write("".join(lines[i] + "\n" for i in order))
# 1-based cursor position of the first genuine hit; borrowed ancestors are context, not hits.
print(next((n for n, i in enumerate(order, 1) if targets[i] in sel), 1))
')
    fi
    # pos() is UNCONDITIONAL: reload-sync keeps the old cursor index, so without it the cursor drifts as the query narrows.
    printf 'reload-sync(cat %s)+pos(%s)\n' "$VIEW" "${POS:-1}"
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
trap 'rm -f "$ROWS_FILE" "$VIEW_FILE"' EXIT

# Looped so ctrl-w's worktree sub-picker can return here on esc - fzf binds aren't modal, so re-entering the loop is the only way to get "esc = back". Mirrors the tmux sesh popup.
while true; do
  build_list >"$ROWS_FILE"
  # --disabled hands matching to $SELF --view so a hit can bring its ancestors; the trade is losing fzf's match highlighting.
  # --no-sort (as in sesh-popup.sh) keeps build_list's ⚡/⚙️ grouping under every query; tiebreak=index could not, since index only breaks SCORE ties.
  OUT=$(fzf <"$ROWS_FILE" \
    --no-border --ansi --layout=reverse --list-border --no-sort \
    --prompt '⚡ ' --gutter=' ' --color "$color_string" \
    --input-border --header-border \
    --delimiter='\t' --with-nth=2 --nth=1 \
    --disabled \
    --expect=ctrl-w \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-j:down,ctrl-k:up' \
    --bind 'ctrl-b:abort' \
    --bind "change:transform($SELF --view $ROWS_FILE $VIEW_FILE {q})" \
    --bind "ctrl-d:execute-silent($SELF --delete {-1})+transform($SELF --view $ROWS_FILE $VIEW_FILE {q} --rebuild)")

  # With --expect, line 1 is the pressed key (blank on plain enter) and line 2 the selection; on esc both come back empty.
  KEY=$(printf '%s' "$OUT" | head -1)
  SELECTED=$(printf '%s\n' "$OUT" | sed -n '2p')

  if [ "$KEY" = "ctrl-w" ]; then
    # 🌳 worktrees scanned live from git; worktree-list emits "🌳 <name>\t<abs-path>".
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
      rm -f "$ROWS_FILE" "$VIEW_FILE"   # exec replaces us, so the EXIT trap never runs
      exec "$HOME/.local/bin/mux/herdr/herdr-sesh-layout.sh" "$WT_PATH"
    fi
    # esc in the worktree view → fall through and re-show the default picker.
    continue
  fi

  [ -z "$SELECTED" ] && exit 0

  TARGET="${SELECTED##*$'\t'}"
  rm -f "$ROWS_FILE" "$VIEW_FILE"   # every branch below execs or exits, and exec loses the EXIT trap
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
    cfg:*)         exec "$HOME/.local/bin/mux/herdr/herdr-sesh-layout.sh" "${TARGET#cfg:}" ;;
    zox:*)         exec "$HOME/.local/bin/mux/herdr/herdr-sesh-layout.sh" "${TARGET#zox:}" ;;
    *)             exit 0 ;;
  esac
done
