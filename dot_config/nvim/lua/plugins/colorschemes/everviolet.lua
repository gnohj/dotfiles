if vim.g.vscode then
  return {}
end

-- set in ~/.config/colorscheme/colorscheme-vars.sh
-- set in ~/.config/nvim/init.lua
local transparent = vim.g.theme_transparent == "transparent"
return {
  "everviolet/nvim",
  name = "evergarden",
  priority = 1000, -- Colorscheme plugin is loaded first before any other plugins
  opts = {
    theme = {
      variant = "winter", -- 'winter'|'fall'|'spring'|'summer'
      accent = "green",
    },
    editor = {
      transparent_background = true,
      sign = { color = "none" },
      float = {
        color = "mantle",
        invert_border = false,
      },
      completion = {
        color = "surface0",
      },
    },
  },
}
