local colors = require("config.colors")

return {
  "vuki656/package-info.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  ft = "json",
  opts = {
    package_manager = "pnpm",
    autostart = true,
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
      -- Skip virtual / URI-scheme buffers (octo://, gitdiff://, diffview://,
      -- fugitive://, etc.). Octo's review layout opens diff buffers named
      -- `package.json` but their "directory" is a fake URI — `jobstart`
      -- then fails with E475 (expected valid directory). The buftype
      -- check above doesn't catch these because Octo leaves it empty.
      local bufname = vim.api.nvim_buf_get_name(0)
      if bufname == "" or bufname:match("^%w+://") then
        return
      end
      if vim.fn.isdirectory(vim.fn.fnamemodify(bufname, ":p:h")) == 0 then
        return
      end
      -- Call the original function
      return original_show()
    end

    -- vim.cmd([[highlight PackageInfoUpToDateVersion guifg=]] .. opts.colors.up_to_date)
    vim.cmd(
      [[highlight PackageInfoOutdatedVersion guifg=]] .. colors["gnohj_color11"]
    )
  end,
}
