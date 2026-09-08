#!/usr/bin/env bash
# shellcheck disable=SC2034
# Repoint the gnohj_color* palette at the active Omarchy theme. Source it AFTER active-colorscheme.sh; off Omarchy the theme file is absent and this is a no-op, so callers need no OS branch.

_omp_file="$HOME/.local/state/omarchy/current/theme/colors.toml"
if [ -r "$_omp_file" ]; then
  # Only these keys are read, so the eval below can never see a name the theme invented.
  while read -r _omp_k _omp_eq _omp_v _omp_rest; do
    [ "$_omp_eq" = "=" ] || continue
    _omp_v="${_omp_v%\"}"
    _omp_v="${_omp_v#\"}"
    case "$_omp_v" in "#"[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;; *) continue ;; esac
    case "$_omp_k" in
    accent | selection | muted | background | dark_background | darker_background | lighter_background | foreground | dark_foreground | light_foreground | bright_foreground | red | yellow | orange | green | cyan | blue | magenta | brown | bright_red | bright_yellow | bright_green | bright_cyan | bright_blue | bright_magenta)
      eval "_omp_c_$_omp_k=\$_omp_v"
      ;;
    *) continue ;;
    esac
  done <"$_omp_file"

  # Each slot keeps its gnohj value when the theme omits the key, so a sparse theme degrades to the seed rather than to empty.
  gnohj_color01="${_omp_c_magenta:-${gnohj_color01:-}}"
  gnohj_color02="${_omp_c_green:-${gnohj_color02:-}}"
  gnohj_color03="${_omp_c_cyan:-${_omp_c_accent:-${gnohj_color03:-}}}"
  gnohj_color04="${_omp_c_blue:-${_omp_c_accent:-${gnohj_color04:-}}}"
  gnohj_color05="${_omp_c_yellow:-${gnohj_color05:-}}"
  gnohj_color06="${_omp_c_orange:-${_omp_c_bright_yellow:-${gnohj_color06:-}}}"
  gnohj_color07="${_omp_c_dark_background:-${gnohj_color07:-}}"
  gnohj_color08="${_omp_c_lighter_background:-${gnohj_color08:-}}"
  gnohj_color09="${_omp_c_dark_foreground:-${gnohj_color09:-}}"
  gnohj_color10="${_omp_c_background:-${gnohj_color10:-}}"
  gnohj_color11="${_omp_c_red:-${gnohj_color11:-}}"
  gnohj_color12="${_omp_c_bright_yellow:-${_omp_c_yellow:-${gnohj_color12:-}}}"
  gnohj_color15="${_omp_c_bright_yellow:-${_omp_c_orange:-${gnohj_color15:-}}}"
  gnohj_color16="${_omp_c_selection:-${gnohj_color16:-}}"
  gnohj_color17="${_omp_c_muted:-${gnohj_color17:-}}"
  gnohj_color24="${_omp_c_accent:-${gnohj_color24:-}}"
  gnohj_color26="${_omp_c_lighter_background:-${gnohj_color26:-}}"
  # The three-step ink ladder herdr's sidebar needs: 13 dim rows, 46 panel headers, 14 the active row.
  gnohj_color13="${_omp_c_dark_foreground:-${gnohj_color13:-}}"
  gnohj_color46="${_omp_c_foreground:-${gnohj_color46:-}}"
  gnohj_color14="${_omp_c_bright_foreground:-${_omp_c_foreground:-${gnohj_color14:-}}}"
  gnohj_color42="${_omp_c_light_foreground:-${_omp_c_foreground:-${gnohj_color42:-}}}"
  gnohj_color49="${_omp_c_bright_cyan:-${_omp_c_cyan:-${gnohj_color49:-}}}"
  gnohj_color54="${_omp_c_muted:-${gnohj_color54:-}}"
  # No gnohj slot holds a selection fill - generate_herdr_config derives one - so this hands over the theme's own instead.
  omarchy_selection_bg="${_omp_c_selection:-}"

  unset _omp_k _omp_eq _omp_v _omp_rest
  unset _omp_c_accent _omp_c_selection _omp_c_muted _omp_c_background _omp_c_dark_background \
    _omp_c_darker_background _omp_c_lighter_background _omp_c_foreground _omp_c_dark_foreground \
    _omp_c_light_foreground _omp_c_bright_foreground _omp_c_red _omp_c_yellow _omp_c_orange \
    _omp_c_green _omp_c_cyan _omp_c_blue _omp_c_magenta _omp_c_brown _omp_c_bright_red \
    _omp_c_bright_yellow _omp_c_bright_green _omp_c_bright_cyan _omp_c_bright_blue _omp_c_bright_magenta
fi
unset _omp_file
