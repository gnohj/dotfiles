return {
  {
    "dmtrKovalenko/fold-imports.nvim",
    pin = true, -- Pin to current version (has local patch for treesitter API)
    event = "BufReadPost", -- Load after file is read (later than LazyFile)
    build = function()
      -- Patch the file after installation/update (backwards-compatible fix)
      local file_path = vim.fn.stdpath("data")
        .. "/lazy/fold-imports.nvim/lua/fold_imports.lua"
      local file = io.open(file_path, "r")
      if file then
        local content = file:read("*all")
        file:close()

        -- Apply the backwards-compatible treesitter API fix
        content = content:gsub(
          "for _, node, _ in query:iter_captures%(root, bufnr%) do",
          "for _, node in query:iter_captures(root, bufnr) do"
        )

        -- Wrap the fold cmd in pcall to silently skip stale ranges.
        -- checktime can reload a buffer mid-fold-pass, leaving the
        -- computed end-line past the new buffer's last line and
        -- producing `E16: Invalid range`. pcall lets the next fold pass
        -- (re-triggered by the BufRead) apply correctly.
        content = content:gsub(
          'vim%.cmd%(string%.format%("%%d,%%dfold"',
          'pcall(vim.cmd, string.format("%%d,%%dfold"'
        )

        file = io.open(file_path, "w")
        if file then
          file:write(content)
          file:close()
          -- Tell git to skip our patched file in the plugin's worktree so lazy
          -- stops flagging it as "local changes" (which blocks updates). Same
          -- reason a fresh box showed it failed while the Mac didn't.
          vim.fn.system({
            "git",
            "-C",
            vim.fn.stdpath("data") .. "/lazy/fold-imports.nvim",
            "update-index",
            "--skip-worktree",
            "lua/fold_imports.lua",
          })
        end
      end
    end,
    config = function()
      require("fold_imports").setup({
        auto_fold = true, -- Auto fold imports on file open
        fold_level = 99, -- Only fold imports, not other code
      })
    end,
  },
}
