#!/usr/bin/env python3
"""herdr-sysinfo - feed a live system-info line to the herdr sidebar's $sys token.

herdr has no status bar and the maintainer ruled one out for the main client UI
(ogulcancelik/herdr#341: "not something i am planning to add"; the tmux-status-bar PRs
#342/#1742 were closed, and the plugin persistent-chrome proposal #1608 was closed
not_planned). A custom sidebar metadata token is the only always-visible surface herdr
exposes, so that is what this feeds.

The line renders on ONE pinned space, so it appears exactly once and always in the same
spot rather than repeating down every sidebar row or chasing focus. That space is labelled
with the username, held at sidebar index 0 via workspace.move (socket API only - the
`herdr workspace` CLI has no move), and recreated if it is ever closed. herdr has no
pinned-space concept; this is just "first in the list, kept that way".

The trade-off is real and deliberate: the pinned space is a genuine workspace with a live
shell pane, so it joins the prefix+w / prefix+W cycle like any other. That is the cost of
a fixed position, since a metadata token can only hang off a space.

The daemon re-samples on a timer and also rides the socket's event stream
(events.subscribe - the same stream herdr-focus-tracker.py uses, not exposed by
`herdr api`) so a closed pinned space comes back immediately rather than on the next tick.

`{hostcity}` is the herdr twin of the tmux host cell: host_short@city, with the city
coming from the SAME ~/.local/bin/mux/shared/host-city geoip helper (public-IP derived, cached ~5min,
re-resolves on its own when a box relocates). It reads that helper's cache file directly
and only forks the helper when the cache is stale, so the poll stays cheap. herdr needs
no #{@ssh_host} equivalent: this daemon runs on whichever host runs the herdr SERVER, so
over `herdr --remote` the line already reports the remote box rather than the Mac.

Lifecycle follows the herdr socket's existence, and exits once it has been gone for a
grace window (long enough to ride out a server restart) rather than polling a dead socket:
  Linux  systemd .path unit (PathExists) -> runs the daemon directly
  macOS  launchd agent org.nixos.herdr-sysinfo (KeepAlive PathState on the socket), same
         as every other herdr daemon; the flock-guarded --kick from herdr-sesh-layout.sh
         is now just a belt-and-braces no-op when launchd already owns the daemon

Stdlib only for the herdr side - no herdr binary, no PATH - so systemd's minimal env is
enough; the only fork is the absolute-path host-city helper on a cache miss.

  herdr-sysinfo.py           run the daemon (event stream + timed re-sample)
  herdr-sysinfo.py --kick    ensure exactly one daemon is running, then return
  herdr-sysinfo.py --once    one refresh pass, then exit
  herdr-sysinfo.py --print   print the rendered line, without touching herdr

Env: HERDR_SYSINFO_INTERVAL  seconds, default 5
     HERDR_SYSINFO_SCOPE     pin | focused | all, default pin
     HERDR_SYSINFO_PIN       label of the pinned space, default "🖥️ $USER"
     HERDR_SYSINFO_FORMAT    fields below; default is host@city alone off Linux, and
                             host@city + cpu/mem/load on Linux
Fields: host city hostcity cpu mem memp memtot load disk up time
"""
import fcntl
import json
import os
import select
import socket
import subprocess
import sys
import time

SOCK = os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser("~/.config/herdr/herdr.sock")
SOURCE = "sysinfo"
TOKEN = "sys"
LINUX = sys.platform.startswith("linux")
INTERVAL = float(os.environ.get("HERDR_SYSINFO_INTERVAL", "5"))
SCOPE = os.environ.get("HERDR_SYSINFO_SCOPE", "pin")
# Home basename, not $USER: it is herdr's own label for the home space, and systemd's minimal env has no $USER.
USER = os.path.basename(os.path.expanduser("~")) or os.environ.get("USER") or "host"
# "Pinned" is just index 0, recreated if closed - herdr has no such concept, and the line must not chase focus.
PIN = os.environ.get("HERDR_SYSINFO_PIN") or f"🖥️ {USER}"
# Off Linux there is no /proc, so cpu/mem would render "-": ship host@city alone there.
FORMAT = os.environ.get("HERDR_SYSINFO_FORMAT") or (
    "{hostcity}  {cpu}  {mem}  {load}" if LINUX else "{hostcity}"
)
TTL_MS = int(INTERVAL * 3000 + 5000)
GRACE = 60.0

