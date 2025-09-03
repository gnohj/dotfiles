if vim.g.vscode then
  return {}
end

-- Helper function to detect package manager
local function detect_package_manager(cwd)
  local old_cwd = vim.fn.getcwd()
  if cwd then
    vim.cmd("cd " .. cwd)
  end

  local pm = "npm" -- default
  if vim.fn.filereadable("pnpm-lock.yaml") == 1 then
    pm = "pnpm"
  elseif vim.fn.filereadable("yarn.lock") == 1 then
    pm = "yarn"
  elseif vim.fn.filereadable("package-lock.json") == 1 then
    pm = "npm"
  elseif vim.fn.filereadable("bun.lockb") == 1 then
    pm = "bun"
  end

  vim.cmd("cd " .. old_cwd)
  return pm
end

-- Helper function to get scripts from package.json
local function get_package_scripts(package_path)
  local package_file = package_path .. "/package.json"
  if vim.fn.filereadable(package_file) == 0 then
    return {}
  end

  local content = vim.fn.readfile(package_file)
  local package_data = vim.fn.json_decode(table.concat(content, "\n"))

  if not package_data or not package_data.scripts then
    return {}
  end

  local scripts = {}
  for script_name, _ in pairs(package_data.scripts) do
    table.insert(scripts, script_name)
  end
  table.sort(scripts)
  return scripts
end

return {
  {
    "stevearc/overseer.nvim",
    enabled = false,
    config = function()
      require("overseer").setup({
        templates = { "builtin" },
      })

      -- Override built-in npm template to be dynamic
      require("overseer").register_template({
        name = "pm",
        builder = function(params)
          local pm = detect_package_manager()
          return {
            cmd = { pm },
            args = { "run", params.script },
            components = { "default" },
          }
        end,
        params = {
          script = {
            type = "enum",
            choices = function()
              return get_package_scripts(".")
            end,
          },
        },
        priority = 60,
        condition = {
          callback = function()
            return vim.fn.filereadable("package.json") == 1
          end,
        },
      })

      -- Root workspace template with dynamic package manager
      require("overseer").register_template({
        name = "root",
        builder = function(params)
          -- Find workspace root
          local root = vim.fn.findfile("pnpm-workspace.yaml", ".;")
          if root == "" then
            root = vim.fn.findfile("package.json", ".;")
            if root ~= "" then
              root = vim.fn.fnamemodify(root, ":h")
            else
              root = vim.fn.getcwd()
            end
          else
            root = vim.fn.fnamemodify(root, ":h")
          end
          local pm = detect_package_manager(root)

          return {
            cmd = { pm },
            args = { "run", params.script },
            cwd = root,
            components = { "default" },
          }
        end,
        params = {
          script = {
            type = "enum",
            choices = function()
              -- Find root and get its scripts
              local root = vim.fn.findfile("pnpm-workspace.yaml", ".;")
              if root == "" then
                root = vim.fn.findfile("package.json", ".;")
                if root ~= "" then
                  root = vim.fn.fnamemodify(root, ":h")
                else
                  root = vim.fn.getcwd()
                end
              else
                root = vim.fn.fnamemodify(root, ":h")
              end
              return get_package_scripts(root)
            end,
          },
        },
        condition = {
          callback = function()
            return vim.fn.filereadable("package.json") == 1
          end,
        },
      })
    end,
    opts = {
      -- Setup DAP later when lazy-loading the plugin.
      dap = false,
      task_list = {
        default_detail = 2,
        direction = "bottom",
        max_width = { 600, 0.7 },
      },
      form = {
        win_opts = { winblend = 0 },
      },
      confirm = {
        win_opts = { winblend = 5 },
      },
      task_win = {

        win_opts = { winblend = 5 },
      },
    },
    keys = {
      { "<leader>ow", false },
      { "<leader>oi", false },
      { "<leader>oo", false },
      {
        "<leader>ot",
        "<cmd>OverseerToggle<cr>",
        desc = "Overseer Toggle task window",
      },
      {
        "<leader>o<",
        function()
          local overseer = require("overseer")

          local tasks = overseer.list_tasks({ recent_first = true })
          if vim.tbl_isempty(tasks) then
            vim.notify("No tasks found", vim.log.levels.WARN)
          else
            overseer.run_action(tasks[1], "restart")
            overseer.open({ enter = false })
          end
        end,
        desc = "Overseer Restart last task",
      },
      {
        "<leader>or",
        function()
          local overseer = require("overseer")

          overseer.run_template({}, function(task)
            if task then
              overseer.open({ enter = false })
            end
          end)
        end,
        desc = "Overseer Run task",
      },
      -- {
      --   "<leader>or",
      --   function()
      --     require("overseer").run_template({ name = "pm" })
      --   end,
      --   desc = "Run local task",
      -- },
      -- {
      --   "<leader>oR",
      --   function()
      --     require("overseer").run_template({ name = "root" })
      --   end,
      --   desc = "Run workspace task",
      -- },
    },
  },
}
