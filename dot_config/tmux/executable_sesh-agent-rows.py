#!/usr/bin/env python3
"""Merge `sesh list --icons` rows with `tmux-dash json` agents.

Emits each sesh row unchanged, then - for rows naming a live tmux session - one
indented child row per agent pane in it. A child row is
`  <glyph> <name> · <state>\t<session:window.pane>`; the tab field is hidden by
fzf's --with-nth and is what enter navigates to.

Argument is a directory holding `sesh`, `agents`, and `theme` (see
sesh-agents.sh). Falls back to the plain sesh list on any parse failure.
"""

import json
import re
import sys

ANSI = re.compile(r"\033\[[0-9;]*m")
RESET = "\033[39m"
NAME_MAX = 18

# Mirrors tmux-dash status_display::{glyph,word}, except Working: fzf renders a static list, so a spinner frame would sit frozen and read as a hang.
INPUT_GLYPH = {"plan": "≡", "question": "?"}
GLYPH = {
    "Working": "➤",
    "Done": "✔",
    "Idle": "✓",
    "Limit": "⊘",
    "NearLimit": "⊙",
}
FALLBACK = {
    "working": "#a3b8c6",
    "input": "#da858e",
    "done": "#da858e",
    "new": "#a7cfbd",
    "limit": "#da858e",
    "near_limit": "#ccd19d",
    "idle": "#dab183",
    "muted": "#9fb7a4",
}


def load_theme(path):
    theme = {}
    try:
        with open(path) as fh:
            for line in fh:
                key, sep, value = line.partition("=")
                if sep:
                    theme[key.strip()] = value.strip().strip('"')
    except OSError:
        pass
    return theme


def truecolor(theme, key):
    digits = theme.get(key, FALLBACK[key]).lstrip("#")
    r, g, b = (int(digits[i : i + 2], 16) for i in (0, 2, 4))
    return "\033[38;2;%d;%d;%dm" % (r, g, b)


def glyph(status, reason):
    if status == "Input":
        return INPUT_GLYPH.get(reason or "", "❯")
    return GLYPH.get(status, "✧")


def word(status, reason, limit_reset):
    if status == "Input":
        return reason if reason in ("permission", "plan", "question") else "input"
    if status == "Limit":
        return "limit %s" % limit_reset if limit_reset else "limit"
    if status == "NearLimit":
        return "near %s" % limit_reset if limit_reset else "near limit"
    return status.lower()


def label(agent):
    # Same precedence as tmux-dash session_display_name; last resort is the window.pane coordinate, not a name that would echo the parent row.
    for key in ("custom_name", "summary", "handle"):
        value = (agent.get(key) or "").strip()
        if value:
            return value
    target = agent.get("pane_target") or ""
    return target.rpartition(":")[2] or "?"


def child_row(agent, color, muted):
    status = agent.get("status") or "Idle"
    reason = agent.get("input_reason")
    name = label(agent)
    if len(name) > NAME_MAX:
        name = name[: NAME_MAX - 1] + "…"
    # Orchestrator children nest one level deeper, matching the sidebar.
    indent = "    " if (agent.get("orch_nest") or "").strip() else "  "
    state = word(status, reason, agent.get("limit_reset"))
    target = agent.get("pane_target") or agent.get("tmux_session") or ""
    head = "%s%s%s %s%s" % (indent, color(status), glyph(status, reason), name, RESET)
    return "%s %s· %s%s\t%s" % (head, muted, state, RESET, target)


def main(directory):
    with open("%s/sesh" % directory) as fh:
        sesh = fh.read().splitlines()
    try:
        with open("%s/agents" % directory) as fh:
            agents = json.load(fh).get("sessions", [])
    except (OSError, ValueError):
        print("\n".join(sesh))
        return

    theme = load_theme("%s/theme" % directory)
    palette = {
        "Working": truecolor(theme, "working"),
        "Input": truecolor(theme, "input"),
        "Done": truecolor(theme, "done"),
        "New": truecolor(theme, "new"),
        "Limit": truecolor(theme, "limit"),
        "NearLimit": truecolor(theme, "near_limit"),
    }
    idle = truecolor(theme, "idle")
    muted = truecolor(theme, "muted")

    by_session = {}
    for agent in agents:
        if agent.get("session_stub"):
            continue
        name = (agent.get("tmux_session") or "").strip()
        if name:
            by_session.setdefault(name, []).append(agent)
    for rows in by_session.values():
        rows.sort(key=lambda a: (a.get("window_pos") or 0, a.get("pane_target") or ""))

    def color(status):
        return palette.get(status, idle)

    seen = set()
    out = []
    for line in sesh:
        out.append(line)
        # sesh orders tmux rows first, so a name's first sighting is the live session, not a same-named zoxide dir.
        name = ANSI.sub("", line).split(" ", 1)[-1].strip()
        if name in seen or name not in by_session:
            continue
        seen.add(name)
        out.extend(child_row(a, color, muted) for a in by_session[name])
    print("\n".join(out))


if __name__ == "__main__":
    main(sys.argv[1])
