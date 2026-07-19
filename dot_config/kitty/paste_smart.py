import subprocess
import sys

from kittens.tui.handler import result_handler


def _run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=1)
    except Exception:
        return None


def clipboard_has_image():
    if sys.platform == "darwin":
        r = _run(["osascript", "-e", "clipboard info"])
        info = r.stdout if r else ""
        return any(marker in info for marker in ("PNGf", "TIFF", "GIFf", "8BPS", "jp2"))
    r = _run(["wl-paste", "--list-types"])
    if r is not None and r.returncode == 0:
        return "image/" in r.stdout
    r = _run(["xclip", "-selection", "clipboard", "-t", "TARGETS", "-o"])
    return bool(r and "image/" in r.stdout)


def clipboard_text():
    if sys.platform == "darwin":
        r = _run(["pbpaste"])
    else:
        r = _run(["wl-paste", "-n"]) or _run(["xclip", "-selection", "clipboard", "-o"])
    return r.stdout if r else ""


def main(args):
    return None


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return
    if clipboard_has_image():
        w.write_to_child("\x16")
    else:
        text = clipboard_text()
        if text:
            w.paste(text)