CITY_HELPER = os.path.expanduser("~/.local/bin/mux/shared/host-city")
CITY_CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "host-city")
CITY_TTL = 300
STATE_DIR = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
LOCK = os.path.join(STATE_DIR, "herdr", "sysinfo.lock")

SUBSCRIPTIONS = ["workspace.focused", "tab.focused", "pane.focused", "workspace.closed"]


def request(method, params):
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.settimeout(4)
    try:
        conn.connect(SOCK)
        conn.sendall((json.dumps({"id": SOURCE, "method": method, "params": params}) + "\n").encode())
        with conn.makefile("rb") as stream:
            line = stream.readline()
    finally:
        conn.close()
    return json.loads(line) if line else {}


def city():
    try:
        fresh = time.time() - os.path.getmtime(CITY_CACHE) < CITY_TTL
    except OSError:
        fresh = False
    if not fresh:
        # host-city writes the cache itself, so a timeout here is survivable - the stale read below still works.
        try:
            subprocess.run([CITY_HELPER], capture_output=True, timeout=6)
        except (OSError, subprocess.SubprocessError):
            pass
    try:
        with open(CITY_CACHE) as f:
            return f.read().strip()
    except OSError:
        return ""


def human(kb):
    if kb >= 1024 * 1024:
        return f"{kb / 1048576:.1f}G"
    return f"{kb / 1024:.0f}M"


def cpu_times():
    with open("/proc/stat") as f:
        vals = [int(x) for x in f.readline().split()[1:]]
    return sum(vals), vals[3] + (vals[4] if len(vals) > 4 else 0)


def meminfo():
    info = {}
    with open("/proc/meminfo") as f:
        for line in f:
            key, _, val = line.partition(":")
            info[key] = int(val.split()[0])
    total = info["MemTotal"]
    return total - info.get("MemAvailable", info["MemFree"]), total


def uptime():
    with open("/proc/uptime") as f:
        secs = int(float(f.readline().split()[0]))
    days, rem = divmod(secs, 86400)
    hours = rem // 3600
    return f"{days}d{hours}h" if days else f"{hours}h{(rem % 3600) // 60}m"


class Sampler:
    def __init__(self):
        self.prev = None
        self.city = ""
        self.city_at = 0.0

    def cpu(self):
        total, idle = cpu_times()
        prev, self.prev = self.prev, (total, idle)
        if prev is None or total <= prev[0]:
            return "--%"
        busy = 1.0 - (idle - prev[1]) / (total - prev[0])
        return f"{max(0.0, busy) * 100:.0f}%"

    def cached_city(self):
        # Tied to CITY_TTL: a longer hold pins a city the disk cache already re-resolved.
        if time.monotonic() - self.city_at > CITY_TTL or not self.city:
            self.city, self.city_at = city(), time.monotonic()
        return self.city

    def render(self):
        keys = ("host", "city", "hostcity", "cpu", "mem", "memp", "memtot", "load", "disk", "up", "time")
        fields = {k: "-" for k in keys}
        host = os.uname().nodename.split(".")[0]
        town = self.cached_city()
        fields["host"] = host
        fields["city"] = town or "-"
        fields["hostcity"] = f"{host}@{town}" if town else host
        fields["time"] = time.strftime("%H:%M")
        try:
            fields["load"] = f"{os.getloadavg()[0]:.2f}"
        except OSError:
            pass
        try:
            st = os.statvfs("/")
            fields["disk"] = f"{(1 - st.f_bavail / st.f_blocks) * 100:.0f}%"
        except (OSError, ZeroDivisionError):
            pass
        try:
            fields["cpu"] = self.cpu()
        except (OSError, IndexError, ValueError):
            pass
        try:
            used, total = meminfo()
            fields["mem"], fields["memtot"] = human(used), human(total)
            fields["memp"] = f"{used / total * 100:.0f}%"
        except (OSError, KeyError, ZeroDivisionError):
            pass
        try:
            fields["up"] = uptime()
        except (OSError, IndexError, ValueError):
            pass
        try:
            return FORMAT.format(**fields)
        except (KeyError, IndexError):
            return fields["hostcity"]


