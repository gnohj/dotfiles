if vim.g.vscode then
  return {}
end

return {
  {
    "epwalsh/obsidian.nvim",
    version = "*",
    lazy = true,
    ft = "markdown",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    disable_frontmatter = true,
    opts = {
      workspaces = {
        {
          name = "second-brain",
          path = "/Users/gnohj/Obsidian/second-brain",
        },
      },
      disable_frontmatter = true,
      templates = {
        subdir = "templates",
        date_format = "%Y-%m-%d",
        time_format = "%H:%M:%S",
      },
      completion = {
        min_chars = 2,
      },
      ui = {
        enabled = false,
      },
    },
  },
}
