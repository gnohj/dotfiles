if vim.g.vscode then
  return {}
end

-- local function update_search_dirs(dirs)
--   local cwd = vim.fn.getcwd()
--   local egrep_actions = require("telescope._extensions.egrepify.actions")
--   local telescope = require("telescope")
--   local ivy_theme = require("telescope.themes").get_ivy({
--     layout_config = {
--       preview_width = 0.7,
--       height = 0.7,
--     },
--   })
--
--   -- Merge ivy theme options with egrepify settings
--   local egrepify_opts = vim.tbl_extend("force", ivy_theme, {
--     search_dirs = dirs,
--     vimgrep_arguments = {
--       "rg",
--       "--no-heading",
--       "--with-filename",
--       "--line-number",
--       "--column",
--       "--smart-case",
--       "--hidden",
--       "--glob",
--       "!**/node_modules/*",
--       "--hidden",
--       "--glob",
--       "!**/.git/*",
--       "--hidden",
--       "--glob",
--       "!pnpm-lock.yaml",
--     },
--     lnum_hl = "LineNr",
--     prefixes = {
--       ["!"] = {
--         flag = "invert-match",
--       },
--       ["^"] = false,
--       ["#"] = {
--         flag = "glob",
--         cb = function(input)
--           return string.format([[*.{%s}]], input)
--         end,
--       },
--       [">"] = {
--         flag = "glob",
--         cb = function(input)
--           return string.format([[**/{%s}*/**]], input)
--         end,
--       },
--       ["&"] = {
--         flag = "glob",
--         cb = function(input)
--           return string.format([[*{%s}*]], input)
--         end,
--       },
--     },
--     cwd = cwd,
--     mappings = {
--       i = {
--         ["<C-z>"] = egrep_actions.toggle_prefixes,
--         ["<C-a>"] = egrep_actions.toggle_and,
--         ["<C-r>"] = egrep_actions.toggle_permutations,
--       },
--     },
--     prompt_title = "  Live Grep (egrepify) " .. cwd,
--   })
--
--   telescope.extensions.egrepify.egrepify(egrepify_opts)
--   print("Search directories updated to: " .. vim.inspect(dirs))
-- end
--
-- vim.api.nvim_create_user_command("Dirs", function(args)
--   local dirs = vim.split(args.args, ",") -- Split input by commas
--   update_search_dirs(dirs)
-- end, { nargs = 1 })

return {
  "fdschmidt93/telescope-egrepify.nvim",
  enabled = false,
  dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
}
