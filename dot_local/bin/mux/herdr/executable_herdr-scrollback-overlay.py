#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import sys
import tempfile
import time

MAX_MESSAGE_BYTES = 4 * 1024 * 1024
ESCAPE_SEQUENCE = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1b]*(?:\x07|\x1b\\)|[PX^_].*?\x1b\\|.)", re.DOTALL)
SGR_SEQUENCE = re.compile(r"\x1b\[[0-9;:]*m")


def request(method, params):
    message = {"id": "scrollback-overlay", "method": method, "params": params}
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(10)
        connection.connect(os.environ["HERDR_SOCKET_PATH"])
        connection.sendall((json.dumps(message) + "\n").encode())
        with connection.makefile("rb") as stream:
            raw = stream.readline(MAX_MESSAGE_BYTES + 1)
    if len(raw) > MAX_MESSAGE_BYTES or not raw.endswith(b"\n"):
        raise ValueError("incomplete or oversized Herdr response")
    response = json.loads(raw)
    if response.get("id") != message["id"]:
        raise ValueError("Herdr response id mismatch")
    if "error" in response:
        raise RuntimeError(response["error"]["message"])
    return response["result"]


def source_pane(environment):
    context = json.loads(environment.get("HERDR_PLUGIN_CONTEXT_JSON", "{}"))
    focused = context.get("focused_pane") or {}
    return context.get("focused_pane_id") or focused.get("id") or environment.get("HERDR_PANE_ID")


def companion(name):
    directory = Path(__file__).resolve().parent
    deployed = directory / name
    return deployed if deployed.is_file() else directory / f"executable_{name}"


def build_layout(node, target, panes, snapshot, mode):
    if node["type"] == "split":
        return {
            "type": "split", "direction": node["direction"], "ratio": node["ratio"],
            "first": build_layout(node["first"], target, panes, snapshot, mode),
            "second": build_layout(node["second"], target, panes, snapshot, mode),
        }
    pane_id = node["pane_id"]
    pane = panes[pane_id]
    command = [sys.executable, str(Path(__file__).resolve())]
    command += ["view", str(snapshot), mode] if pane_id == target else ["hold", str(snapshot), pane_id]
    result = {"type": "pane", "command": command, "cwd": pane.get("foreground_cwd") or pane["cwd"]}
    if pane.get("title"):
        result["label"] = pane["title"]
    return result


def viewer_pane(source, created, target):
    if source["type"] == "pane":
        return created["pane_id"] if source["pane_id"] == target else None
    return viewer_pane(source["first"], created["first"], target) or viewer_pane(source["second"], created["second"], target)


def pane_ids(node):
    if node["type"] == "pane":
        return [node["pane_id"]]
    return pane_ids(node["first"]) + pane_ids(node["second"])


def cleanup_files(snapshot):
    for path in (snapshot, snapshot.with_suffix(".ready"), snapshot.with_suffix(".ready.tmp"), snapshot.with_suffix(".ansi")):
        path.unlink(missing_ok=True)
    try:
        snapshot.parent.rmdir()
    except FileNotFoundError:
        pass


def wait_for_ready(snapshot):
    deadline = time.monotonic() + 15
    while not snapshot.with_suffix(".ready").exists():
        if time.monotonic() > deadline:
            raise TimeoutError("scrollback layout did not become ready")
        time.sleep(0.02)


