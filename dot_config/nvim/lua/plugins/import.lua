return {
  "piersolenski/import.nvim",
  dependencies = {
    "folke/snacks.nvim",
  },
  opts = {
    picker = "snacks",
    insert_at_top = true,
  },
  config = function(_, opts)
    require("import").setup(opts)

    -- Override the snacks picker to use ivy layout
    package.loaded["import.pickers.snacks"] = function(imports, filetype, on_select)
      local formatted_imports = {}
      for _, result in ipairs(imports) do
        table.insert(formatted_imports, { text = result })
      end

      require("snacks").picker({
        title = " Imports ",
        items = formatted_imports,
        confirm = function(picker)
          picker:close()
          local results = {}
          local selected = picker:selected()
          if selected and #selected > 0 then
            for _, selected_item in ipairs(selected) do
              if selected_item and selected_item.text then
                table.insert(results, selected_item.text)
              end
            end
          else
            local current_selection = picker:current()
            if current_selection and current_selection.text then
              table.insert(results, current_selection.text)
            end
          end
          on_select(results)
        end,
        format = "text",
        formatters = { text = { ft = filetype } },
        layout = {
          layout = {
            box = "vertical",
            backdrop = false,
            row = -1,
            width = 0,
            height = 0.5,
            border = "top",
            title = " {title} ",
            title_pos = "left",
            { win = "input", height = 1, border = "bottom" },
            { win = "list", border = "none" },
          },
        },
      })
    end
  end,
  keys = {
    {
      "<leader>i",
      function()
        require("import").pick()
      end,
      desc = "Import Statements",
    },
  },
}
