return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 500
  end,
  opts = function(_, opts)
    -- Use a function so we MERGE with LazyVim's default spec instead of
    -- replacing it. Plain `opts = { spec = { ... } }` overwrites the
    -- default array (Lua table-merge replaces arrays, doesn't concat),
    -- which strips LazyVim's group labels like `<leader>s`/`<leader>c`.
    opts.spec = vim.list_extend(opts.spec or {}, {
      { "<leader>9", group = "99 AI [+]", icon = "󰍜" },
      { "<leader>a", desc = "Copilot Suggestion Toggle", icon = "󰚩" },
      { "<leader>b", group = "Buffer [+]" },
      { "<leader>c", group = "Code [+]" },
      { "<leader>d", group = "Debug [+]" },
      { "<leader>f", group = "File/Find [+]" },
      { "<leader>g", group = "Git [+]" },
      { "<leader>G", hidden = true },
      { "<leader>gh", hidden = true },
      { "<leader>gl", hidden = true }, -- Hidden: use visual mode for gitlineage
      { "<leader>h", group = "Hunks [+]", icon = "󰊢" },
      { "<leader>i", icon = "󰋺" }, -- Import Statements
      { "<leader>K", hidden = true },
      { "<leader>L", hidden = true },
      { "<leader>m", group = "Toggle C [+]", icon = "󰔡" },
      { "<leader>n", hidden = true },
      { "<leader>o", group = "Octo [+]", icon = "󰭹" },
      { "<leader>p", group = "Yank History [+]", icon = "󰅍" },
      { "<leader>q", group = "Quit/Session [+]" },
      { "<leader>s", group = "Search [+]" },
      { "<leader>t", group = "Neotest & Toggle [+]" },
      { "<leader>u", group = "UI [+]" },
      { "<leader>w", group = "Windows [+]" },
      { "<leader>x", group = "Diagnostics/Quickfix [+]" },
      { "<leader>z", group = "Obsidian [+]", icon = "󱓥" },
      { "<leader>-", desc = "Open yazi at cwd", icon = "󰉋" },
      { "<leader><tab>", group = "Tabs [+]" },
    })
    -- Default sort splits "actions" and "+groups" into separate
    -- sections; remove "group" to interleave them alphabetically.
    opts.sort = { "local", "order", "alphanum", "mod", "lower", "icase" }

    -- Disable which-key's hardcoded "+" prefix on group descriptions
    -- (defined as `icons.group` in the plugin's config). Empty string
    -- means no prefix — our specs append "[+]" as the group marker.
    opts.icons = opts.icons or {}
    opts.icons.group = ""

    -- Clean up displayed descriptions:
    --   1. strip "[P]" prefix (personal-keymap marker — noise in the popup)
    --   2. strip any leading whitespace
    --   3. capitalize the first letter so LazyVim's lowercase group labels
    --      ("buffer", "code", ...) display as "Buffer", "Code", etc.
    opts.replace = opts.replace or {}
    opts.replace.desc = vim.list_extend(opts.replace.desc or {}, {
      { "^%[P%]", "" },
      { "^%s+", "" },
      { "^%l", string.upper },
    })
  end,
}
