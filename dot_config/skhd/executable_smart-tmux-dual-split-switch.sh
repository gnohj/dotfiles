#!/bin/bash

export PATH="/opt/homebrew/bin:$PATH"

# Toggle focus between the leftmost and rightmost pane; one list-panes + awk keeps it to two tmux round-trips.
TARGET=$(tmux list-panes -F '#{pane_active} #{pane_id} #{pane_left}' | awk '
  { id[NR] = $2; left[NR] = $3 + 0; if ($1 == 1) active = $2 }
  END {
    if (NR < 2) exit
    lmin = id[1]; lminv = left[1]; lmax = id[1]; lmaxv = left[1]
    for (i = 2; i <= NR; i++) {
      if (left[i] < lminv) { lminv = left[i]; lmin = id[i] }
      if (left[i] > lmaxv) { lmaxv = left[i]; lmax = id[i] }
    }
    print (active == lmin) ? lmax : lmin
  }
')

[ -n "$TARGET" ] && tmux select-pane -t "$TARGET"
