return {
  {
    -- Fork of dmtrKovalenko/fold-imports.nvim with two fixes committed
    -- (two-value iter_captures + pcall'd fold cmd). Forking removes the
    -- in-place source patching and per-machine git skip-worktree state
    -- that made `Lazy update` fail on freshly provisioned boxes.
    "gnohj/fold-imports.nvim",
    event = "BufReadPost", -- Load after file is read (later than LazyFile)
    config = function()
      require("fold_imports").setup({
        auto_fold = true, -- Auto fold imports on file open
        fold_level = 99, -- Only fold imports, not other code
      })
    end,
  },
}
