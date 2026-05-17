-- Lazyvim will call this plugin via autocmd: on readpost, insertleave, writepost
return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        yaml = { "actionlint" }, -- only does workflow files
        ["yaml.github"] = { "actionlint" },
        markdown = {}, -- Disable markdownlint-cli2 from LazyVim markdown extra
      },
      linters = {
        actionlint = {
          -- actionlint is a workflow-only linter. Pointing it at composite
          -- action.yml files under .github/actions/ produces false errors
          -- ("on" / "jobs" missing) because those files use a different
          -- schema (runs/inputs/outputs). Restrict to workflows only.
          condition = function(ctx)
            return ctx.filename:match("%.github/workflows/.*%.ya?ml$") ~= nil
          end,
        },
      },
    },
  },
}
