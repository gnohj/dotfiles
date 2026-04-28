-- LuaSnip is already pulled in as a dependency of blink-cmp; this spec
-- registers custom snippets that surface in the blink-cmp completion menu.
-- Lazy-loaded on InsertEnter — snippets are only useful while editing, and
-- this saves ~2-3ms off startup since the spec used to load eagerly.
return {
  "L3MON4D3/LuaSnip",
  event = "InsertEnter",
  config = function()
    local ls = require("luasnip")
    local s, t, i, f =
      ls.snippet, ls.text_node, ls.insert_node, ls.function_node
    local fmt = require("luasnip.extras.fmt").fmt

    -- Compute today's date for the frontmatter `date:` field.
    local function today()
      return os.date("%Y-%m-%d")
    end

    -- Read available hubs from Notes-Hubs/hubs.md
    local function read_hubs()
      local path = vim.fn.expand("~/Obsidian/second-brain/Notes-Hubs/hubs.md")
      if vim.fn.filereadable(path) == 0 then
        return {}
      end
      local hubs = {}
      for line in io.lines(path) do
        local hub = line:match("^%-%s*(.+)$")
        if hub then
          table.insert(hubs, hub)
        end
      end
      return hubs
    end

    -- Read available tags from Notes-Tags/*.md filenames
    local function read_tags()
      local files = vim.fn.globpath(
        vim.fn.expand("~/Obsidian/second-brain/Notes-Tags"),
        "*.md",
        false,
        true
      )
      local tags = {}
      for _, f in ipairs(files) do
        table.insert(tags, vim.fn.fnamemodify(f, ":t:r"))
      end
      return tags
    end

    -- Build wrapped YAML comment lines. Every line starts with `  # AVAILABLE:`
    -- (2-space indent baked in) so multi-line output aligns under YAML fields,
    -- and `<leader>zc` can strip them all with a single regex.
    local AVAILABLE_MAX = 80
    local function build_available(items)
      if #items == 0 then
        return { "" }
      end
      local indent = "  "
      local prefix = indent .. "# AVAILABLE: "
      local lines = {}
      local current = prefix
      for i, item in ipairs(items) do
        local sep = i < #items and ", " or ""
        local addition = item .. sep
        if #current + #addition > AVAILABLE_MAX and current ~= prefix then
          table.insert(lines, current)
          current = prefix .. addition
        else
          current = current .. addition
        end
      end
      table.insert(lines, current)
      return lines
    end

    local function hubs_available()
      return build_available(read_hubs())
    end

    local function tags_available()
      return build_available(read_tags())
    end

    -- Derive a Title-Cased note title from the filename:
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

    -- Derive a Title-Cased project name from the current working directory.
    -- `~/Obsidian/second-brain/Projects/parents-estate-active` → `Parents Estate Active`
    local function project_name_from_cwd()
      local cwd = vim.fn.getcwd()
      local name = vim.fn.fnamemodify(cwd, ":t")
      return name:gsub("-", " "):gsub("(%a)([%w_']*)", function(first, rest)
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
        { trig = ";backaliaslink" },
        { t("[["), i(1), t("|"), i(2), t("]]") },
        { desc = "Obsidian wikilink with alias (body)" }
      ),
      s(
        { trig = ";tag" },
        { t('"[['), i(1), t(']]"') },
        { desc = "Obsidian wikilink (frontmatter, quoted)" }
      ),
      s(
        { trig = ";todo" },
        { t("- [ ] "), i(1) },
        { desc = "Markdown checkbox" }
      ),
      s(
        { trig = ";today" },
        { f(today) },
        { desc = "Today's date (YYYY-MM-DD)" }
      ),
      s(
        { trig = ";img" },
        { t("!["), i(1), t("]("), i(2), t(")") },
        { desc = "Markdown image (external)" }
      ),
      s(
        { trig = ";imbed" },
        { t("![["), i(1), t("]]") },
        { desc = "Embed image/file (Obsidian wikilink)" }
      ),
      s(
        { trig = ";note-callout" },
        { t({ "> [!NOTE]", "> " }), i(1) },
        { desc = "Callout: note" }
      ),
      s(
        { trig = ";tip-callout" },
        { t({ "> [!TIP]", "> " }), i(1) },
        { desc = "Callout: tip" }
      ),
      s(
        { trig = ";important-callout" },
        { t({ "> [!IMPORTANT]", "> " }), i(1) },
        { desc = "Callout: important" }
      ),
      s(
        { trig = ";warning-callout" },
        { t({ "> [!WARNING] " }), i(1), t({ "", "> " }), i(2) },
        { desc = "Callout: warning (with custom title)" }
      ),
      s(
        { trig = ";caution-callout" },
        { t({ "> [!CAUTION]", "> " }), i(1) },
        { desc = "Callout: caution" }
      ),
      s(
        { trig = ";bug-callout" },
        { t({ "> [!BUG]", "> " }), i(1) },
        { desc = "Callout: bug" }
      ),
      s(
        { trig = ";front-matter-template" },
        fmt(
          [==[
---
date:
  - {}
hubs:
{}
  - {}
tags:
{}
  - "[[{}]]"
urls:
  - {}
---
{}]==],
          {
            f(today),
            f(hubs_available),
            i(1),
            f(tags_available),
            i(2),
            i(3),
            i(0),
          }
        ),
        { desc = "Frontmatter scaffold (no title)" }
      ),
      s(
        { trig = ";note-template" },
        fmt(
          [==[
---
date:
  - {}
hubs:
{}
  - {}
tags:
{}
  - "[[{}]]"
urls:
  - {}
---

# {}

{}
]==],
          {
            f(today),
            f(hubs_available),
            i(1),
            f(tags_available),
            i(2),
            i(3),
            f(title_from_filename),
            i(0),
          }
        ),
        { desc = "Obsidian note scaffold (date+title auto-filled)" }
      ),

      -- ;project-readme — project landing page (purpose, scope, status).
      -- Scaffolds in the project's root directory; project name auto-derived
      -- from cwd via Title-Cased folder name.
      s(
        { trig = ";project-readme" },
        fmt(
          [==[
# {}

> {}

## Status

- Stage: {}
- Started: {}

## Scope

- In: {}
- Out: {}

## Key References

- [[{}]]

{}
]==],
          {
            f(project_name_from_cwd),
            i(1, "One-line purpose"),
            i(2, "active"),
            f(today),
            i(3),
            i(4),
            i(5),
            i(0),
          }
        ),
        { desc = "Project README scaffold" }
      ),

      -- ;project-claude — project-specific instructions (Claude Desktop's
      -- "Set project instructions" equivalent). Layered on top of vault CLAUDE.md
      -- via the directory-cascade.
      s(
        { trig = ";project-claude" },
        fmt(
          [==[
# {} — Project Instructions

This project extends the vault's `CLAUDE.md`. Vault rules (Zettelkasten conventions, hubs/tags, scope boundaries) apply automatically via cascade.

## Context

{}

## Conventions

- {}

## In scope

- {}

## Out of scope

- Task execution → Apple Reminders.
- General atomic notes → `Notes/<hub>/`.
- {}
]==],
          {
            f(project_name_from_cwd),
            i(1, "Status, key stakeholders, what this project is about."),
            i(2, "Project-specific naming, handling, or privacy rules."),
            i(3, "What belongs in this project."),
            i(0, "Anything explicitly excluded from this project."),
          }
        ),
        { desc = "Project CLAUDE.md scaffold (project instructions)" }
      ),

      -- ;project-index — project's internal map (analog to vault's index.md
      -- but scoped to this project only).
      s(
        { trig = ";project-index" },
        fmt(
          [==[
# {} Index

> Map of this project's files. Last updated: {}

## Notes

- {}

## Assets

See `assets/` directory for binaries (PDFs, images, screenshots).

{}
]==],
          {
            f(project_name_from_cwd),
            f(today),
            i(1),
            i(0),
          }
        ),
        { desc = "Project index.md scaffold" }
      ),

      -- ;project-note — minimal frontmatter for project notes.
      -- No `hubs:` (project IS the hub). Just date + title — for casual
      -- captures where the project is the only context that matters.
      s(
        { trig = ";project-note" },
        fmt(
          [==[
---
date:
  - {}
---

# {}

{}
]==],
          {
            f(today),
            f(title_from_filename),
            i(0),
          }
        ),
        { desc = "Project note (minimal: date + title)" }
      ),

      -- ;project-note-tagged — vault-style frontmatter for project notes.
      -- Same look as the main vault `;note-template` but WITHOUT `hubs:`
      -- (project IS the hub). For project notes that ALSO touch a cross-cutting
      -- topic in `Notes-Tags/`, so they appear in vault-wide `gr` results.
      s(
        { trig = ";project-note-tagged" },
        fmt(
          [==[
---
date:
  - {}
tags:
{}
  - "[[{}]]"
urls:
  - {}
---

# {}

{}
]==],
          {
            f(today),
            f(tags_available),
            i(1),
            i(2),
            f(title_from_filename),
            i(0),
          }
        ),
        { desc = "Project note (vault-style frontmatter, no hubs)" }
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
