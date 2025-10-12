return {
  "windwp/nvim-ts-autotag",
  ft = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  conifg = function()
    require("nvim-ts-autotag").setup()
  end,
}
