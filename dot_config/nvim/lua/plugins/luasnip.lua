-- LuaSnip is already pulled in as a dependency of blink-cmp; this spec
-- registers custom snippets that surface in the blink-cmp completion menu.
return {
  "L3MON4D3/LuaSnip",
  config = function()
    local ls = require("luasnip")
    local s, t, i = ls.snippet, ls.text_node, ls.insert_node

    -- Markdown snippets. Accept via blink-cmp (<C-y>); <Tab> jumps past
    -- the closing brackets / end of fence.
    --
    --   ;backlink   →  [[<cursor>]]               (body wikilink)
    --   ;tag        →  "[[<cursor>]]"             (frontmatter, YAML-safe)
    --   <lang>      →  fenced code block in <lang> with cursor inside
    local snippets = {
      s(
        { trig = ";backlink" },
        { t("[["), i(1), t("]]") },
        { desc = "Obsidian wikilink (body)" }
      ),
      s(
        { trig = ";tag" },
        { t('"[['), i(1), t(']]"') },
        { desc = "Obsidian wikilink (frontmatter, quoted)" }
      ),
    }

    -- Fenced code block snippets for common languages.
    -- Trigger: `;<lang>` (e.g. `;bash`, `;lua`) — keeps consistent with
    -- the `;backlink` / `;tag` style and avoids matching mid-prose.
    local function code_block(lang)
      return s({
        trig = ";" .. lang,
        name = "Codeblock",
        desc = lang .. " codeblock",
      }, {
        t({ "```" .. lang, "" }),
        i(1),
        t({ "", "```" }),
      })
    end

    local languages = {
      "txt",
      "lua",
      "sql",
      "go",
      "regex",
      "bash",
      "markdown",
      "markdown_inline",
      "yaml",
      "json",
      "jsonc",
      "cpp",
      "csv",
      "java",
      "javascript",
      "jsx",
      "typescript",
      "tsx",
      "python",
      "dockerfile",
      "html",
      "css",
      "templ",
      "php",
    }

    for _, lang in ipairs(languages) do
      table.insert(snippets, code_block(lang))
    end

    ls.add_snippets("markdown", snippets)
  end,
}
