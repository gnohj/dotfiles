return {
  "dmtrKovalenko/fff.nvim",
  build = function()
    require("fff.download").download_or_build_binary()
  end,
  lazy = false,
  opts = {
    layout = {
      prompt_position = "top",
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
