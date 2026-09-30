#!/usr/bin/env bash
# herdr popup that types a skill/command or @file into the focused agent pane in its harness's syntax (enter submits, tab inserts); PICKER_PANE/PICKER_OUT let a harness drive it.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"
herdr="${HERDR_BIN_PATH:-herdr}"
MODE="${1:-skills}"

if [ -n "${PICKER_OUT:-}" ]; then
  trap '[ -e "$PICKER_OUT" ] || : >"$PICKER_OUT"' EXIT
fi

PANES=$("$herdr" pane list 2>/dev/null)
PANE="${PICKER_PANE:-}"
[ -n "$PANE" ] || PANE=$(printf '%s' "$PANES" | jq -r '.result.panes[] | select(.focused == true) | .pane_id' | head -1)
[ -n "$PANE" ] || PANE="${HERDR_PANE_ID:-}"
[ -n "$PANE" ] || { echo "herdr-prompt-picker: no focused pane" >&2; sleep 1; exit 0; }

# \x1f, not a tab: read collapses whitespace IFS, so an empty agent field would swallow the cwd.
IFS=$'\x1f' read -r agent cwd < <(printf '%s' "$PANES" |
  jq -r --arg p "$PANE" '.result.panes[] | select(.pane_id == $p) | [.agent // "", (.foreground_cwd // .cwd // "")] | join("\u001f")')
[ -d "$cwd" ] || cwd="$HOME"
project=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || project="$cwd"

[ -f "$HOME/.config/colorscheme/active/active-colorscheme.sh" ] &&
  source "$HOME/.config/colorscheme/active/active-colorscheme.sh"
color_string="list-border:6,input-border:6,preview-border:6,preview-fg:${gnohj_color04:-},bg+:${gnohj_color13:-},fg+:${gnohj_color02:-},hl+:${gnohj_color04:-},fg:${gnohj_color02:-},info:${gnohj_color09:-},prompt:${gnohj_color04:-},pointer:${gnohj_color04:-},marker:${gnohj_color04:-}"

# The sleep debounces the preview: fzf kills it when the cursor moves on, so a held arrow redraws only the list.
preview='sleep 0.06; f={4}; case "$f" in builtin:*) printf "%s\n" "${f#builtin:}" ;; *) bat --color=never --decorations=always --style=numbers "$f" 2>/dev/null || cat "$f" ;; esac'

# Vim modes: jk enters normal (unmapped keys do nothing), i/a// return to insert, esc always closes; k stays bound because fzf has no key sequences.
NORMAL_KEYS='j,g,G,J,K,x,q,i,a,/,b,w,$,^'
# "," and "\" cannot sit in a rebind list, so those two still type in normal mode.
IGNORE_KEYS=()
for c in {a..z} {A..Z} {0..9} space '!' '"' '#' '%' '&' "'" '*' '+' '-' '.' ':' ';' '<' '=' '>' '?' '@' '_' '`' '{' '|' '}' '~'; do
  case ",$NORMAL_KEYS,k," in *",$c,"*) continue ;; esac
  IGNORE_KEYS+=("$c")
done
ignore_list=$(IFS=,; printf '%s' "${IGNORE_KEYS[*]}")
ignore_binds=()
for c in "${IGNORE_KEYS[@]}" '(' ')' '[' ']'; do ignore_binds+=(--bind "$c:ignore"); done

pick() {
  local insert="unbind($NORMAL_KEYS,$ignore_list)+unbind[(,)]+unbind{[,]}+change-prompt(INSERT $1)"
  local normal="rebind($NORMAL_KEYS,$ignore_list)+rebind[(,)]+rebind{[,]}+change-prompt(NORMAL $1)"
  # Passed via env: spliced into the k transform's quoted source, the ' and " keys would break it.
  export PICK_NORMAL="$normal"
  # sh, not $SHELL: every preview and transform spawns one, and zsh would load .zshenv each time.
  fzf --ansi --no-border --layout=reverse --list-border --input-border --gutter=' ' --with-shell 'sh -c' \
    --color "$color_string" --prompt "INSERT $1" \
    "${ignore_binds[@]}" \
    --bind "start:$insert" \
    --preview-window 'up,55%,border-bottom' \
    --bind 'ctrl-j:down,ctrl-k:up,ctrl-b:abort,ctrl-d:preview-down,ctrl-u:preview-up' \
    --bind 'j:down,g:first,G:last,J:preview-down,K:preview-up,x:clear-query,q:abort' \
    --bind 'b:backward-word,w:forward-word+forward-char,$:end-of-line,^:beginning-of-line' \
    --bind 'k:transform:case "$FZF_PROMPT" in NORMAL*) echo up ;; *) case "$FZF_QUERY" in *j) printf "backward-delete-char+%s" "$PICK_NORMAL" ;; *) echo "put(k)" ;; esac ;; esac' \
    --bind "i:$insert,a:$insert,/:$insert+clear-query" \
    --bind 'esc:abort' \
    "${@:2}"
}

frecency="$HOME/.local/bin/mux/herdr/herdr-prompt-frecency.py"

# Rows are `insert\tdisplay\tpreview\tkey`; the ranker adds a star column after insert and floats frecent rows to the top.
case "$MODE" in
  skills)
    rows() { "$HOME/.local/bin/mux/herdr/herdr-prompt-list.py" "$agent" "$project"; }
    prompt='/ '
    order=(--tiebreak=begin,index)
    rank=("$frecency" rank)
    ;;
  files)
    rows() { (cd "$cwd" && fd --type f --hidden --exclude .git --strip-cwd-prefix) | awk -v d="$cwd" '{ printf "@%s \t%s\t%s/%s\t%s/%s\n", $0, $0, d, $0, d, $0 }'; }
    prompt='@ '
    order=(--scheme=path)
    rank=("$frecency" rank --stream "$cwd")
    ;;
  *)
    echo "usage: herdr-prompt-picker.sh [skills|files]" >&2
    exit 2
    ;;
esac

# --nth=2 skips the star column; for skills a name hit beats a description hit, then frecency order.
OUT=$(rows | "${rank[@]}" |
  pick "$prompt" --delimiter='\t' --with-nth=2,3 --nth=2 "${order[@]}" --expect=tab \
    --preview "$preview") || exit 0
KEY=$(printf '%s\n' "$OUT" | sed -n 1p)
SEL=$(printf '%s\n' "$OUT" | sed -n 2p)
[ -n "$SEL" ] || exit 0
TEXT=${SEL%%$'\t'*}
"$frecency" bump "${SEL##*$'\t'}"
if [ "$KEY" = tab ]; then ACTION=insert; else ACTION=submit; fi

# PICKER_OUT protocol: `<insert|submit>\t<text>`, or an empty file on cancel.
if [ -n "${PICKER_OUT:-}" ]; then
  printf '%s\t%s' "$ACTION" "$TEXT" >"$PICKER_OUT.tmp" && mv "$PICKER_OUT.tmp" "$PICKER_OUT"
elif [ -n "$TEXT" ]; then
  "$herdr" pane send-text "$PANE" "$TEXT" >/dev/null 2>&1
  [ "$ACTION" = submit ] && "$herdr" pane send-keys "$PANE" enter >/dev/null 2>&1
fi
exit 0
