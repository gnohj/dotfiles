-- LuaSnip is already pulled in as a dependency of blink-cmp; this spec
-- registers custom snippets that surface in the blink-cmp completion menu.
return {
  "L3MON4D3/LuaSnip",
  config = function()
    local ls = require("luasnip")

    -- Markdown snippets. Accept via blink-cmp (<C-y>); <Tab> jumps past
    -- the closing brackets.
    --
    --   ;backlink   →  [[<cursor>]]      (body wikilink, no quotes)
    --   ;tag        →  "[[<cursor>]]"    (frontmatter, YAML-safe quoted)
    ls.add_snippets("markdown", {
      ls.snippet(
        { trig = ";backlink" },
        { ls.text_node("[["), ls.insert_node(1), ls.text_node("]]") },
        { desc = "Obsidian wikilink (body)" }
      ),
      ls.snippet(
        { trig = ";tag" },
        { ls.text_node('"[['), ls.insert_node(1), ls.text_node(']]"') },
        { desc = "Obsidian wikilink (frontmatter, quoted)" }
      ),
    })
  end,
}
