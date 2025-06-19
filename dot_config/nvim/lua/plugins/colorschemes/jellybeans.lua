if vim.g.vscode then
  return {}
end

-- https://github.com/WTFox/jellybeans.nvim
return {
  "wtfox/jellybeans.nvim",
  name = "jellybeans",
  lazy = true,
  priority = 1000,
  opts = {
    transparent = true,
  }, -- Optional
}
