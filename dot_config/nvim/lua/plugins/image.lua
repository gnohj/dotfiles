return {
  {
    "3rd/image.nvim",
    priority = 1002,
    dependencies = {
      "kiyoon/magick.nvim",
    },
    opts = {
      backend = "kitty",
      markdown = {
        enable = true,
      },
      css = {
        enable = true,
      },
      html = {
        enable = true,
      },
      window_overlap_clear_enabled = true,
      tmux_show_only_in_active_window = true,
      hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.svg" },
    },
  },
}
