vim.keymap.set("n", "gf", function()
  if require("obsidian").util.cursor_on_markdown_link() then
    return "<cmd>ObsidianFollowLink<CR>"
  else
    return "gf"
  end
end, { noremap = false, expr = true })
--------------
-- obsidian --
--------------
--
-- >>> oo # from shell, navigate to vault (optional)
--
-- # NEW NOTE
-- >>> on "Note Name" # call my "obsidian new note" shell script (~/bin/on)
-- >>>
-- >>> ))) <leader>on # inside vim now, format note as template
-- >>> ))) # add tag, e.g. fact / blog / video / etc..
-- >>> ))) # add hubs, e.g. [[python]], [[machine-learning]], etc...
-- >>> ))) <leader>of # format title
--
-- # END OF DAY/WEEK REVIEW
-- >>> or # review notes in inbox
-- >>>
-- >>> ))) <leader>ok # inside vim now, move to zettelkasten
-- >>> ))) <leader>odd # or delete
-- >>>
-- >>> og # organize saved notes from zettelkasten into notes/[tag] folders
-- >>> ou # sync local with Notion
--
-- navigate to vault
vim.keymap.set("n", "<leader>oo", ":cd /Users/gnohj/Obsidian/second-brain/<cr>")
--
-- convert note to template and remove leading white space
vim.keymap.set("n", "<leader>on", ":ObsidianTemplate note<cr> :lua vim.cmd([[1,/^\\S/s/^\\n\\{1,}//]])<cr>")
-- strip date from note title and replace dashes with spaces
-- must have cursor on title
vim.keymap.set("n", "<leader>of", ":s/\\(# \\)[^_]*_/\\1/ | s/-/ /g<cr>")
--
-- search for files in full vault
vim.keymap.set("n", "<leader>os", ':Telescope find_files search_dirs={"/Users/gnohj/Obsidian/second-brain/"}<cr>')
vim.keymap.set("n", "<leader>oz", ':Telescope live_grep search_dirs={"/Users/gnohj/Obsidian/second-brain/"}<cr>')
-- for review workflow
-- move file in current buffer to zettelkasten folder
vim.keymap.set("n", "<leader>ok", ":!mv '%:p' /Users/gnohj/Obsidian/second-brain/Zettelkasten/<cr>:bd<cr>")
-- delete file in current buffer
vim.keymap.set("n", "<leader>odd", ":!rm '%:p'<cr>:bd<cr>")
-- strip date from note title and replace dashes with spaces
-- must have cursor on title
vim.keymap.set("n", "<leader>of", ":s/\\(# \\)[^_]*_/\\1/ | s/-/ /g<cr>")

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
          name = "personal",
          path = "/Users/gnohj/Obsidian/personal",
        },
        {
          name = "work",
          path = "/Users/gnohj/Obsidian/work",
        },
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
        nvim_cmp = true,
        min_chars = 2,
      },
      ui = {
        enabled = false,
      },
    },
  },
}
