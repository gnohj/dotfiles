-- Ok
return {
  "dmtrKovalenko/fff.nvim",
  build = function()
    require("fff.download").download_or_build_binary()
  end,
  lazy = false,
  opts = {
    lazy_sync = false,
    max_threads = 8,
    layout = {
      prompt_position = "top",
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
  },
}
