#!/usr/bin/env bash
# Shared by mic.sh and mic-click.sh so both render the same short label.

# Abbreviate known devices; the bar is tight and the full name pushes the clock off.
mic_short_name() {
  case "$1" in
  TONOR*) printf '%s' "T" ;;
  AirPods*) printf '%s' "AP" ;;
  MacBook*) printf '%s' "MB" ;;
  *) printf '%s' "$1" ;;
  esac
}
