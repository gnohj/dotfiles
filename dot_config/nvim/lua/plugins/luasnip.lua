-- LuaSnip is already pulled in as a dependency of blink-cmp; this spec
-- registers custom snippets that surface in the blink-cmp completion menu.
return {
  "L3MON4D3/LuaSnip",
  config = function()
    local ls = require("luasnip")
    local s, t, i, f = ls.snippet, ls.text_node, ls.insert_node, ls.function_node
    local fmt = require("luasnip.extras.fmt").fmt

    -- Compute today's date for the frontmatter `date:` field.
    local function today()
      return os.date("%Y-%m-%d")
    end

    -- Derive a Title-Cased note title from the filename, mirroring the
    -- behavior of the `<leader>zn` keymap:
    -- `2026-04-26_Markdown-Oxide.md` → `Markdown Oxide`
    local function title_from_filename()
      local filename = vim.fn.expand("%:t:r")
      return filename
        :gsub("^%d%d%d%d%-%d%d%-%d%d_", "")
        :gsub("-", " ")
        :gsub("(%a)([%w_']*)", function(first, rest)
          return first:upper() .. rest:lower()
        end)
    end

    -- Markdown snippets. Accept via blink-cmp (<C-y>); <Tab> jumps to
    -- the next placeholder.
    --
    --   ;backlink        →  [[<cursor>]]                  (body wikilink)
    --   ;tag             →  "[[<cursor>]]"                (frontmatter, YAML-safe)
    --   ;note-template   →  full Templates/note.md scaffold with date+title filled in
    --   <lang>           →  fenced code block in <lang> with cursor inside
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
      s(
        { trig = ";note-template" },
        fmt(
          [==[
---
date:
  - {}
hubs:
  - {}
tags:
  - "[[{}]]"
urls:
  - {}
---

# {}

{}
]==],
          {
            f(today),
            i(1),
            i(2),
            i(3),
            f(title_from_filename),
            i(0),
          }
        ),
        { desc = "Obsidian note scaffold (date+title auto-filled)" }
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
