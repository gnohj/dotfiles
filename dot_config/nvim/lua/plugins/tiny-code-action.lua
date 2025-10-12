-- https://github.com/rachartier/tiny-code-action.nvim
return {
  "rachartier/tiny-code-action.nvim",
  lazy = true,
  opts = {
    picker = {
      "buffer",
      opts = {
        hotkeys = true,
        auto_preview = true,
        -- Use numeric labels.
        hotkeys_mode = function(titles)
          return vim
            .iter(ipairs(titles))
            :map(function(i)
              return tostring(i)
            end)
            :totable()
        end,
      },
    },
  },
}
