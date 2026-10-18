import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def file_stamp(path, identity_only=False):
    try:
        info = path.stat()
        if identity_only:
            return [info.st_dev, info.st_ino]
        return [info.st_dev, info.st_ino, info.st_mtime_ns, info.st_ctime_ns, info.st_size]
    except OSError:
        return None


def git_directory(seed):
    marker = seed if seed.name == ".bare" else seed / ".git"
    if marker.is_dir():
        return marker
    try:
        text = marker.read_text().strip()
        if text.startswith("gitdir: "):
            return (marker.parent / text[8:]).resolve()
    except OSError:
        pass
    return None


def fingerprint(home):
    developer = home / "Developer"
    directories = sorted(path for path in developer.glob("*") if path.is_dir())
    seeds = [path / ".bare" if (path / ".bare").is_dir() else path for path in directories]
    treehouse = home / ".treehouse"
    if treehouse.is_dir() and shutil.which("fd"):
        found = subprocess.run(
            ["fd", "-H", "-a", "-0", "--max-depth", "5", "-E", "node_modules", r"^\.git$", str(treehouse)],
            capture_output=True, check=True,
        )
        seeds.extend(Path(os.fsdecode(path)).parent for path in found.stdout.split(b"\0") if path)
    stamps = {}
    for seed in sorted(set(seeds)):
        marker = seed if seed.name == ".bare" else seed / ".git"
        stamps[str(marker)] = file_stamp(marker, marker.is_dir())
        gitdir = git_directory(seed)
        if gitdir is None:
            continue
        common_file = gitdir / "commondir"
        stamps[str(common_file)] = file_stamp(common_file)
        try:
            common = (gitdir / common_file.read_text().strip()).resolve()
        except OSError:
            common = gitdir
        for path in (common / "config", common / "worktrees"):
            stamps[str(path)] = file_stamp(path)
        for entry in sorted((common / "worktrees").glob("*")):
            for path in (entry / "gitdir", entry / "locked", entry / "commondir"):
                stamps[str(path)] = file_stamp(path)
            try:
                marker = Path((entry / "gitdir").read_text().strip())
                stamps[str(marker)] = file_stamp(marker)
                stamps[str(marker.parent)] = file_stamp(marker.parent, True)
            except OSError:
                pass
    scanner = shutil.which("worktree-list")
    return {"version": 1, "directories": [str(path) for path in directories], "metadata": stamps,
            "scanner": [scanner, file_stamp(Path(scanner)) if scanner else None]}


def load_cache(path):
    try:
        result = json.loads(path.read_text())
        return result if isinstance(result, dict) else {}
    except (OSError, ValueError):
        return {}


def save_cache(path, value):
    with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as handle:
        temporary = Path(handle.name)
        try:
            json.dump(value, handle)
            handle.flush()
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


def sync(home, cache):
    current = fingerprint(home)
    previous = load_cache(cache)
    paths = previous.get("paths")
    if previous.get("fingerprint") != current or not isinstance(paths, list):
        result = subprocess.run(["worktree-list"], capture_output=True, text=True, check=True)
        paths = [row.split("\t", 1)[1] for row in result.stdout.splitlines() if "\t" in row]
        paths.extend(current["directories"])
        if (home / "Developer").is_dir():
            paths.append(str(home / "Developer"))
        paths = sorted(set(paths))
        if fingerprint(home) == current:
            save_cache(cache, {"fingerprint": current, "paths": paths})
    env = dict(os.environ, _ZO_DATA_DIR=os.environ.get("_ZO_DATA_DIR", str(home / ".config/zshrc")))
    existing = subprocess.run(["zoxide", "query", "-l"], capture_output=True, text=True, env=env, check=True)
    known = set(existing.stdout.splitlines())
    new = [path for path in paths if path not in known and Path(path).is_dir()]
    if new:
        subprocess.run(["zoxide", "add", "--", *new], check=True, env=env)


def main():
    home = Path.home()
    directory = Path(os.environ.get("XDG_CACHE_HOME", home / ".cache")) / "worktree-sync"
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / "refresh.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        sync(home, directory / "paths.json")


if __name__ == "__main__":
    main()
