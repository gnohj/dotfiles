if vim.g.vscode then
  return {}
end
-- https://github.com/CopilotC-Nvim/CopilotChat.nvim

local prompts = {
  -- Code related prompts
  Explain = "Please explain how the following code works.",
  Review = "Please review the following code and provide suggestions for improvement.",
  Tests = "Please explain how the selected code works, then generate unit tests for it.",
  Refactor = "Please refactor the following code to improve its clarity and readability.",
  FixCode = "Please fix the following code to make it work as intended.",
  FixError = "Please explain the error in the following text and provide a solution.",
  BetterNamings = "Please provide better names for the following variables and functions.",
  Documentation = "Please provide documentation for the following code.",
  SwaggerApiDocs = "Please provide documentation for the following API using Swagger.",
  SwaggerJsDocs = "Please write JSDoc for the following API using Swagger.",
  -- Text related prompts
  Summarize = "Please summarize the following text.",
  Spelling = "Please correct any grammar and spelling errors in the following text.",
  Wording = "Please improve the grammar and wording of the following text.",
  Concise = "Please rewrite the following text to make it more concise.",
}

return {
  "CopilotC-Nvim/CopilotChat.nvim",
  dependencies = {
    { "nvim-telescope/telescope.nvim" }, -- Use telescope for help actions
    { "nvim-lua/plenary.nvim" },
  },
  event = "VeryLazy",
  opts = function(_, opts)
    -- Initialize options
    opts = opts or {}
    opts.model = "gpt-4o"

    -- Format username
    local user = (vim.env.USER or "User"):gsub("^%l", string.upper)
    opts.question_header = string.format(" %s (%s) ", user, opts.model)
    -- opts.answer_header = "## Copilot "
    -- opts.error_header = "## Error "
    opts.prompts = prompts

    opts.mappings = {
      -- Use tab for completion
      complete = {
        detail = "Use @<Tab> or /<Tab> for options.",
        insert = "<Tab>",
      },
      -- Close the chat
      close = {
        normal = "q",
        insert = "<C-c>",
      },
      -- Reset the chat buffer
      reset = {
        normal = "<C-x>",
        insert = "<C-x>",
      },
      -- Submit the prompt to Copilot
      submit_prompt = {
        normal = "<CR>",
        insert = "<C-CR>",
      },
      -- Accept the diff
      accept_diff = {
        normal = "<C-y>",
        insert = "<C-y>",
      },
      -- Show help
      show_help = {
        normal = "g?",
      },
    }

    -- Configure mappings
    -- opts.mappings = {
    --   close = {
    --     normal = "<Esc>",
    --     insert = "<Esc>",
    --   },
    --   -- I hated this keymap with all my heart, when trying to navigate between
    --   -- neovim splits I reset the chat by mistake if I was in insert mode
    --   reset = {
    --     normal = "",
    --     insert = "",
    --   },
    -- }

    -- opts.prompts = {
    --   Lazy = {
    --     prompt = "Specify a custom prompt here",
    --   },
    -- }

    return opts
  end,
  config = function(_, opts)
    local chat = require("CopilotChat")
    chat.setup(opts)

    local select = require("CopilotChat.select")
    vim.api.nvim_create_user_command("CopilotChatVisual", function(args)
      chat.ask(args.args, { selection = select.visual })
    end, { nargs = "*", range = true })

    -- Inline chat with Copilot
    vim.api.nvim_create_user_command("CopilotChatInline", function(args)
      chat.ask(args.args, {
        selection = select.visual,
        window = {
          layout = "float",
          relative = "cursor",
          width = 1,
          height = 0.4,
          row = 1,
        },
      })
    end, { nargs = "*", range = true })

    -- Restore CopilotChatBuffer
    vim.api.nvim_create_user_command("CopilotChatBuffer", function(args)
      chat.ask(args.args, { selection = select.buffer })
    end, { nargs = "*", range = true })

    -- Custom buffer for CopilotChat
    vim.api.nvim_create_autocmd("BufEnter", {
      pattern = "copilot-*",
      callback = function()
        vim.opt_local.relativenumber = true
        vim.opt_local.number = true

        -- Get current filetype and set it to markdown if the current filetype is copilot-chat
        local ft = vim.bo.filetype
        if ft == "copilot-chat" then
          vim.bo.filetype = "markdown"
        end
      end,
    })
  end,
  keys = {
    -- Show prompts actions with telescope
    {
      "<leader>zp",
      function()
        local actions = require("CopilotChat.actions")
        require("CopilotChat.integrations.telescope").pick(actions.prompt_actions())
      end,
      desc = "CopilotChat - Prompt actions",
    },
    -- Show prompts actions with telescope
    {
      "<leader>zh",
      function()
        local actions = require("CopilotChat.actions")
        require("CopilotChat.integrations.telescope").pick(actions.help_actions())
      end,
      desc = "CopilotChat - Help actions",
    },
    {
      "<leader>zp",
      ":lua require('CopilotChat.integrations.telescope').pick(require('CopilotChat.actions').prompt_actions({selection = require('CopilotChat.select').visual}))<CR>",
      mode = "x",
      desc = "CopilotChat - Prompt actions",
    },
    -- Code related commands
    { "<leader>ze", "<cmd>CopilotChatExplain<cr>", desc = "CopilotChat - Explain code" },
    { "<leader>zt", "<cmd>CopilotChatTests<cr>", desc = "CopilotChat - Generate tests" },
    { "<leader>zr", "<cmd>CopilotChatReview<cr>", desc = "CopilotChat - Review code" },
    { "<leader>zR", "<cmd>CopilotChatRefactor<cr>", desc = "CopilotChat - Refactor code" },
    { "<leader>zn", "<cmd>CopilotChatBetterNamings<cr>", desc = "CopilotChat - Better Naming" },
    -- Chat with Copilot in visual mode
    {
      "<leader>zv",
      ":CopilotChatVisual",
      mode = "x",
      desc = "CopilotChat - Open in vertical split",
    },
    {
      "<leader>zx",
      ":CopilotChatInline<cr>",
      mode = "x",
      desc = "CopilotChat - Inline chat",
    },
    -- Custom input for CopilotChat
    {
      "<leader>zi",
      function()
        local input = vim.fn.input("Ask Copilot: ")
        if input ~= "" then
          vim.cmd("CopilotChat " .. input)
        end
      end,
      desc = "CopilotChat - Ask input",
    },
    -- Generate commit message based on the git diff
    {
      "<leader>zm",
      "<cmd>CopilotChatCommit<cr>",
      desc = "CopilotChat - Generate commit message for all changes",
    },
    -- Quick chat with Copilot
    {
      "<leader>zq",
      function()
        local input = vim.fn.input("Quick Chat: ")
        if input ~= "" then
          vim.cmd("CopilotChatBuffer " .. input)
        end
      end,
      desc = "CopilotChat - Quick chat",
    },
    -- Debug
    { "<leader>zd", "<cmd>CopilotChatDebugInfo<cr>", desc = "CopilotChat - Debug Info" },
    -- Fix the issue with diagnostic
    { "<leader>zf", "<cmd>CopilotChatFixDiagnostic<cr>", desc = "CopilotChat - Fix Diagnostic" },
    -- Clear buffer and chat history
    { "<leader>zl", "<cmd>CopilotChatReset<cr>", desc = "CopilotChat - Clear buffer and chat history" },
    -- Toggle Copilot Chat Vsplit
    { "<leader>zv", "<cmd>CopilotChatToggle<cr>", desc = "CopilotChat - Toggle" },
    -- Copilot Chat Models
    { "<leader>z?", "<cmd>CopilotChatModels<cr>", desc = "CopilotChat - Select Models" },
    -- Copilot Chat Agents
    { "<leader>za", "<cmd>CopilotChatAgents<cr>", desc = "CopilotChat - Select Agents" },
  },
}
