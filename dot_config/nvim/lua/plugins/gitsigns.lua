return {
  "lewis6991/gitsigns.nvim",
  event = "LazyFile",
  opts = {
    signs = {
      add = { text = "•" },
      change = { text = "•" },
      delete = { text = "" },
      topdelete = { text = "•" },
      changedelete = { text = "•" },
      untracked = { text = "•" },
    },
    signs_staged = {
      add = { text = "·" },
      change = { text = "·" },
      delete = { text = "·" },
      topdelete = { text = "·" },
      changedelete = { text = "·" },
      untracked = { text = "·" },
    },
    on_attach = function(buffer)
      -- Skip gitsigns in codediff tabs
      local lifecycle = package.loaded["codediff.ui.lifecycle"]
      if lifecycle then
        local tabpage = vim.api.nvim_get_current_tabpage()
        if lifecycle.get_session(tabpage) then
          return
        end
      end

      local gs = package.loaded.gitsigns

      local function map(mode, l, r, desc)
        vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
      end

      -- Navigation. `target = "all"` walks both staged AND unstaged hunks
      -- — without it, gitsigns defaults to "unstaged" and silently skips
      -- hunks once you stage them, even though signs_staged shows the
      -- markers. We want ]h/[h to work consistently regardless of stage
      -- state.
      map("n", "]h", function()
        if vim.wo.diff then
          vim.cmd.normal({ "]c", bang = true })
        else
          gs.nav_hunk("next", { target = "all" })
        end
      end, "Next Hunk (all)")
      map("n", "[h", function()
        if vim.wo.diff then
          vim.cmd.normal({ "[c", bang = true })
        else
          gs.nav_hunk("prev", { target = "all" })
        end
      end, "Prev Hunk (all)")

      -- Capital H variants → staged hunks only. Useful when reviewing
      -- exactly what's about to be committed without unstaged noise.
      map("n", "]H", function()
        gs.nav_hunk("next", { target = "staged" })
      end, "Next Hunk (staged only)")
      map("n", "[H", function()
        gs.nav_hunk("prev", { target = "staged" })
      end, "Prev Hunk (staged only)")

      -- Actions
      map("n", "<leader>hs", gs.stage_hunk, "Stage Hunk")
      map("n", "<leader>hr", gs.reset_hunk, "Reset Hunk")
      map("v", "<leader>hs", function()
        gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Stage Hunk")
      map("v", "<leader>hr", function()
        gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Reset Hunk")
      map("n", "<leader>hS", gs.stage_buffer, "Stage Buffer")
      map("n", "<leader>hu", gs.undo_stage_hunk, "Undo Stage Hunk")
      map("n", "<leader>hR", gs.reset_buffer, "Reset Buffer")
      map("n", "<leader>hp", gs.preview_hunk_inline, "Preview Hunk Inline")
      map("n", "<leader>hb", function()
        gs.blame_line({ full = true })
      end, "Blame Line")
      map("n", "<leader>hB", gs.toggle_current_line_blame, "Toggle Line Blame")
      map("n", "<leader>hd", gs.diffthis, "Diff This")
      map("n", "<leader>hD", function()
        gs.diffthis("~")
      end, "Diff This ~")

      -- Text object
      map(
        { "o", "x" },
        "ih",
        ":<C-U>Gitsigns select_hunk<CR>",
        "GitSigns Select Hunk"
      )
    end,
  },
}
