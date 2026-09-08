from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urlparse

from kittens.tui.handler import result_handler


def _run(cmd, timeout=1):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
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


def converted_heic_path(text):
    if "\n" in text or "\r" in text:
        return None
    raw_path = text.strip().strip("'\"")
    if raw_path.startswith("file://"):
        raw_path = unquote(urlparse(raw_path).path)
    path = Path(raw_path)
    if path.suffix.lower() not in (".heic", ".heif") or not path.is_file():
        return None
    output_dir = Path(tempfile.mkdtemp(prefix="terminal-image-paste-"))
    output = output_dir / f"{path.stem}.png"
    if sys.platform == "darwin":
        command = ["sips", "-s", "format", "png", str(path), "--out", str(output)]
    elif shutil.which("magick"):
        command = ["magick", str(path), str(output)]
    elif shutil.which("heif-convert"):
        command = ["heif-convert", str(path), str(output)]
    else:
        output_dir.rmdir()
        return None
    result = _run(command, timeout=10)
    if result is not None and result.returncode == 0 and output.is_file():
        return str(output)
    shutil.rmtree(output_dir, ignore_errors=True)
    return None


def main(args):
    return None


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return
    # Read text FIRST (one fast pbpaste); the slow osascript image-check ran before this, letting a dictation tool restore the clipboard right after Cmd+V and paste the OLD content (OpenSuperWhisper #153).
    text = clipboard_text()
    converted_path = converted_heic_path(text)
    if converted_path:
        w.paste(converted_path)
    elif text:
        w.paste(text)
    elif clipboard_has_image():
        w.write_to_child("\x16")
