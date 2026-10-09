#!/usr/bin/env bash
# prefix+m: fzf-vim picker over herdr-annotate's annotations and archives.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"
store="$HOME/.local/bin/mux/herdr/herdr-annotate-store.py"

# shellcheck disable=SC1091
[ -f "$HOME/.config/colorscheme/active/active-colorscheme.sh" ] && . "$HOME/.config/colorscheme/active/active-colorscheme.sh"
FZF_COLORS="--color=bg+:${gnohj_color13:-},border:${gnohj_color03:-},fg:${gnohj_color04:-},fg+:${gnohj_color04:-},hl+:${gnohj_color04:-},info:${gnohj_color09:-},prompt:${gnohj_color04:-},pointer:${gnohj_color04:-},marker:${gnohj_color04:-},header:${gnohj_color09:-}"

export HERDR_ANNOTATE_KEY_COLOR="${gnohj_color02:-}" HERDR_ANNOTATE_TEXT_COLOR="${gnohj_color04:-}"
HERDR_ANNOTATE_VIEW_FILE=$(mktemp "${TMPDIR:-/tmp}/herdr-annotate-view.XXXXXX")
export HERDR_ANNOTATE_VIEW_FILE
trap 'rm -f "$HERDR_ANNOTATE_VIEW_FILE"' EXIT

refresh="reload($store list)+transform-header($store header)"
normal_binds="x:execute-silent($store delete {+1})+$refresh
a:execute-silent($store archive {+1})+$refresh
r:execute-silent($store restore {+1})+$refresh
v:execute-silent($store toggle-view)+$refresh+first"

picked=$("$store" list |
  FZF_VIM_MULTI=1 FZF_VIM_HEADER="$("$store" header)" FZF_VIM_NORMAL_BINDS="$normal_binds" \
    "$HOME/.local/bin/fzf-vim.sh" --ansi --no-sort --delimiter='\t' --with-nth=2 \
    --prompt='✎ ' $FZF_COLORS \
    --bind "start:$refresh" \
    --preview "$store preview {1}" --preview-window 'right:55%:wrap' |
  cut -f1)
[ -n "$picked" ] || exit 0

IFS=$'\n' read -r -d '' -a ids <<<"$picked"
markdown=$("$store" markdown "${ids[@]}")
[ -n "$markdown" ] || exit 0

# Bracketed paste into the focused pane, ESC stripped so the text cannot end it early.
herdr="${HERDR_BIN_PATH:-herdr}"
pane=$("$herdr" pane list 2>/dev/null | jq -r '[.result.panes[] | select(.focused == true)][0].pane_id // empty')
[ -n "$pane" ] || exit 1
"$herdr" pane send-text "$pane" $'\e[200~'"${markdown//$'\e'/}"$'\n\e[201~' >/dev/null
