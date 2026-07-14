return {
  "pwntester/octo.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  cmd = { "Octo" },
  keys = {
    {
      "<leader>gi",
      function()
        local cmd = "gh-dash --config " .. vim.fn.expand("~/.config/gh-dash/issues.yml")
        require("config.mux").new_window(cmd, { name = "🐙" })
      end,
      desc = "gh-dash Issues (window)",
    },
    {
      "<leader>oa",
      "<cmd>Octo actions<cr>",
      desc = "Octo actions",
    },
  },
  opts = {
    enable_builtin = false,
    picker = "snacks",
    mappings = {
      review_diff = {
        select_next_entry = {
          lhs = "<Tab>",
          desc = "move to next changed file",
        },
        select_prev_entry = {
          lhs = "<S-Tab>",
          desc = "move to previous changed file",
        },
        close_review_tab = {
          lhs = "<esc>",
          desc = "close review tab",
        },
        add_review_comment = {
          lhs = "<leader>oc",
          desc = "add review comment",
          mode = { "n", "x" },
        },
        add_review_suggestion = {
          lhs = "<leader>os",
          desc = "add review suggestion",
          mode = { "n", "x" },
        },
        next_thread = {
          lhs = "]t",
          desc = "next comment thread",
        },
        prev_thread = {
          lhs = "[t",
          desc = "previous comment thread",
        },
        submit_review = {
          lhs = "<leader>oS",
          desc = "submit review",
        },
        discard_review = {
          lhs = "<leader>oD",
          desc = "discard review",
        },
      },
    },
  },
  config = function(_, opts)
    require("octo").setup(opts)

    -- gh-dash review launches pass `let g:octo_auto_review=1`. Once the PR
    -- buffer's filetype is set (its PR node is already attached by then), fire a
    -- bare `Octo review`, which start-or-resumes: it opens octo's internal diff
    -- mode for inline comments, resuming an existing pending review if one is
    -- already open on GitHub. Resolves the PR from the octo buffer, so it works
    -- even when the checked-out branch is `review/<head>` rather than the head
    -- itself. Deferred so it runs after the buffer finishes configuring, and
    -- latched to a single PR buffer so it never double-fires.
    if vim.g.octo_auto_review then
      local fired = false
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "octo",
        callback = function(ev)
          if fired then
            return
          end
          if not vim.api.nvim_buf_get_name(ev.buf):match("/pull/%d+$") then
            return
          end
          fired = true
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(ev.buf) then
              vim.api.nvim_set_current_buf(ev.buf)
              vim.cmd("Octo review")
            end
          end)
        end,
      })
    end

    -- gh-dash / <leader>gi open Octo in a throwaway tmux window flagged with
    -- `let g:zen_disabled=1`. Unlike codediff (which self-quits on TabClosed),
    -- Octo never exits, so when that window closes the nvim lingers, gets
    -- reparented to launchd, and pins an fff LMDB reader slot forever until it
    -- exhausts the 126-slot table (MDB_READERS_FULL). Quit once the last
    -- octo:// buffer is gone. Gated on zen_disabled + octo_seen so it only
    -- affects ephemeral launches and never fires on the startup empty buffer.
    if vim.g.zen_disabled then
      local octo_seen = false
      vim.api.nvim_create_autocmd("BufEnter", {
        callback = function(ev)
          if vim.api.nvim_buf_get_name(ev.buf):match("^octo://") then
            octo_seen = true
          end
        end,
      })
      vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
        callback = function()
          if not octo_seen then
            return
          end
          vim.defer_fn(function()
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              if
                vim.api.nvim_buf_is_loaded(buf)
                and vim.api.nvim_buf_get_name(buf):match("^octo://")
              then
                return
              end
            end
            vim.cmd("qa")
          end, 100)
        end,
      })
    end
  end,
}
