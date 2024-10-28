local keymap = vim.keymap.set
local v = require("vscode")
local opts = { noremap = true, silent = true }

-- set leader key
keymap("n", "<Space>", "", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

keymap("n", "<leader>nr", function()
  v.action("vscode-neovim.restart")
end)

keymap("n", "<C-d>", "<C-d>zz")
keymap("n", "<C-u>", "<C-u>zz")
keymap("n", "<leader>e", function()
  v.action("workbench.action.toggleSidebarVisibility")
end)

-- VSCode Neovim: Theme changer
-- vim.api.nvim_exec(
--   [[
--   " THEME CHANGER
--   function! SetCursorLineNrColorInsert(mode)
--     " Insert mode: blue
--     if a:mode == "i"
--       call VSCodeNotify('nvim-theme.insert')
--     " Replace mode: red
--     elseif a:mode == "r"
--       call VSCodeNotify('nvim-theme.replace')
--     endif
--   endfunction
--
--   augroup CursorLineNrColorSwap
--     autocmd!
--     autocmd ModeChanged *:[vV\x16]* call VSCodeNotify('nvim-theme.visual')
--     autocmd ModeChanged *:[R]* call VSCodeNotify('nvim-theme.replace')
--     autocmd InsertEnter * call SetCursorLineNrColorInsert(v:insertmode)
--     autocmd InsertLeave * call VSCodeNotify('nvim-theme.normal')
--     autocmd CursorHold * call VSCodeNotify('nvim-theme.normal')
--     autocmd ModeChanged [vV\x16]*:* call VSCodeNotify('nvim-theme.normal')
--   augroup END
--   ]],
--   false
-- )

-- sync system clipboard
vim.opt.clipboard = "unnamedplus"

-- search ignoring case
vim.opt.ignorecase = true

-- disble "ignorecase" option if search pattern contains upper case chars
vim.opt.smartcase = true

-- vscode_call fn
local function vscode_call(action)
  return "<cmd>lua require('vscode-neovim').call('" .. action .. "')<cr>"
end

-- yank to system clipboard
keymap({ "n", "v" }, "<leader>y", '"+y', opts)

-- paste from system clipboard
keymap({ "n", "v" }, "<leader>p", '"+p', opts)

-- better indent handling
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- move text up and down
keymap("v", "J", ":m .+1<CR>==", opts)
keymap("v", "K", ":m .-2<CR>==", opts)
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)

-- paste preserves primal yanked piece
keymap("v", "p", '"_dP', opts)

-- removes highlighting after escaping vim search
keymap("n", "<Esc>", "<Esc>:noh<CR>", opts)

-- call vscode commands from neovim
keymap({ "n", "v" }, "<leader>b", "<cmd>lua require('vscode').action('editor.debug.action.toggleBreakpoint')<CR>")
keymap({ "n", "v" }, "<leader>a", "<cmd>lua require('vscode').action('editor.action.quickFix')<CR>")
keymap({ "n", "v" }, "<leader>sp", "<cmd>lua require('vscode').action('workbench.actions.view.problems')<CR>")
keymap({ "n", "v" }, "<leader>cn", "<cmd>lua require('vscode').action('notifications.clearAll')<CR>")
keymap({ "n", "v" }, "<leader>ff", "<cmd>lua require('vscode').action('workbench.action.quickOpen')<CR>")
keymap({ "n", "v" }, "<leader>cp", "<cmd>lua require('vscode').action('workbench.action.showCommands')<CR>")
keymap({ "n", "v" }, "<leader>pr", "<cmd>lua require('vscode').action('code-runner.run')<CR>")
keymap({ "n", "v" }, "<leader>fd", "<cmd>lua require('vscode').action('editor.action.formatDocument')<CR>")
--  Git Hub
keymap("n", "<leader>gr", function()
  v.action("openInGitHub.openProject")
end)
keymap("n", "<leader>gf", function()
  v.action("openInGitHub.openFile")
end)
keymap("n", "<leader>gl", function()
  v.action("issue.copyGithubPermalink")
end)
keymap("n", "<leader>gp", function()
  v.action("pr.openPullRequestOnGitHub")
end)
keymap("n", "<leader>ga", function()
  v.action("openInGitHub.openActions")
end)
-- Git Lens --
keymap({ "n", "v" }, "<leader>gg", vscode_call("gitlens.openFileOnRemote"))
keymap({ "n", "v" }, "<leader>gh", vscode_call("gitlens.showFileHistoryView"))

-- Quickscope --
vim.cmd([[
  highlight QuickScopePrimary guifg='#afff5f' gui=underline ctermfg=155 cterm=underline
  highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=81 cterm=underline
]])
vim.g.qs_highlight_on_keys = { "f", "F", "t", "T" }
