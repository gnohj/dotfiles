#!/usr/bin/env python3
"""Rows for herdr-prompt-picker.sh: every skill/command the given harness can invoke, as `insert\tdisplay\tpath\tkey`."""
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True

HOME = Path.home()
DIM, NAME, TAG, RESET = "\033[2m", "\033[1m", "\033[36m", "\033[0m"


def description(path):
    try:
        lines = path.read_text(errors="replace").splitlines()
    except OSError:
        return ""
    if not lines or lines[0].strip() != "---":
        return ""
    for i, line in enumerate(lines[1:], 1):
        if line.strip() == "---":
            return ""
        if line.startswith("description:"):
            value = line.split(":", 1)[1].strip()
            if value in ("", "|", ">", "|-", ">-"):
                block = []
                for nxt in lines[i + 1:]:
                    if nxt and not nxt[0].isspace():
                        break
                    block.append(nxt.strip())
                value = " ".join(b for b in block if b)
            return value.strip("'\"")
    return ""


def skills(root):
    return sorted(root.glob("*/SKILL.md")) if root.is_dir() else []


def commands(root):
    return sorted(p for p in root.glob("*.md") if p.stem != "README") if root.is_dir() else []


def claude_plugins():
    try:
        data = json.loads((HOME / ".claude/plugins/installed_plugins.json").read_text())
    except (OSError, ValueError):
        return
    for key, installs in data.get("plugins", {}).items():
        if not installs:
            continue
        plugin, base = key.split("@", 1)[0], Path(installs[0].get("installPath", ""))
        for p in skills(base / "skills"):
            yield f"/{plugin}:{p.parent.name}", p, plugin
        for p in commands(base / "commands"):
            yield f"/{plugin}:{p.stem}", p, plugin


def pi_dirs(key):
    try:
        data = json.loads((HOME / ".pi/agent/settings.json").read_text())
    except (OSError, ValueError):
        return []
    return [Path(os.path.expanduser(d)) for d in data.get(key, [])]


def real_binary(name):
    try:
        out = subprocess.run(["mise", "which", name], capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None
    return Path(os.path.realpath(out)) if out else None


def pi_builtins():
    # pi ships its command table with each release, so reading it at runtime tracks pi upgrades.
    binary = real_binary("pi")
    for parent in (binary.parents if binary else []):
        table = parent / "docs/slash-commands.md"
        if table.is_file():
            for m in re.finditer(r"^\| `/([a-z0-9-]+)[^`]*` \| (.+?) \|$", table.read_text(), re.M):
                yield m.group(1), m.group(2)
            return


def enclosing_object(data, pos):
    # Minified literals list fields in any order, so walk out to the braces around the type field.
    depth, i = 0, pos
    while i > pos - 2000:
        c = data[i]
        if c == 0x7D:
            depth += 1
        elif c == 0x7B:
            if depth == 0:
                break
            depth -= 1
        i -= 1
    else:
        return None
    depth, j = 0, i
    while j < i + 4000:
        c = data[j]
        if c == 0x7B:
            depth += 1
        elif c == 0x7D:
            depth -= 1
            if depth == 0:
                return data[i:j + 1]
        elif c == 0x22:
            j = data.find(b'"', j + 1)
            if j < 0:
                return None
        j += 1
    return None


def top_level(obj):
    # Drop nested {...} so a sub-object's name cannot stand in for the command's own.
    out, depth = bytearray(), 0
    for c in obj[1:-1]:
        if c == 0x7B:
            depth += 1
        elif c == 0x7D:
            depth -= 1
        elif depth == 0:
            out.append(c)
    return bytes(out)


def claude_builtins():
    # The commands exist only inside Claude's ~200MB binary, so cache the scan per binary version.
    binary = real_binary("claude")
    if not binary or not binary.is_file():
        return []
    st = binary.stat()
    stamp = hashlib.sha1(f"{binary}:{st.st_size}:{st.st_mtime_ns}".encode()).hexdigest()[:16]
    cache = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / f"herdr-prompt-picker/claude-builtins-{stamp}.tsv"
    try:
        return [tuple(line.split("\t", 1)) for line in cache.read_text().splitlines()]
    except OSError:
        pass
    data = binary.read_bytes()
    found = {}
    for m in re.finditer(rb'type:"(?:local|local-jsx|prompt)"', data):
        obj = enclosing_object(data, m.start())
        if not obj:
            continue
        top = top_level(obj)
        name = re.search(rb'(?<![A-Za-z])name:"([a-z][a-z0-9-]*)"', top)
        desc = re.search(rb'description:"([^"]*)"', top) or re.search(rb'get description\(\)\{return[^{}]*:"([^"]*)"', obj)
        # Conditional isEnabled checks cannot be evaluated here, so only always-false ones are dropped.
        disabled = re.search(rb"isEnabled(?::\(\)=>|\(\)\{return ?)!1(?![0-9])", top)
        if name and desc and b"isHidden:!0" not in top and not disabled:
            found.setdefault(name.group(1).decode(), desc.group(1).decode(errors="replace"))
    found = list(found.items())
    found.sort()
    cache.parent.mkdir(parents=True, exist_ok=True)
    for old in cache.parent.glob("claude-builtins-*.tsv"):
        old.unlink()
    cache.write_text("".join(f"{n}\t{d}\n" for n, d in found))
    return found


def entries(agent, project):
    if agent == "pi":
        for d in pi_dirs("skills") + [project / ".pi/skills", project / ".agents/skills"]:
            for p in skills(d):
                yield f"/skill:{p.parent.name}", p, "skill"
        for d in pi_dirs("prompts") + [project / ".pi/prompts"]:
            for p in commands(d):
                yield f"/{p.stem}", p, "prompt"
        for name, desc in pi_builtins():
            yield f"/{name}", desc, "built-in"
        return
    # Claude Code, and any other harness, which shares the ~/.claude trees.
    for d in (HOME / ".claude/skills", project / ".claude/skills"):
        for p in skills(d):
            yield f"/{p.parent.name}", p, "skill"
    for d in (HOME / ".claude/commands", project / ".claude/commands"):
        for p in commands(d):
            yield f"/{p.stem}", p, "command"
    if agent == "claude":
        yield from claude_plugins()
        for name, desc in claude_builtins():
            yield f"/{name}", desc, "built-in"


def main():
    agent, project = sys.argv[1], Path(sys.argv[2])
    seen = set()
    for insert, path, tag in entries(agent, project):
        # A command wrapping the same-named skill adds nothing.
        name = insert.rsplit(":", 1)[-1].lstrip("/")
        if name in seen and tag in ("command", "prompt"):
            continue
        seen.add(name)
        if tag == "built-in":
            desc, preview, key = path, f"builtin:{path}", f"builtin:{agent}:{name}"
        else:
            desc, preview, key = description(path), path, os.path.realpath(path)
        if len(desc) > 90:
            desc = desc[:89] + "…"
        # The resolved path is the frecency key, so a skill shares one score across Claude and pi.
        print(f"{insert} \t{NAME}{insert}{RESET}  {TAG}{tag}{RESET}  {DIM}{desc}{RESET}\t{preview}\t{key}")


if __name__ == "__main__":
    main()
