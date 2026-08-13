"""Sidebar label geometry, shared by every writer that paints a herdr metadata row.

herdr puts a workspace's glyph inside its LABEL (`🖥️ gnohj`, `🌿 repo`, `└ <task>`, and firstmate's
patched `⛵⠀sm-<id>`), so row 0's text starts a few cells in while every row below it starts at the
edge. Each writer owns different tokens on different rows - herdr-git-status.sh row 2,
herdr-thread-status.py row 3, herdr-sysinfo.py rows 2-4 - so they all need the same answer to "how
far in does this label's text start". That answer lives here once rather than in three copies.

The pad is U+2800 BRAILLE PATTERN BLANK, never spaces: herdr trims leading whitespace from a token
value (plain space, NBSP and U+2007 figure space all verified stripped), while U+2800 survives
because it is a printable symbol rather than whitespace, and still renders as one blank cell.
"""
import unicodedata

INDENT_CELL = "⠀"
_VARIATION_SELECTOR_16 = "️"
_ZERO_WIDTH = ("Mn", "Me", "Cf")


def _cells(text):
    """Terminal columns `text` occupies.

    U+FE0F is why this is not a plain east_asian_width sum: it carries no width itself but switches
    the character BEFORE it to emoji presentation, which renders 2 columns wide. `🖥` is East Asian
    Width "N" on its own, so `🖥️ gnohj` measures 2 without this rule and 3 with it - and 3 is what
    the terminal actually draws.
    """
    total = 0
    for i, ch in enumerate(text):
        if ch == _VARIATION_SELECTOR_16 or unicodedata.category(ch) in _ZERO_WIDTH:
            continue
        wide = unicodedata.east_asian_width(ch) in ("W", "F")
        if not wide and text[i + 1:i + 2] == _VARIATION_SELECTOR_16:
            wide = True
        total += 2 if wide else 1
    return total


def glyph_run(label):
    """Length in CHARACTERS of the leading glyph plus its separator, or 0 when there is no glyph.

    Covers both spellings in play: `🚢 fm-personal` and `└ <task>` separate with an ASCII space,
    while firstmate's patched `⛵⠀sm-<id>` uses U+2800 - deliberately, because an ASCII space there
    splits the label when it rides an unquoted shell argument, which is a real path in that codebase.
    """
    text = label or ""
    i = 0
    while i < len(text) and not text[i].isascii():
        i += 1
    if i == 0:
        return 0
    return i + 1 if text[i:i + 1] == " " else i


def bare_label(label):
    """Label with any leading glyph removed.

    Everything that keys off a label goes through here so the glyph stays presentation: an earlier
    matcher held 🦜 inside its own constant, and changing the sidebar glyph silently reopened the
    very row that matcher existed to suppress.
    """
    return (label or "")[glyph_run(label):].strip()


def row_indent(label):
    """Blank cells that line a continuation row up under the label's text; "" when there is no glyph.

    Measured per label rather than assumed: `└ ` is 2 cells, an emoji plus a space is 3.
    """
    run = glyph_run(label)
    if not run:
        return ""
    return INDENT_CELL * _cells((label or "")[:run])


def indent_first(tokens, label, order):
    """Indent one row by padding the first LIT token in `order`. Mutates and returns `tokens`.

    Only the first lit token takes the pad, because that is what actually starts the row, and which
    one that is varies per workspace - a ticket with no PR leads with $jira, one with approvals
    leads with $pr_on.
    """
    pad = row_indent(label)
    if not pad:
        return tokens
    for name in order:
        if tokens.get(name):
            tokens[name] = pad + tokens[name]
            break
    return tokens
