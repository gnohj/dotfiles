return {
  "m4xshen/hardtime.nvim",
  enabled = false,
  dependencies = { "MunifTanjim/nui.nvim" },
  event = "BufEnter",
  opts = {
    disabled_filetypes = { "qf", "netrw", "NvimTree", "lazy", "mason", "oil" },
    disable_mouse = false,
    restricted_keys = {
      ["jk"] = false, -- Allow jk combination
      ["j"] = false, -- Allow j key
      ["k"] = false, -- Allow k key
      disabled_keys = {},
      -- ["<Up>"] = {}, -- needed for blink
      -- ["<Down>"] = {}, -- needed for blink
      ["<Left>"] = {},
      ["<Right>"] = {},
    },
  },
}
