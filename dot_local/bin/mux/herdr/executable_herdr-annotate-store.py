#!/usr/bin/env python3
"""herdr-annotate store access for the prefix+m picker, using the plugin's own lock and file formats."""
import json
import os
import re
import shutil
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

STATE = Path(os.environ.get("HERDR_ANNOTATE_STATE_DIR") or Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "herdr/plugins/annotate")
VIEW_FILE = os.environ.get("HERDR_ANNOTATE_VIEW_FILE")
STALE_LOCK_SECONDS = 30
BOLD, DIM, RESET = "\x1b[1m", "\x1b[2m", "\x1b[0m"


class Lock:
    def __init__(self, name):
        self.path = STATE / f".{name}.lock"
        self.owner = f"{os.getpid()}:{uuid.uuid4()}"

    def __enter__(self):
        STATE.mkdir(parents=True, exist_ok=True)
        for _ in range(2):
            try:
                self.path.mkdir(mode=0o700)
            except FileExistsError:
                if time.time() - self.path.stat().st_mtime < STALE_LOCK_SECONDS:
                    raise SystemExit("annotations are busy; try again")
                shutil.rmtree(self.path, ignore_errors=True)
                continue
            fd = os.open(self.path / "owner", os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            os.write(fd, f"{self.owner}\n".encode())
            os.close(fd)
            return self
        raise SystemExit("annotations are busy; try again")

    def __exit__(self, *_):
        try:
            if (self.path / "owner").read_text().strip() == self.owner:
                shutil.rmtree(self.path, ignore_errors=True)
        except OSError:
            pass


def load(name):
    path = STATE / f"{name}.jsonl"
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def save(name, records):
    temporary = STATE / f".{name}-{os.getpid()}-{int(time.time() * 1000)}.tmp"
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as stream:
        for record in records:
            stream.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")
    os.replace(temporary, STATE / f"{name}.jsonl")


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.") + f"{datetime.now(timezone.utc).microsecond // 1000:03d}Z"


def local_time(stamp):
    try:
        return datetime.fromisoformat(stamp.replace("Z", "+00:00")).astimezone().strftime("%Y-%m-%d %H:%M")
    except (ValueError, AttributeError):
        return ""


def by_created(annotations):
    return sorted(annotations, key=lambda item: item.get("createdAt") or "")


def view():
    try:
        return Path(VIEW_FILE).read_text().strip() or "active"
    except (TypeError, OSError):
        return "active"


def one_line(text):
    return re.sub(r"\s+", " ", text or "").strip() or "(blank selection)"


def source(annotation):
    context = annotation.get("context") or {}
    return " / ".join(value for value in (context.get("workspace_label"), context.get("tab_label")) if value)


def fence(text):
    longest = max((len(run) for run in re.findall(r"`+", text)), default=0)
    return "`" * max(longest + 1, 3)


def markdown(annotations):
    sections = []
    for index, annotation in enumerate(annotations, 1):
        where = source(annotation)
        location = f" ({where})" if where else ""
        selection = annotation.get("selectedText", "").strip("\r\n")
        if "\n" in selection:
            mark = fence(selection)
            quoted = f"Comment on:\n{mark}\n{selection}\n{mark}"
        else:
            quoted = f'Comment on: "{selection.strip()}"'
        comment = annotation.get("comment", "").strip().replace("\r\n", "\n").replace("\n", "\n> ")
        sections.append(f"## Annotation {index}{location}\n{quoted}\n> {comment}")
    return "# Annotations on terminal selections\n\n" + "\n\n".join(sections) + "\n"


def selected(keys):
    wanted = set(keys)
    if view() == "archives":
        sets = [item for item in load("archives") if item.get("id") in wanted]
        return by_created([annotation for item in sets for annotation in item.get("annotations", [])])
    return by_created([item for item in load("annotations") if item.get("id") in wanted])


def cmd_list(_):
    if view() == "archives":
        for item in sorted(load("archives"), key=lambda entry: entry.get("archivedAt") or "", reverse=True):
            annotations = item.get("annotations", [])
            first = one_line(annotations[0].get("selectedText")) if annotations else ""
            count = f"{len(annotations)} annotation{'' if len(annotations) == 1 else 's'}"
            print(f"{item['id']}\t{count} · {local_time(item.get('archivedAt'))} · {first}")
    else:
        for item in by_created(load("annotations")):
            print(f"{item['id']}\t{one_line(item.get('selectedText'))}")


def color(name, fallback):
    value = os.environ.get(name, "").lstrip("#") or fallback
    return "\x1b[38;2;{};{};{}m".format(*(int(value[i:i + 2], 16) for i in (0, 2, 4)))


def keys_line(*pairs):
    key, text = color("HERDR_ANNOTATE_KEY_COLOR", "b7ce97"), color("HERDR_ANNOTATE_TEXT_COLOR", "a3b8c6")
    return f"{text} · ".join(f"{key}{shortcut} {text}{label}" for shortcut, label in pairs) + RESET


def cmd_header(_):
    text = color("HERDR_ANNOTATE_TEXT_COLOR", "a3b8c6")
    if view() == "archives":
        title, toggle, act = f"Archives ({len(load('archives'))}) newest first", ("v", "active"), ("r", "restore")
    else:
        title, toggle, act = f"Annotations ({len(load('annotations'))}) oldest first", ("v", "archives"), ("a", "archive")
    print(f"{text}{title}{RESET}")
    print(keys_line(("enter", "paste"), act))
    print(keys_line(("x", "delete"), toggle, ("tab/space", "mark")))


def cmd_toggle(_):
    Path(VIEW_FILE).write_text("active" if view() == "archives" else "archives")


def cmd_preview(keys):
    blocks = []
    for annotation in selected(keys[:1]):
        meta = "  ·  ".join(value for value in (source(annotation), local_time(annotation.get("createdAt"))) if value)
        text = (annotation.get("selectedText") or "").rstrip("\r\n")
        comment = (annotation.get("comment") or "").replace("\r", "").strip()
        blocks.append(f"{BOLD}Selected text{RESET}\n{DIM}{text}{RESET}\n\n{BOLD}Comment{RESET}\n{comment}\n\n{DIM}{meta}{RESET}")
    print("\n\n────────\n\n".join(blocks))


def cmd_markdown(keys):
    annotations = selected(keys)
    if annotations:
        sys.stdout.write(markdown(annotations))


def cmd_delete(keys):
    wanted = set(keys)
    name = "archives" if view() == "archives" else "annotations"
    with Lock(name):
        save(name, [item for item in load(name) if item.get("id") not in wanted])


def cmd_archive(keys):
    if view() == "archives":
        return
    wanted = set(keys)
    with Lock("annotations"):
        active = load("annotations")
        moving = by_created([item for item in active if item.get("id") in wanted])
        if not moving:
            return
        with Lock("archives"):
            save("archives", load("archives") + [{"version": 1, "id": str(uuid.uuid4()), "archivedAt": now_iso(), "annotations": moving}])
        save("annotations", [item for item in active if item.get("id") not in wanted])


def cmd_restore(keys):
    if view() != "archives":
        return
    wanted = set(keys)
    with Lock("annotations"), Lock("archives"):
        archives = load("archives")
        active = load("annotations")
        existing = {item.get("id") for item in active}
        for item in archives:
            if item.get("id") in wanted:
                active += [annotation for annotation in item.get("annotations", []) if annotation.get("id") not in existing]
        save("annotations", active)
        save("archives", [item for item in archives if item.get("id") not in wanted])


COMMANDS = {
    "list": cmd_list, "header": cmd_header, "toggle-view": cmd_toggle, "preview": cmd_preview,
    "markdown": cmd_markdown, "delete": cmd_delete, "archive": cmd_archive, "restore": cmd_restore,
}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        raise SystemExit(f"usage: {Path(sys.argv[0]).name} {'|'.join(COMMANDS)} [ids...]")
    COMMANDS[sys.argv[1]]([key for key in sys.argv[2:] if key])
