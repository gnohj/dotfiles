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
    -- Save the original show function
    local package_info = require("package-info")
    package_info.setup(opts)
    -- Save the original show function
    local original_show = package_info.show
    -- Override the show function to check for mini.files
    package_info.show = function()
      -- Check if we're in mini.files
      if vim.b.mini_files ~= nil then
        return -- Don't do anything in mini.files
      end
      -- Check if buffer is valid for package.json operations
      if vim.bo.buftype ~= "" then
        return -- Don't do anything for special buffers
      end
      -- Call the original function
      return original_show()
    end

    -- vim.cmd([[highlight PackageInfoUpToDateVersion guifg=]] .. opts.colors.up_to_date)
    vim.cmd([[highlight PackageInfoOutdatedVersion guifg=]] .. opts.colors.outdated)
  end,
}
