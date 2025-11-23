return {
  "codethread/qmk.nvim",
  ft = { "dts", "keymap" },
  enabled = true,
  opts = function()
    -- Auto-detect keyboard based on current buffer path
    local bufname = vim.api.nvim_buf_get_name(0)

    if bufname:match("glove80") then
      return {
        name = "LAYOUT_glove80",
        variant = "zmk",
        layout = {
          "x x x x x _ _ _ _ _ _ _ _ x x x x x _", -- Padded to 19 items
          "x x x x x x _ _ _ _ _ _ _ x x x x x x",
          "x x x x x x _ _ _ _ _ _ _ x x x x x x",
          "x x x x x x _ _ _ _ _ _ _ x x x x x x",
          "x x x x x x x x x _ x x x x x x x x x",
          "x x x x x _ x x x _ x x x _ x x x x x",
        },
        comment_preview = { position = "top" },
      }
    elseif bufname:match("corne") then
      return {
        name = "LAYOUT_split_3x6_3",
        variant = "zmk",
        layout = {
          "x x x x x x _ _ _ _ x x x x x x",
          "x x x x x x _ _ _ _ x x x x x x",
          "x x x x x x _ _ _ _ x x x x x x",
          "_ _ _ x x x _ _ _ _ x x x _ _ _",
        },
        comment_preview = { position = "top" },
      }
    else
      -- Default minimal config
      return {
        name = "LAYOUT",
        variant = "zmk",
        layout = { "x" },
        comment_preview = { position = "top" },
      }
    end
  end,
}
