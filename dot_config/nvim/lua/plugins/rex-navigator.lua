local function focus(dir)
  return function()
    require("vim-rex-navigator").focus(dir)
  end
end

return {
  {
    "pankrashin/vim-rex-navigator",
    keys = {
      { "<c-h>", focus("left"), desc = "Navigate left" },
      { "<c-j>", focus("down"), desc = "Navigate down" },
      { "<c-k>", focus("up"), desc = "Navigate up" },
      { "<c-l>", focus("right"), desc = "Navigate right" },
    },
  },
}
