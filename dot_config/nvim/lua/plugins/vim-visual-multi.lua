-- https://github.com/mg979/vim-visual-multi  (:help visual-multi)
--
-- macOS gotcha: disable the two Mission Control shortcuts bound to ctrl+up /
-- ctrl+down (Settings > Keyboard > Keyboard Shortcuts) — the plugin uses them
-- to create vertical cursors.
--
-- Ctrl-N select word · Ctrl-Up/Down add vertical cursors · Shift-Arrows extend
-- · n/N next/prev occurrence · [/] next/prev cursor · q skip · Q remove cursor
-- · i/a/I insert · tab toggle extend mode · g/ match by pattern

return {
  {
    "mg979/vim-visual-multi",
    event = "VeryLazy", -- Defer until after startup
  },
}
