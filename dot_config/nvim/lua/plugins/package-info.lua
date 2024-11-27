if vim.g.vscode then
  return {}
end

return {
  "vuki656/package-info.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  ft = "json",
  opts = {
    package_manager = "pnpm",
    autostart = true,
    colors = {
      outdated = "#db4b4b",
    },
    hide_up_to_date = true,
  },
  config = function(_, opts)
    require("package-info").setup(opts)
    -- manually register them https://github.com/vuki656/package-info.nvim/issues/155
    -- vim.cmd([[highlight PackageInfoUpToDateVersion guifg=]] .. opts.colors.up_to_date)
    vim.cmd([[highlight PackageInfoOutdatedVersion guifg=]] .. opts.colors.outdated)
  end,
}
