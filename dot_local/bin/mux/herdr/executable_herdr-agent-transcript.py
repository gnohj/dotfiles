#!/usr/bin/env python3
"""Claude or pi session transcript as text for the herdr scrollback viewer, whose prompt jumps key on `❯ ` lines. Usage: herdr-agent-transcript.py <claude|pi> <session-kind> <session-value> <cwd>"""
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
TOOL_HINT_KEYS = ("description", "command", "file_path", "path", "pattern", "query", "url", "prompt")

# Truecolor SGR matching Claude Code's dark transcript; the viewer renders it through baleia.
RESET = "\x1b[0m"
DIM = "\x1b[2m"
BOLD = "\x1b[1m"
PROMPT_BG = "\x1b[48;2;55;55;55m"
TOOL_DOT = "\x1b[38;2;78;186;101m"
ERROR = "\x1b[38;2;255;107;128m"
CODE = "\x1b[38;2;177;185;249m"
INLINE_CODE = re.compile(r"`([^`\n]+)`")
INLINE_BOLD = re.compile(r"\*\*([^*\n]+)\*\*")
RESULT_PREVIEW = 3


def markdown(line):
    if re.match(r"^#{1,6} ", line):
        return f"{BOLD}{line.lstrip('#').strip()}{RESET}"
    line = INLINE_BOLD.sub(lambda m: f"{BOLD}{m.group(1)}\x1b[22m", line)
    return INLINE_CODE.sub(lambda m: f"{CODE}{m.group(1)}\x1b[39m", line)


def prompt_block(text):
    # The ❯ must follow only SGR codes for the viewer's prompt jumps to find the row.
    lines = text.strip().splitlines() or [""]
    rows = [f"{PROMPT_BG}{BOLD}❯ \x1b[22m{lines[0]} {RESET}"]
    rows += [f"{PROMPT_BG}  {line} {RESET}" for line in lines[1:]]
    return rows + [""]


def reply_block(text):
    lines = text.strip().splitlines() or [""]
    return [f"⏺ {markdown(lines[0])}", *(f"  {markdown(line)}" for line in lines[1:]), ""]


def tool_block(tool):
    return [f"{TOOL_DOT}⏺{RESET} {tool_hint(tool)}"]


def result_block(result):
    content = result.get("content")
    if isinstance(content, list):
        content = "\n".join(part.get("text", "") for part in content if isinstance(part, dict) and part.get("type") == "text")
    lines = [line for line in str(content or "").splitlines() if line.strip()]
    tone = ERROR if result.get("is_error") else DIM
    if not lines:
        return [f"  {DIM}⎿  (no output){RESET}", ""]
    rows = [f"  {DIM}⎿{RESET}  {tone}{lines[0][:160]}{RESET}"]
    rows += [f"     {tone}{line[:160]}{RESET}" for line in lines[1:RESULT_PREVIEW]]
    if len(lines) > RESULT_PREVIEW:
        rows.append(f"     {DIM}… +{len(lines) - RESULT_PREVIEW} lines{RESET}")
    return rows + [""]


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
    data = tool.get("input") or tool.get("arguments") or {}
    hint = next((str(data[key]) for key in TOOL_HINT_KEYS if data.get(key)), "")
    hint = " ".join(hint.split())
    return f"{BOLD}{tool.get('name', 'tool')}{RESET}{DIM}({hint[:100]}{'…' if len(hint) > 100 else ''}){RESET}"


def text_of(parts):
    return "\n".join(p.get("text", "") for p in parts if isinstance(p, dict) and p.get("type") == "text").strip()


def render_claude(entry):
    out = []
    if entry.get("isSidechain"):
        return out
    content = entry.get("message", {}).get("content")
    if entry.get("type") == "user":
        prompt = user_prompt(entry)
        if prompt:
            out += prompt_block(prompt)
        for part in content if isinstance(content, list) else []:
            if isinstance(part, dict) and part.get("type") == "tool_result":
                out += result_block(part)
    elif entry.get("type") == "assistant":
        for part in content or []:
            if isinstance(part, dict) and part.get("type") == "text" and part.get("text", "").strip():
                out += reply_block(part["text"])
            elif isinstance(part, dict) and part.get("type") == "tool_use":
                out += tool_block(part)
    return out


def render_pi(entry):
    out = []
    message = entry.get("message") or {}
    content = message.get("content")
    role = message.get("role")
    if entry.get("type") != "message" or not isinstance(content, list):
        return out
    if role == "user":
        text = text_of(content)
        if text:
            out += prompt_block(text)
    elif role == "assistant":
        for part in content:
            if isinstance(part, dict) and part.get("type") == "text" and part.get("text", "").strip():
                out += reply_block(part["text"])
            elif isinstance(part, dict) and part.get("type") == "toolCall":
                out += tool_block(part)
    elif role == "toolResult":
        out += result_block({"content": content, "is_error": message.get("isError")})
    return out


def render(path, renderer):
    out = []
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if isinstance(entry, dict):
                out += renderer(entry)
    return out


def pi_session(kind, value, cwd):
    # pi reports its session as a file path; only a .jsonl inside pi's own session store is read.
    if kind == "path" and value.endswith(".jsonl"):
        root = os.path.realpath(os.path.join(stores.PI_ROOT, "sessions"))
        real = os.path.realpath(value)
        if real.startswith(root + os.sep) and os.path.isfile(real):
            return real
    return stores.pi_newest_session(cwd)


def main():
    if len(sys.argv) != 5:
        sys.exit("usage: herdr-agent-transcript.py <claude|pi> <session-kind> <session-value> <cwd>")
    agent, kind, value, cwd = sys.argv[1:]
    if agent == "claude":
        if value and not re.fullmatch(r"[0-9A-Za-z-]+", value):
            sys.exit(f"herdr-agent-transcript: invalid session id {value!r}")
        path, renderer = (stores.claude_transcript(value, cwd) if value else stores.claude_newest_session(cwd)), render_claude
    elif agent == "pi":
        path, renderer = pi_session(kind, value, cwd), render_pi
    else:
        sys.exit(f"herdr-agent-transcript: no transcript reader for {agent!r}")
    if not path:
        sys.exit(f"herdr-agent-transcript: no {agent} transcript for {value or cwd}")
    sys.stdout.write("\n".join(render(path, renderer)).rstrip() + "\n")


if __name__ == "__main__":
    main()
