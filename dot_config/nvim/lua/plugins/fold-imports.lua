return {
  {
    "dmtrKovalenko/fold-imports.nvim",
    build = function()
      -- Patch the file after installation/update (backwards-compatible fix)
      local file_path = vim.fn.stdpath("data")
        .. "/lazy/fold-imports.nvim/lua/fold_imports.lua"
      local file = io.open(file_path, "r")
      if file then
        local content = file:read("*all")
        file:close()

        -- Apply the backwards-compatible treesitter API fix
        content = content:gsub(
          "for _, node, _ in query:iter_captures%(root, bufnr%) do",
          "for _, node in query:iter_captures(root, bufnr) do"
        )

        file = io.open(file_path, "w")
        if file then
          file:write(content)
          file:close()
        end
      end
    end,
    config = function()
      require("fold_imports").setup({
        auto_fold = true, -- Auto fold imports on file open
        fold_level = 99, -- Only fold imports, not other code
      })
    end,
  },
}
