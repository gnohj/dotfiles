if vim.g.vscode then
  return {}
end

-- return {}

-- enable with LazyExtras
return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  lazy = true,
  version = false,
  opts = {
    -- provider = "openai",
    -- openai = {
    --   model = "gpt-4o-mini",
    -- },
    provider = "copilot",
    -- provider = "claude",
    -- claude = {
    --   endpoint = "https://api.anthropic.com",
    --   model = "claude-3-5-sonnet-20241022",
    --   temperature = 0,
    --   max_tokens = 4096,
    -- },
    hints = { enabled = false },
  },
  -- cd into ~/.local/share/nvim/lazy/avante.nvim and run make BUILD_FROM_SOURCE=true
  build = "make BUILD_FROM_SOURCE=true",
  dependencies = {
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
    "zbirenbaum/copilot.lua",
    {
      "HakonHarnes/img-clip.nvim",
      event = "VeryLazy",
      opts = {
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          use_absolute_path = true,
        },
      },
    },
    {
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
  },
}
