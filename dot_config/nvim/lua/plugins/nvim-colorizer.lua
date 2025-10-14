-- https://github.com/norcalli/nvim-colorizer.lua
-- This plugin allows me to see the colors of hex code inside files

return {
  "norcalli/nvim-colorizer.lua",
  event = "BufReadPost", -- Defer loading until file is read
  config = function()
    require("colorizer").setup()
  end,
}
