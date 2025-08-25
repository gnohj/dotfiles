if vim.g.vscode then
  return {}
end

return {
  -- this plugin is only within neovim and adds tmux like keybindings
  {
    "aserowy/tmux.nvim",
    config = function()
      return require("tmux").setup({
        resize = {
          -- enables default keybindings (A-hjkl) for normal mode (A = Alt)
          resize_step_x = 1,
          resize_step_y = 1,
          enable_default_keybindings = false,
        },
        navigation = {
          -- cycles to opposite pane while navigating into the border (neovim panes only)
          cycle_navigation = true,
          -- enables default keybindings (C-hjkl) for normal mode
          enable_default_keybindings = false,
          -- prevents unzoom tmux when navigating beyond vim border
          persist_zoom = false,
        },
        copy_sync = {
          -- this damn thing prevents neovim to access the system clipboard..
          -- it tries to sync tmux and neovim clipboards only.. but leaves system out? WHY! :/
          enable = false,
        },
        swap = {
          -- cycles to opposite pane while navigating into the border
          cycle_navigation = true,
          -- enables default keybindings (C-A-hjkl) for normal mode
          enable_default_keybindings = false,
        },
      })
    end,
  },
  -- this plugin actually allows us to navigate between nvim and tmux panes
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
      { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
      { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
      { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
      { "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
    },
  },
}
