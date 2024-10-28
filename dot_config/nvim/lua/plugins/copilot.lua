return {
  "github/copilot.vim",
  config = function()
    vim.keymap.set("i", "<A-j>", 'copilot#Accept("<CR>")', { expr = true, replace_keycodes = false })
    vim.keymap.del("i", "<Tab>")
    vim.g.copilot_no_tab_map = true
    vim.g.copilot_assume_mapped = true
    vim.keymap.set("i", "<A-w>", "<Plug>(copilot-accept-word)")
    vim.keymap.set("i", "<A-n>", "<Plug>(copilot-next)")
    -- enable/disable copilot
    vim.keymap.set("n", "<leader>ce", "<cmd>Copilot enable<CR>", { desc = "Enable Copilot" })
    vim.keymap.set("n", "<leader>cd", "<cmd>Copilot disable<CR>", { desc = "Disable Copilot" })
  end,
}
