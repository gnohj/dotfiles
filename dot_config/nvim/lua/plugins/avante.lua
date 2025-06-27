if vim.g.vscode then
  return {}
end

return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false,
    opts = {
      hints = { enabled = false },
      provider = "copilot",
      providers = {
        openai = {
          endpoint = "https://api.openai.com/v1",
          model = "gpt-4o",
          timeout = 30000,
          disable_tools = true,
          extra_request_body = {
            temperature = 0.75,
            max_completion_tokens = 16384,
            reasoning_effort = "medium",
          },
        },
        ["openai-gpt-4o-mini"] = {
          __inherited_from = "openai",
          model = "gpt-4o-mini",
        },
        copilot = {
          endpoint = "https://api.githubcopilot.com",
          model = "gpt-4o-2024-11-20",
          proxy = nil,
          disable_tools = true,
          allow_insecure = false,
          timeout = 10 * 60 * 1000,
          extra_request_body = { temperature = 0 },
          max_completion_tokens = 1000000,
          reasoning_effort = "high",
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
      auto_suggestions_provider = nil,
      behaviour = {
        auto_suggestions = false,
      },
      file_selector = {
        provider = "snacks",
        provider_opts = {},
      },
      selector = { provider = "snacks" },
      system_prompt = function()
        local hub = require("mcphub").get_hub_instance()
        return hub and hub:get_active_servers_prompt() or ""
      end,
      custom_tools = function()
        return {
          require("mcphub.extensions.avante").mcp_tool(),
        }
      end,
      extensions = {
        avante = {
          make_slash_commands = true,
        },
      },
      input = { provider = "snacks" },
    },
    dependencies = {
      {
        "ravitemer/mcphub.nvim",
        cmd = "MCPHub",
        build = "pnpm install -g mcp-hub@latest",
        opts = {},
        keys = {
          { "<leader>am", "<cmd>MCPHub<cr>", mode = { "n" }, desc = "MCP Hub" },
        },
      },
    },
    build = function()
      if vim.fn.has("win32") == 1 then
        return "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
      else
        return "make"
      end
    end,
  },
}
