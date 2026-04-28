-- Paste images from clipboard into markdown notes
-- https://github.com/HakonHarnes/img-clip.nvim
return {
  "HakonHarnes/img-clip.nvim",
  event = "VeryLazy",
  opts = {
    default = {
      embed_image_as_base64 = false,
      prompt_for_file_name = true,
      drag_and_drop = {
        insert_mode = true,
      },
      use_absolute_path = false,
    },
    filetypes = {
      markdown = {
        url_encode_path = true,
        template = "![[$FILE_NAME]]",
        download_images = false,
        -- Obsidian-style: paste into vault Notes-Assets/ regardless of cwd
        dir_path = function()
          local vault = vim.fn.expand("~/Obsidian/second-brain")
          local current = vim.fn.expand("%:p")
          if current:find(vault, 1, true) then
            return vault .. "/Notes-Assets"
          end
          return "assets"
        end,
        file_name = "%y%m%d-%H%M%S",
        relative_to_current_file = false,
      },
    },
  },
  keys = {
    {
      "<leader>zv",
      "<cmd>PasteImage<cr>",
      desc = "[P]Obsidian: Paste image from clipboard",
      mode = { "n", "i" },
    },
  },
}
