import os
from pathlib import Path
import stat
import subprocess
import sys
import time


def recent_files(directory, seconds, now=None):
    cutoff = (time.time() if now is None else now) - seconds
    result = subprocess.run(
        ["git", "-C", str(directory), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        capture_output=True, check=True,
    )
    recent = []
    for name in dict.fromkeys(result.stdout.split(b"\0")):
        if not name:
            continue
        path = Path(directory) / os.fsdecode(name)
        try:
            info = path.lstat()
        except FileNotFoundError:
            continue
        if (stat.S_ISREG(info.st_mode) or stat.S_ISLNK(info.st_mode)) and info.st_mtime > cutoff:
            recent.append(os.fsdecode(name))
    return recent


if __name__ == "__main__":
    for name in recent_files(Path.cwd(), float(sys.argv[1])):
        print(name)
