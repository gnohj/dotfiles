local function jira_provider()
  if not (vim.env.JIRA_EMAIL and vim.env.JIRA_API_TOKEN) then
    return nil
  end
  return {
    base_url = "https://ihm-it.atlassian.net",
    email = vim.env.JIRA_EMAIL,
    token = vim.env.JIRA_API_TOKEN,
    auth_method = "basic",
    api_type = "cloud",
  }
end

return {
  "emrearmagan/atlas.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "esmuellert/codediff.nvim",
  },
  cmd = "Atlas",
  keys = {
    { "<leader>gA", "<cmd>Atlas<cr>", desc = "Atlas" },
  },
  opts = function()
    return {
      ui = { picker = "snacks" },
      providers = {
        github = {},
        jira = jira_provider(),
      },
    }
  end,
}
