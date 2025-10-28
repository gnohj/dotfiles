-- Lazyvim will call this plugin via autocmd: on readpost, insertleave, writepost
return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        yaml = { "actionlint" }, -- only does workflow files
        markdown = {}, -- Disable markdownlint-cli2 from LazyVim markdown extra
      },
      linters = {
        actionlint = {
          condition = function(ctx)
            return ctx.filename:match("%.github/workflows/.*%.ya?ml$")
          end,
        },
      },
    },
  },
}
