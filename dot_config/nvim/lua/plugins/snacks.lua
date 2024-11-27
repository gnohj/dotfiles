if vim.g.vscode then
  return {}
end

return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    -- Configure the dashboard
    opts.dashboard = {
      preset = {
        header = [[
                                                                    
      ████ ██████           █████      ██                     
     ███████████             █████                             
     █████████ ███████████████████ ███   ███████████   
    █████████  ███    █████████████ █████ ██████████████   
   █████████ ██████████ █████████ █████ █████ ████ █████   
 ███████████ ███    ███ █████████ █████ █████ ████ █████  
██████  █████████████████████ ████ █████ █████ ████ ██████ 

 [@gnohj]
]],
      },
    }

    -- Configure LazyGit
    opts.lazygit = {
      -- Automatically configure lazygit to use the current colorscheme
      configure = true,
      -- Extra configuration for lazygit that will be merged with the default
      config = {
        os = { editPreset = "nvim-remote" },
        gui = { nerdFontsVersion = "3" },
      },
      theme_path = vim.fs.normalize(vim.fn.stdpath("cache") .. "/lazygit-theme.yml"),
      -- Theme for lazygit
      theme = {
        [241] = { fg = "Special" },
        activeBorderColor = { fg = "MatchParen", bold = true },
        cherryPickedCommitBgColor = { fg = "Identifier" },
        cherryPickedCommitFgColor = { fg = "Function" },
        defaultFgColor = { fg = "Normal" },
        inactiveBorderColor = { fg = "FloatBorder" },
        optionsTextColor = { fg = "Function" },
        searchingActiveBorderColor = { fg = "MatchParen", bold = true },
        selectedLineBgColor = { bg = "Visual" }, -- Set to `default` to have no background colour
        unstagedChangesColor = { fg = "DiagnosticError" },
      },
      win = {
        style = "lazygit",
      },
    }

    -- Ensure the LazyGit theme and config are applied

    return opts
  end,
}