def ensure_pin(entries):
    """Resolve the pinned space by label, creating it at the top of the sidebar if gone."""
    for entry in entries:
        if entry.get("label") == PIN:
            return entry["workspace_id"], entries
    # Adopt+relabel any existing home space: matching the exact label alone spawned a twin on every rename.
    for entry in entries:
        if (entry.get("label") or "").split()[-1:] == [USER]:
            wid = entry["workspace_id"]
            request("workspace.rename", {"workspace_id": wid, "label": PIN})
            return wid, entries
    created = (request("workspace.create", {"label": PIN, "cwd": os.path.expanduser("~"),
                                            "focus": False}).get("result") or {})
    wid = ((created.get("workspace") or {}).get("workspace_id"))
    if not wid:
        return None, entries
    request("workspace.move", {"workspace_id": wid, "insert_index": 0})
    refreshed = (request("workspace.list", {}).get("result") or {}).get("workspaces") or entries
    return wid, refreshed


def publish(line, focused_hint=None):
    result = request("workspace.list", {}).get("result") or {}
    entries = result.get("workspaces") or []
    if not entries:
        return
    if SCOPE == "all":
        targets = {w["workspace_id"] for w in entries}
    elif SCOPE == "focused":
        focused = focused_hint or next((w["workspace_id"] for w in entries if w.get("focused")), None)
        targets = {focused} if focused else set()
    else:
        pinned, entries = ensure_pin(entries)
        targets = {pinned} if pinned else set()
    seq = time.time_ns()
    for entry in entries:
        wid = entry["workspace_id"]
        wanted = line if wid in targets else None
        # Only redundant CLEARS are skippable: the write is what refreshes ttl_ms, so an unchanged line still needs it.
        if wanted is None and (entry.get("tokens") or {}).get(TOKEN) is None:
            continue
        request("workspace.report_metadata", {
            "workspace_id": wid,
            "source": SOURCE,
            "tokens": {TOKEN: wanted},
            "seq": seq,
            **({"ttl_ms": TTL_MS} if wanted else {}),
        })


def stream(sampler):
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.connect(SOCK)
    req = {"id": SOURCE, "method": "events.subscribe",
           "params": {"subscriptions": [{"type": t} for t in SUBSCRIPTIONS]}}
    conn.sendall((json.dumps(req) + "\n").encode())
    line = sampler.render()
    publish(line)
    deadline = time.monotonic() + INTERVAL
    with conn.makefile("rb") as events:
        while True:
            ready, _, _ = select.select([conn], [], [], max(0.0, deadline - time.monotonic()))
            if ready:
                raw = events.readline()
                if not raw:
                    return
                try:
                    msg = json.loads(raw)
                except ValueError:
                    continue
                if not str(msg.get("event", "")).endswith(("_focused", "_closed")):
                    continue
                # Focus moved: retarget the existing line now, no re-sample needed.
                publish(line, (msg.get("data") or {}).get("workspace_id"))
                continue
            line = sampler.render()
            publish(line)
            deadline = time.monotonic() + INTERVAL


def daemon():
    os.makedirs(os.path.dirname(LOCK), exist_ok=True)
    handle = open(LOCK, "w")
    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return  # another daemon owns the lock
    sampler = Sampler()
    gone_since = None
    while True:
        try:
            stream(sampler)
        except (OSError, ConnectionError):
            pass
        # A restart kills the stream exactly when the socket is gone, so ride out GRACE before quitting.
        if os.path.exists(SOCK):
            gone_since = None
        elif gone_since is None:
            gone_since = time.monotonic()
        elif time.monotonic() - gone_since > GRACE:
            return
        time.sleep(1)


def kick():
    if not os.path.exists(SOCK):
        return
    os.makedirs(os.path.dirname(LOCK), exist_ok=True)
    with open(LOCK, "w") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            fcntl.flock(handle, fcntl.LOCK_UN)
        except OSError:
            return  # a daemon already holds it
    subprocess.Popen([sys.executable, os.path.abspath(__file__)],
                     start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else ""
    if arg == "--kick":
        kick()
        return
    sampler = Sampler()
    if arg in ("--print", "--once"):
        sampler.render()          # prime the cpu delta
        time.sleep(0.2)
        line = sampler.render()
        print(line) if arg == "--print" else publish(line)
        return
    daemon()


if __name__ == "__main__":
    main()
