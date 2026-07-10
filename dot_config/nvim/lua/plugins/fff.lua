-- Ok
return {
  "dmtrKovalenko/fff.nvim",
  build = function()
    require("fff.download").download_or_build_binary()
  end,
  lazy = false,
  opts = {
    debug = {
      show_scores = true,
    },
    lazy_sync = false,
    max_threads = 4,
    layout = {
      prompt_position = "top",
      path_shorten_strategy = "start",
      flex = { wrap = "bottom" },
    },
    hl = {
      normal = "FFFNormal",
      directory_path = "FFFDirectoryPath",
    },
    keymaps = {
      preview_scroll_up = "K",
      preview_scroll_down = "J",
    },
    git = {
      status_text_color = true,
    },
    preview = {
      enabled = true,
      max_size = 50 * 1024,
    },
  },
  keys = {
    {
      "<leader>ff",
      function()
        require("fff").find_files()
      end,
      desc = "FFF — find files (frecency, .gitignore-aware)",
    },
    {
      "<leader>fg",
      function()
        require("fff").live_grep()
      end,
      desc = "FFF - exact grep",
    },
    {
      "<leader>fz",
      function()
        require("fff").live_grep({ grep = { modes = { "fuzzy", "plain" } } })
      end,
      desc = "FFF - fuzzy grep",
    },
    {
      "<leader>fx",
      function()
        require("fff").live_grep({ query = vim.fn.expand("<cword>") })
      end,
      desc = "FFF - Search current word",
    },
  },
}
