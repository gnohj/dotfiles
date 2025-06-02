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
    mode = "legacy", -- "agentic" always uses tools
    -- provider = "openai",
    provider = "copilot",
    -- provider = "claude",
    providers = {
      -- openai = {
      --   model = "gpt-4o-mini",
      -- },
      openai = {
        endpoint = "https://api.openai.com/v1",
        model = "gpt-4o",
        timeout = 30000, -- Timeout in milliseconds, increase this for reasoning models
        disable_tools = true,
        extra_request_body = {
          temperature = 0.75,
          max_completion_tokens = 16384, -- Increase this to include reasoning tokens (for reasoning models)
          reasoning_effort = "medium", -- low|medium|high, only used for reasoning models
        },
      },
      ["openai-gpt-4o-mini"] = {
        __inherited_from = "openai",
        model = "gpt-4o-mini",
      },
      copilot = {
        endpoint = "https://api.githubcopilot.com",
        model = "gpt-4o-2024-11-20",
        proxy = nil, -- [protocol://]host[:port] Use this proxy
        allow_insecure = false, -- Allow insecure server connections
        disable_tools = true,
        timeout = 30000, -- Timeout in milliseconds
        extra_request_body = {
          temperature = 0.75,
          max_tokens = 20480,
        },
      },
      claude = {
        endpoint = "https://api.anthropic.com",
        model = "claude-3-5-sonnet-20241022",
        disable_tools = true,
        extra_request_body = {
          temperature = 0,
          max_tokens = 4096,
        },
      },
    },
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
