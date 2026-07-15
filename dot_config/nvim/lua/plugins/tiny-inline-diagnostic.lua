-- https://github.com/rachartier/tiny-inline-diagnostic.nvim
return {
  "rachartier/tiny-inline-diagnostic.nvim",
  event = "VeryLazy", -- Or `LspAttach`
  priority = 1000, -- needs to be loaded in first
  config = function()
    require("tiny-inline-diagnostic").setup({
      preset = "minimal",
      transparent_bg = true,
      options = {
        overflow = {
          mode = "wrap", -- wrap, truncate, or none
          max_width = 70, -- Maximum width before wrapping/truncating
        },
        format = function(diagnostic)
          local msg = diagnostic.message

          local severity_emojis = {
            [vim.diagnostic.severity.ERROR] = "🚨 ",
            [vim.diagnostic.severity.WARN] = "⚠️ ",
            [vim.diagnostic.severity.INFO] = "ℹ️ ",
            [vim.diagnostic.severity.HINT] = "💡 ",
          }

          local emoji = severity_emojis[diagnostic.severity] or "● "

          local first_period = msg:find("%. ")
          if first_period then
            msg = msg:sub(1, first_period)
          end

          if #msg > 67 then
            msg = msg:sub(1, 64) .. "..."
          end

          if #msg > 0 then
            msg = msg:sub(1, 1):lower() .. msg:sub(2)
          end

          local source_text = ""
          if diagnostic.source and diagnostic.source ~= "" then
            source_text = " [" .. diagnostic.source .. "]"
          end

          return emoji .. msg .. source_text
        end,
      },
    })
    vim.diagnostic.config({ virtual_text = false }) -- Disable native virtual text
  end,
}
