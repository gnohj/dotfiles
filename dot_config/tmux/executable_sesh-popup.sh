#!/usr/bin/env bash
# Shared sesh picker body. Runs INSIDE a tmux display-popup (callers own the
# popup geometry), so $TMUX already points at the correct server/client —
# sesh connect then switches THAT client, with no socket guessing.
#
# One module, two modes, so the theme, keymap, and stamp+connect tail are
# defined once and can't drift:
#   (default)    full picker — every sesh source incl. active sessions, with
#                source-switching binds (ctrl-a/t/g/x/f) and kill (ctrl-d).
#                Callers: skhd rctrl-t wrapper (sesh-switcher.sh) and the tmux
#                status-line click (tmux.conf MouseDown1Status), both 28%x40%.
#   --new-only   config+zoxide entries WITHOUT an active tmux session — places
#                to start a NEW session. Plain list, no source binds (a reload
#                would break the mode's invariant by pulling unfiltered
#                sources back in). Caller: tmux-dash "new session → sesh" via
#                the sesh-new-picker.sh adapter, 45%x65%.

# /opt/homebrew stays first so macOS resolution is unchanged; the Linux dirs
# (linuxbrew / mise shims / ~/.local/bin) are appended for a headless Linux VPS.
export PATH="/opt/homebrew/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
[ "$(uname)" = Linux ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

[ -f "$HOME/.config/colorscheme/active/active-colorscheme.sh" ] &&
  source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

# Detached, non-blocking zoxide reconciliation: seed any git worktree not yet
# in zoxide so the default view + `z` stay complete (catches worktrees made
# outside treekanga). Reparented via the subshell so it survives this popup
# closing. Refreshes the NEXT picker open, never blocks this one. ctrl-w's
# live scan is independent of this.
( wtsync >/dev/null 2>&1 & ) 2>/dev/null

# Canonical picker theme (the rctrl-t look) — one definition for both modes.
color_string="list-border:6,input-border:6,preview-border:4,header-bg:-1,header-border:6,bg+:${gnohj_color13:-},fg+:${gnohj_color02:-},hl+:${gnohj_color04:-},fg:${gnohj_color02:-},info:${gnohj_color09:-},prompt:${gnohj_color04:-},pointer:${gnohj_color04:-},marker:${gnohj_color04:-},header:${gnohj_color09:-}"

fzf_common=(
  --no-border --ansi --layout=reverse --list-border --no-sort
  --prompt '⚡ ' --gutter=' ' --color "$color_string"
  --input-border --header-border
  --bind 'tab:down,btab:up'
  --bind 'ctrl-b:abort'
)

if [[ "${1:-}" == "--new-only" ]]; then
  # cwd of every active tmux session — used to drop entries already open.
  ACTIVE=$(tmux list-sessions -F '#{session_path}' 2>/dev/null | sort -u || true)
  # `--icons` gives the colored glyph+label rows (config first, then zoxide);
  # `-j` gives the same rows as JSON with Path (for the active filter). Same
  # query → same order — zip them, drop active/duplicate paths, keep the icon
  # line (which `sesh connect` accepts, icon and all).
  ICONS=$(sesh list -c -z --icons)
  LIST=$(sesh list -c -z -j | ICONS="$ICONS" ACTIVE="$ACTIVE" python3 -c '
import sys, json, os
icons = os.environ.get("ICONS", "").splitlines()
active = {p.rstrip("/") for p in os.environ.get("ACTIVE", "").splitlines() if p}
seen = set()
rows = []
for i, e in enumerate(json.load(sys.stdin)):
    p = e.get("Path", "").rstrip("/")
    if p in active or p in seen:
        continue
    seen.add(p)
    rows.append(icons[i] if i < len(icons) else e.get("Name", ""))
print("\n".join(rows))
')
  SELECTED=$(printf '%s\n' "$LIST" | fzf "${fzf_common[@]}")
else
  # Default picker runs in a loop so ctrl-w can open a dedicated, LIVE worktree
  # sub-picker and esc there returns here (fzf keybinds aren't modal, so the
  # only way to get "esc = back to default" is to re-enter this loop). ctrl-w
  # is surfaced via --expect: pressing it accepts and exits with "ctrl-w" on
  # line 1, so we branch on it instead of connecting.
  while true; do
    OUT=$(sesh list --icons | fzf "${fzf_common[@]}" \
      --expect=ctrl-w \
      --bind 'ctrl-a:change-prompt(⚡ )+reload(sesh list --icons)' \
      --bind 'ctrl-t:change-prompt( )+reload(sesh list -t --icons)' \
      --bind 'ctrl-g:change-prompt(⚙️ )+reload(sesh list -c --icons)' \
      --bind 'ctrl-x:change-prompt(📁 )+reload(sesh list -z --icons)' \
      --bind 'ctrl-f:change-prompt(🔎 )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
      --bind 'ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡ )+reload(sesh list --icons)')
    # With --expect, line 1 is the pressed expect-key (empty on a normal enter)
    # and line 2 is the selection. On esc/abort fzf exits non-zero and OUT is
    # empty, so both come back blank.
    KEY=$(printf '%s' "$OUT" | head -1)
    SELECTED=$(printf '%s\n' "$OUT" | sed -n '2p')

    if [[ "$KEY" == "ctrl-w" ]]; then
      # 🌳 worktrees, scanned live from git (worktree-list emits
      # "🌳 <name>\t<abs-path>"). Show field 1, connect to the hidden path.
      WT=$(worktree-list | fzf "${fzf_common[@]}" \
        --prompt '🌳 ' --delimiter='\t' --with-nth=1 \
        --preview-window=hidden)
      if [[ -n "$WT" ]]; then
        WT_PATH=$(printf '%s' "$WT" | cut -f2)
        # Record on entry so the worktree shows in the default view immediately
        # — the zoxide chpwd hook only fires on a later `cd`, so connecting
        # alone wouldn't seed it. _ZO_DATA_DIR matches the interactive DB.
        _ZO_DATA_DIR="${_ZO_DATA_DIR:-$HOME/.config/zshrc}" zoxide add "$WT_PATH" 2>/dev/null
        "$HOME/.config/sesh/sesh-spawn.sh" stamp
        sesh connect "$WT_PATH"
        exit 0
      fi
      # esc in the worktree view → fall through to re-show the default picker.
      continue
    fi

    [[ -z "$SELECTED" ]] && exit 0
    # Stamp so the tmux session-created hook knows this is a sesh launch (fast nvim).
    "$HOME/.config/sesh/sesh-spawn.sh" stamp
    sesh connect "$SELECTED"
    exit 0
  done
fi

[[ -z "$SELECTED" ]] && exit 0
# Stamp so the tmux session-created hook knows this is a sesh launch (fast nvim).
"$HOME/.config/sesh/sesh-spawn.sh" stamp
sesh connect "$SELECTED"
