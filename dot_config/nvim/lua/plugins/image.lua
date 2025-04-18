if vim.g.vscode then
  return {}
end

return {
  {
    "3rd/image.nvim",
    priority = 1002,
    ft = { "markdown", "quarto", "vimwiki" },
    dependencies = {
      {
        "vhyrro/luarocks.nvim",
        priority = 1001, -- this plugin needs to run before anything else
        opts = {
          rocks = { "magick" },
        },
      },
    },
    opts = {
      backend = "kitty",
      integrations = {
        markdown = {
          enabled = true,
          only_render_image_at_cursor = true,
          filetypes = { "markdown", "vimwiki", "quarto" },
        },
      },
      editor_only_render_when_focused = false,
      window_overlap_clear_enabled = true,
      -- window_overlap_clear_ft_ignore = { 'cmp_menu', 'cmp_docs', 'scrollview' },
      tmux_show_only_in_active_window = true,
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "scrollview", "scrollview_sign" },
      max_width = nil,
      max_height = nil,
      max_width_window_percentage = nil,
      max_height_window_percentage = 30,
      kitty_method = "normal",
    },
  },
}
