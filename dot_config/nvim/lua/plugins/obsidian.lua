if vim.g.vscode then
  return {}
end

vim.keymap.set("n", "gf", function()
  if require("obsidian").util.cursor_on_markdown_link() then
    return "<cmd>ObsidianFollowLink<CR>"
  else
    return "gf"
  end
end, { noremap = false, expr = true })

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
        -- nvim_cmp = true,
        min_chars = 2,
      },
      ui = {
        enabled = false,
      },
    },
  },
}
