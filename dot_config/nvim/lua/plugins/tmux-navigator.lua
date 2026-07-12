return {
  -- aserowy/tmux.nvim was previously specced here with every default
  -- keybinding disabled and no callers — pure dead weight (~1.5ms at
  -- startup). Removed. christoomey/vim-tmux-navigator below is what
  -- actually drives <C-hjkl> nvim<->tmux pane navigation.
  {
    "christoomey/vim-tmux-navigator",
    -- Own every <C-hjkl> mapping ourselves (below) so the plugin never installs
    -- its default <C-h> → TmuxNavigateLeft over our custom sidebar-aware one.
    init = function()
      vim.g.tmux_navigator_no_mappings = 1
    end,
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      -- Left is special: at nvim's leftmost split, defer to tmux instead of
      -- christoomey's default `select-pane -L` (which wraps at the edge). If the
      -- pane is also the leftmost tmux pane, focus the tmux-dash sidebar via
      -- SIGUSR1; otherwise move to the tmux pane on the left.
      {
        "<c-h>",
        function()
          if vim.env.TMUX == nil then
            vim.cmd("wincmd h")
            return
          end
          local cur = vim.fn.winnr()
          vim.cmd("wincmd h")
          if vim.fn.winnr() == cur then
            local pane = vim.env.TMUX_PANE or ""
            vim.fn.jobstart({
              "tmux",
              "if-shell",
              "-F",
              "-t",
              pane,
              "#{pane_at_left}",
              'run-shell "pkill -USR1 -x tmux-dash"',
              "select-pane -t " .. pane .. " -L",
            })
          end
        end,
        desc = "Navigate left, or focus tmux-dash sidebar at the leftmost edge",
      },
      { "<c-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate down" },
      { "<c-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate up" },
      { "<c-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right" },
      { "<c-\\>", "<cmd>TmuxNavigatePrevious<cr>", desc = "Navigate previous" },
    },
  },
}
