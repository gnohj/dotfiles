return {
  "MeanderingProgrammer/render-markdown.nvim",
  opts = {
    -- Mimic org-indent-mode behavior by indenting everything under a heading based on the
    -- level of the heading. Indenting starts from level 2 headings onward.
    indent = {
      -- Turn on / off org-indent-mode
      enabled = true,
      -- Amount of additional padding added for each heading level
      per_level = 2,
      -- Heading levels <= this value will not be indented
      -- Use 0 to begin indenting from the very first level
      skip_level = 1,
      -- Do not indent heading titles, only the body
      skip_heading = false,
    },
    sign = {
      -- Turn on / off sign rendering
      enabled = true,
      -- Applies to background of sign text
      highlight = "RenderMarkdownSign",
    },
    code = {
      sign = true,
      width = "block",
      right_pad = 1,
    },
    heading = {
      sign = true,
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
    },
  },
}