def open_viewer(mode):
    target = source_pane(os.environ)
    if not target:
        raise ValueError("no source pane for scrollback")
    source = request("pane.get", {"pane_id": target})["pane"]
    layout = request("layout.export", {"tab_id": source["tab_id"]})["layout"]
    ids = pane_ids(layout["root"])
    if target not in ids:
        raise ValueError("source pane is missing from its tab layout")
    panes = {pane_id: request("pane.get", {"pane_id": pane_id})["pane"] for pane_id in ids}
    frozen = {}
    for pane_id in ids:
        frozen[pane_id] = request("pane.read", {
            "pane_id": pane_id, "source": "visible", "format": "ansi",
            "strip_ansi": False, "lines": panes[pane_id]["scroll"]["viewport_rows"],
        })["read"]["text"]
    height = panes[target]["scroll"]["viewport_rows"]
    rows = frozen.pop(target).split("\n")[:height]
    rows += [""] * (height - len(rows))
    viewport = "\n".join(safe_ansi(row) for row in rows) + "\n"
    payload = {
        "source_pane": target, "source_tab": source["tab_id"], "siblings": frozen,
        "viewport_rows": panes[target]["scroll"]["viewport_rows"],
        "viewer_script": str(companion("herdr-scrollback.sh")),
        "viewer_init": os.environ.get("HERDR_SCROLLBACK_INIT", str(Path.home() / ".config/herdr/lib/scrollback-nvim-init.lua")),
    }
    snapshot = Path(tempfile.mkdtemp(prefix="herdr-scrollview-", dir="/tmp")) / "view.json"
    created = None
    try:
        with snapshot.open("x") as stream:
            os.chmod(snapshot, 0o600)
            json.dump(payload, stream)
        snapshot.with_suffix(".ansi").write_text(viewport)
        created = request("layout.apply", {
            "workspace_id": source["workspace_id"], "tab_label": f"scrollback:{mode}",
            "focus": True, "root": build_layout(layout["root"], target, panes, snapshot, mode),
        })["layout"]
        viewer = viewer_pane(layout["root"], created["root"], target)
        if not viewer:
            raise ValueError("viewer pane is missing from the temporary layout")
        request("pane.focus", {"pane_id": viewer})
        if layout.get("zoomed"):
            request("pane.zoom", {"pane_id": viewer, "mode": "on"})
        marker = snapshot.with_suffix(".ready.tmp")
        marker.write_text("ready")
        marker.rename(snapshot.with_suffix(".ready"))
    except BaseException:
        cleanup_files(snapshot)
        if created:
            try:
                request("tab.focus", {"tab_id": source["tab_id"]})
            finally:
                request("tab.close", {"tab_id": created["tab_id"]})
        raise


def run_viewer(snapshot, mode):
    payload = json.loads(snapshot.read_text())
    tab_id = os.environ["HERDR_TAB_ID"]
    if tab_id == payload["source_tab"]:
        raise ValueError("refusing to replace the source tab with a scrollback viewer")
    try:
        wait_for_ready(snapshot)
        deadline = time.monotonic() + 3
        while os.get_terminal_size().lines != payload["viewport_rows"]:
            if time.monotonic() > deadline:
                raise TimeoutError("viewer did not reach the source pane height")
            time.sleep(0.02)
        command = ["/bin/bash", payload["viewer_script"]]
        if mode == "prompt":
            command.append("--jump")
        return subprocess.run(command, env={
            **os.environ, "HERDR_SCROLLBACK_SOURCE_PANE": payload["source_pane"],
            "HERDR_SCROLLBACK_VIEWPORT_FILE": str(snapshot.with_suffix(".ansi")),
            "HERDR_SCROLLBACK_VIEWPORT_ROWS": str(payload["viewport_rows"]),
            "HERDR_SCROLLBACK_INIT": payload.get("viewer_init", os.environ.get("HERDR_SCROLLBACK_INIT", str(Path.home() / ".config/herdr/lib/scrollback-nvim-init.lua"))),
        }, check=False).returncode
    finally:
        cleanup_files(snapshot)
        try:
            request("tab.focus", {"tab_id": payload["source_tab"]})
        finally:
            request("tab.close", {"tab_id": tab_id})


def safe_ansi(text):
    text = ESCAPE_SEQUENCE.sub(lambda match: match[0] if SGR_SEQUENCE.fullmatch(match[0]) else "", text)
    parts = re.split(r"(\x1b\[[0-9;:]*m)", text)
    return "".join(part if SGR_SEQUENCE.fullmatch(part) else re.sub(r"[\x00-\x1f\x7f]", "", part) for part in parts)


def hold_snapshot(snapshot, pane_id):
    payload = json.loads(snapshot.read_text())
    rows = [safe_ansi(row.rstrip("\r")) for row in payload["siblings"][pane_id].split("\n")]
    wait_for_ready(snapshot)

    def render(*_):
        height = os.get_terminal_size().lines
        screen = "\x1b[?25l\x1b[?7l\x1b[0m\x1b[2J"
        screen += "".join(f"\x1b[{index + 1};1H{row}\x1b[0m" for index, row in enumerate(rows[:height]))
        os.write(1, (screen + "\x1b[1;1H").encode())

    signal.signal(signal.SIGWINCH, render)
    render()
    while True:
        signal.pause()


def main():
    arguments = sys.argv[1:]
    if arguments in (["bottom"], ["prompt"]):
        open_viewer(arguments[0])
        return 0
    if len(arguments) == 3 and arguments[0] == "view" and arguments[2] in {"bottom", "prompt"}:
        return run_viewer(Path(arguments[1]), arguments[2])
    if len(arguments) == 3 and arguments[0] == "hold":
        hold_snapshot(Path(arguments[1]), arguments[2])
        return 0
    raise ValueError("usage: herdr-scrollback-overlay.py bottom|prompt")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"herdr-scrollback: {error}", file=sys.stderr)
        sys.exit(1)
