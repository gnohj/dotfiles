#!/usr/bin/env python3
import copy
import json
import os
from pathlib import Path
import socket
import socketserver
import subprocess
import sys
import tempfile
import threading

PLUGIN_ID = "rmarganti.herdr-pluck"
SUPPORTED_PLUCK_VERSION = "0.3.1"
MAX_MESSAGE_BYTES = 4 * 1024 * 1024
LAUNCH_METHODS = {"pane.layout", "pane.read", "layout.apply", "pane.focus", "tab.focus", "tab.close"}


def read_message(stream):
    raw = stream.readline(MAX_MESSAGE_BYTES + 1)
    if len(raw) > MAX_MESSAGE_BYTES or not raw.endswith(b"\n"):
        raise ValueError("incomplete or oversized Herdr message")
    message = json.loads(raw)
    if not isinstance(message, dict):
        raise ValueError("Herdr message must be an object")
    return message


def exchange(socket_path, message):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(10)
        connection.connect(socket_path)
        connection.sendall((json.dumps(message) + "\n").encode())
        with connection.makefile("rb") as stream:
            response = read_message(stream)
    if response.get("id") != message["id"]:
        raise ValueError("Herdr response id mismatch")
    return response


def result(socket_path, method, params):
    response = exchange(socket_path, {"id": "pluck-viewport", "method": method, "params": params})
    if "error" in response:
        raise RuntimeError(response["error"]["message"])
    return response["result"]


def content_layout(layout, viewport_rows):
    if len(layout["panes"]) != 1:
        return layout
    outer = layout["area"] if layout.get("zoomed") else layout["panes"][0]["rect"]
    missing_rows = outer["height"] - viewport_rows
    if missing_rows == 0:
        return layout
    if missing_rows != 2 or viewport_rows < 1 or outer["width"] < 4:
        raise ValueError("source pane geometry changed; refusing an inaccurate Pluck viewport")
    adjusted = copy.deepcopy(layout)
    rect = {
        "x": outer["x"] + 1,
        "y": outer["y"] + 1,
        "width": outer["width"] - 2,
        "height": viewport_rows,
    }
    adjusted["area"] = rect.copy()
    adjusted["panes"][0]["rect"] = rect.copy()
    return adjusted


class PluckRequestHandler(socketserver.StreamRequestHandler):
    def handle(self):
        message = {}
        self.connection.settimeout(10)
        try:
            message = read_message(self.rfile)
            response = self.server.relay(message)
        except (OSError, ValueError, KeyError, TypeError, RuntimeError) as error:
            response = {
                "id": message.get("id"),
                "error": {"code": "pluck_viewport_error", "message": str(error)},
            }
        self.wfile.write((json.dumps(response) + "\n").encode())


class PluckServer(socketserver.UnixStreamServer):
    def __init__(self, path, upstream):
        self.upstream = upstream
        super().__init__(path, PluckRequestHandler)
        os.chmod(path, 0o600)

    def relay(self, message):
        if message["method"] not in LAUNCH_METHODS:
            raise ValueError("unsupported Pluck launch method")
        response = exchange(self.upstream, message)
        if message["method"] == "pane.layout" and "result" in response:
            layout = response["result"]["layout"]
            if len(layout["panes"]) == 1:
                pane = result(self.upstream, "pane.get", {"pane_id": layout["panes"][0]["pane_id"]})["pane"]
                response["result"]["layout"] = content_layout(layout, pane["scroll"]["viewport_rows"])
        return response


def open_picker(socket_path, binary, environment, action="open"):
    with tempfile.TemporaryDirectory(prefix="pluck-viewport-", dir="/tmp") as directory:
        path = str(Path(directory) / "api.sock")
        with PluckServer(path, socket_path) as server:
            thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.05})
            thread.start()
            try:
                return subprocess.run(
                    [str(binary), action],
                    env={**environment, "HERDR_SOCKET_PATH": path},
                    cwd=binary.parent.parent,
                    timeout=60,
                    check=False,
                ).returncode
            finally:
                server.shutdown()
                thread.join()


def main():
    action = sys.argv[1] if len(sys.argv) == 2 else "open"
    if action not in {"open", "open-url"} or len(sys.argv) > 2:
        raise ValueError("usage: herdr-pluck.py [open|open-url]")
    socket_path = os.environ["HERDR_SOCKET_PATH"]
    plugins = result(socket_path, "plugin.list", {})["plugins"]
    plugin = next((plugin for plugin in plugins if plugin["plugin_id"] == PLUGIN_ID), None)
    if not plugin or not plugin["enabled"]:
        raise RuntimeError("install and enable rmarganti/herdr-pluck first")
    if plugin["version"] != SUPPORTED_PLUCK_VERSION:
        raise RuntimeError("Pluck version changed; re-check this viewport adapter before using it")
    binary = Path(plugin["plugin_root"]) / "bin" / "herdr-pluck"
    herdr = os.environ.get("HERDR_BIN_PATH", "herdr")
    config_dir = subprocess.check_output([herdr, "plugin", "config-dir", PLUGIN_ID], text=True, timeout=10).strip()
    environment = {
        **os.environ,
        "HERDR_PLUGIN_ID": PLUGIN_ID,
        "HERDR_PLUGIN_ROOT": plugin["plugin_root"],
        "HERDR_PLUGIN_CONFIG_DIR": config_dir,
    }
    return open_picker(socket_path, binary, environment, action)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"herdr-pluck: {error}", file=sys.stderr)
        sys.exit(1)
