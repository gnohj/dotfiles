#!/usr/bin/env python3
"""Claude session transcript as text for the herdr scrollback viewer, whose prompt jumps key on `❯ ` lines. Usage: herdr-claude-transcript.py <session-id> <cwd>"""
import json
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import herdr_agent_stores as stores  # noqa: E402

REMINDER = re.compile(r"<system-reminder>.*?</system-reminder>", re.S)
COMMAND_NAME = re.compile(r"<command-name>(.*?)</command-name>", re.S)
COMMAND_ARGS = re.compile(r"<command-args>(.*?)</command-args>", re.S)
TOOL_HINT_KEYS = ("description", "command", "file_path", "pattern", "query", "url", "prompt")


def block(marker, text):
    lines = text.strip().splitlines() or [""]
    return [f"{marker}{lines[0]}", *(f"  {line}" for line in lines[1:]), ""]


def user_prompt(entry):
    if entry.get("isMeta") or entry.get("isCompactSummary"):
        return None
    content = entry.get("message", {}).get("content")
    if isinstance(content, str):
        if content.startswith(("<local-command-", "<local-command-caveat")):
            return None
        name = COMMAND_NAME.search(content)
        if name:
            args = COMMAND_ARGS.search(content)
            return f"{name.group(1).strip()} {args.group(1).strip() if args else ''}".strip()
        text = REMINDER.sub("", content).strip()
        return text or None
    if not isinstance(content, list) or any(b.get("type") == "tool_result" for b in content if isinstance(b, dict)):
        return None
    parts = []
    for part in content:
        if not isinstance(part, dict):
            continue
        if part.get("type") == "text":
            parts.append(REMINDER.sub("", part.get("text", "")).strip())
        elif part.get("type") == "image":
            parts.append("[image]")
    text = "\n".join(p for p in parts if p)
    return text or None


def tool_hint(tool):
    data = tool.get("input") or {}
    hint = next((str(data[key]) for key in TOOL_HINT_KEYS if data.get(key)), "")
    hint = " ".join(hint.split())
    return f"{tool.get('name', 'tool')}({hint[:100]}{'…' if len(hint) > 100 else ''})"


def render(path):
    out = []
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if not isinstance(entry, dict) or entry.get("isSidechain"):
                continue
            if entry.get("type") == "user":
                prompt = user_prompt(entry)
                if prompt:
                    out += block("❯ ", prompt)
            elif entry.get("type") == "assistant":
                for part in entry.get("message", {}).get("content") or []:
                    if not isinstance(part, dict):
                        continue
                    if part.get("type") == "text" and part.get("text", "").strip():
                        out += block("⏺ ", part["text"])
                    elif part.get("type") == "tool_use":
                        out += block("⏺ ", tool_hint(part))
    return out


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: herdr-claude-transcript.py <session-id> <cwd>")
    session_id, cwd = sys.argv[1], sys.argv[2]
    if session_id and not re.fullmatch(r"[0-9A-Za-z-]+", session_id):
        sys.exit(f"herdr-claude-transcript: invalid session id {session_id!r}")
    path = stores.claude_transcript(session_id, cwd) if session_id else stores.claude_newest_session(cwd)
    if not path:
        sys.exit(f"herdr-claude-transcript: no transcript for session {session_id or '?'} in {cwd}")
    sys.stdout.write("\n".join(render(path)).rstrip() + "\n")


if __name__ == "__main__":
    main()
