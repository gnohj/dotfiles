#!/usr/bin/env python3
"""herdr-sysinfo - feed a live system-info line to the herdr sidebar's $sys token.

herdr has no status bar and the maintainer ruled one out for the main client UI
(herdrdev/herdr#341: "not something i am planning to add"; the tmux-status-bar PRs
#342/#1742 were closed, and the plugin persistent-chrome proposal #1608 was closed
not_planned). A custom sidebar metadata token is the only always-visible surface herdr
exposes, so that is what this feeds.

The line renders on the pinned space rather than repeating down every sidebar row or chasing
focus. That space is labelled with the username, held at sidebar index 0 via workspace.move
(socket API only - the `herdr workspace` CLI has no move), and recreated if it is ever closed.
herdr has no pinned-space concept; this is just "first in the list, kept that way". EVERY space
carrying that label is fed, not only the first: herdr-sesh-layout.sh labels a workspace rooted at
$HOME the same way, and its attach-if-exists probe can only match a pane's cwd (herdr exposes no
workspace root cwd), so the pin's own pane wandering off ~ is enough to spawn a twin. Feeding both
beats leaving whichever one you opened blank.

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

The same pass feeds four more tokens onto that pinned space: `$sysres` (cpu/mem/disk, split off
`$sys` because host@city plus resources is 34 columns against sidebar_width 32), `$systime`
(uptime and the wall-clock time in the box's geolocated zone, on its own row for the same width
reason), and the `$repos` / `$sync` pair - a fleet-wide git roll-up of dirty, unpushed and unpulled counts across EVERY path
the sesh picker knows, all of ~/Developer plus every ~/.treehouse slot. That is the half herdr
cannot show alone: its `$git` token only describes a workspace already open, and the pin is a bare
~ workspace with no repo. The pair is two tokens because a token takes ONE fg and both halves can
be lit at once - dirty red, arrows green - unlike $git/$git_on where only ever one is.

No scanner and no new dependency: counts are read from the sesh git cache (herdr_gitmux.CACHE)
that herdr-git-status.sh and the picker already keep warm. That is also the limitation - a path is
only as fresh as the last poll that visited it. They ride this daemon rather than a second one
because the pin lookup, event stream and flock already live here, and report_metadata takes a
token DICT, so each costs one extra key on a request already being sent.

Env: HERDR_SYSINFO_INTERVAL  seconds, default 5
     HERDR_SYSINFO_SCOPE     pin | focused | all, default pin
     HERDR_SYSINFO_PIN       label of the pinned space, default "🖥️ $USER"
     HERDR_SYSINFO_FORMAT    fields below; default host@city alone (resources live in $sysres)
     HERDR_SYSINFO_RES       $sysres layout; "" disables the token
     HERDR_SYSINFO_TIME      $systime layout; "" disables the token
     HERDR_REPOS_FORMAT      $repos layout, default "{dirty}"; "" disables the token
     HERDR_SYNC_FORMAT       $sync layout, default "{sync}"; "" disables the token
Fields: host city hostcity cpu mem memp memtot load disk up time tz
        dirty unpushed behind sync repos
"""
import fcntl
import json
import os
import re
import select
import socket
import subprocess
import sys
import time
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

SOCK = os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser("~/.config/herdr/herdr.sock")
SOURCE = "sysinfo"
TOKEN = "sys"
RES_TOKEN = "sysres"
TIME_TOKEN = "systime"
REPOS_TOKEN = "repos"
SYNC_TOKEN = "sync"
LINUX = sys.platform.startswith("linux")
INTERVAL = float(os.environ.get("HERDR_SYSINFO_INTERVAL", "5"))
SCOPE = os.environ.get("HERDR_SYSINFO_SCOPE", "pin")
# Home basename, not $USER: it is herdr's own label for the home space, and systemd's minimal env has no $USER.
USER = os.path.basename(os.path.expanduser("~")) or os.environ.get("USER") or "host"
# "Pinned" is just index 0, recreated if closed - herdr has no such concept, and the line must not chase focus.
PIN = os.environ.get("HERDR_SYSINFO_PIN") or f"🖥️ {USER}"
FORMAT = os.environ.get("HERDR_SYSINFO_FORMAT") or "{hostcity}"
# Empty off Linux (no /proc). Glyphs and percent-used both mirror the sketchybar cpu/memory widgets.
RES_FORMAT = os.environ.get("HERDR_SYSINFO_RES") or (
    " {cpu} ·  {memp} · 󰋊 {disk}" if LINUX else "")
# Uptime and disk swapped rows: disk took uptime's slot beside cpu/mem, uptime took disk's ahead of the clock.
TIME_FORMAT = os.environ.get("HERDR_SYSINFO_TIME") or ("󰁝 {up} · 󰥔 {time} {tz}" if LINUX else "")
TTL_MS = int(INTERVAL * 3000 + 5000)
GRACE = 60.0

CITY_HELPER = os.path.expanduser("~/.local/bin/mux/shared/host-city")
CITY_CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "host-city")
CITY_TTL = 300
# Written beside the city cache by the same host-city lookup, so the clock names the city the row names.
TZ_CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "host-tz")
STATE_DIR = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
LOCK = os.path.join(STATE_DIR, "herdr", "sysinfo.lock")

# Two tokens because a herdr token takes ONE fg and dirty (red) can be lit alongside ahead/behind (green).
REPOS_FORMAT = os.environ.get("HERDR_REPOS_FORMAT", "{dirty}")
SYNC_FORMAT = os.environ.get("HERDR_SYNC_FORMAT", "{sync}")
# Written by herdr_gitmux.update() from both the sidebar poller and the picker warm pass.
GIT_CACHE = os.path.join(STATE_DIR, "herdr", "sesh-git-cache.json")
# Codepoints, not literals, matching herdr_gitmux: these are gitmux.yml's ahead/behind symbols.
AHEAD, BEHIND = chr(0x1F446), chr(0x1F447)
_SGR = re.compile(r"\033\[[0-9;]*m")
_ARROWS = re.compile("[" + AHEAD + BEHIND + r"]\s*\d*")

# workspace.reordered arrived in 0.8.0 with group reordering, which can displace the pin.
SUBSCRIPTIONS = ["workspace.focused", "tab.focused", "pane.focused", "workspace.closed",
                 "workspace.reordered", "workspace.moved"]


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


def repo_counts():
    """(dirty, unpushed, behind) over every path in the sesh git cache, or None if unreadable."""
    try:
        with open(GIT_CACHE) as f:
            cache = json.load(f)
    except (OSError, ValueError):
        return None
    dirty = unpushed = behind = 0
    for entry in cache.values():
        # Entry is [ts, sgr_string, width, has_real_changes]; the glyphs live in the sgr string.
        if not isinstance(entry, list) or len(entry) < 2:
            continue
        flat = _SGR.sub("", entry[1] or "")
        if AHEAD in flat:
            unpushed += 1
        if BEHIND in flat:
            behind += 1
        # Whatever survives the arrows is working-tree state; stash was already dropped upstream.
        if _ARROWS.sub("", flat).strip():
            dirty += 1
    return dirty, unpushed, behind


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


# Rows 3-4 zero-pad every varying cell: herdr re-lays the row out on a length change, so 9% -> 10% reflowed it each tick.
def uptime():
    # Whole days only - hours churn every poll and the row is glanced at, not read.
    with open("/proc/uptime") as f:
        secs = int(float(f.readline().split()[0]))
    return f"{secs // 86400:02d}d"


def host_zone():
    """The IANA zone host-city resolved for this box, or None to mean system-local."""
    try:
        with open(TZ_CACHE) as f:
            return ZoneInfo(f.read().strip())
    except (OSError, ValueError, ZoneInfoNotFoundError):
        return None


def zone_abbrev(stamp):
    # CDT/CST both read CT: the row names a region, and which half of the year it is is already the clock's job.
    name = stamp.strftime("%Z")
    if len(name) == 3 and name[1] in "DS" and name[2] == "T":
        return name[0] + "T"
    return name


def clock():
    """(hh:mm, abbrev) in the box's geolocated zone, falling back to system-local."""
    zone = host_zone()
    # astimezone() on the fallback, not a bare now(): a naive datetime renders %Z as an empty string.
    stamp = datetime.now(zone) if zone else datetime.now().astimezone()
    return stamp.strftime("%H:%M"), zone_abbrev(stamp)


class Sampler:
    def __init__(self):
        self.prev = None
        self.city = ""
        self.city_at = 0.0
        self.repos = None
        self.repos_at = None

    def cpu(self):
        total, idle = cpu_times()
        prev, self.prev = self.prev, (total, idle)
        if prev is None or total <= prev[0]:
            return "--%"
        busy = 1.0 - (idle - prev[1]) / (total - prev[0])
        return f"{max(0.0, busy) * 100:02.0f}%"

    def cached_city(self):
        # Tied to CITY_TTL: a longer hold pins a city the disk cache already re-resolved.
        if time.monotonic() - self.city_at > CITY_TTL or not self.city:
            self.city, self.city_at = city(), time.monotonic()
        return self.city

    def cached_repos(self):
        # Keyed on the cache mtime, not a timer, so the roll-up never lags the $git token reading the same file.
        try:
            stamp = os.path.getmtime(GIT_CACHE)
        except OSError:
            return self.repos
        if stamp != self.repos_at:
            counts = repo_counts()
            if counts is not None:
                self.repos, self.repos_at = counts, stamp
        return self.repos

    def render_repos(self):
        """(repos_line, sync_line, parts) - fleet-wide and cwd-independent, split red/green."""
        counts = self.cached_repos()
        blank = {"dirty": "", "unpushed": "", "behind": "", "repos": "", "sync": ""}
        if counts is None:
            return "", "", blank
        dirty, unpushed, behind = counts
        parts = {
            "dirty": f"󰊢 {dirty}" if dirty else "",
            "unpushed": f"↑{unpushed}" if unpushed else "",
            "behind": f"↓{behind}" if behind else "",
        }
        # Empty halves collapse, so a clean fleet renders nothing and herdr drops the row entirely.
        parts["sync"] = " ".join(p for p in (parts["unpushed"], parts["behind"]) if p)
        parts["repos"] = " ".join(p for p in (parts["dirty"], parts["sync"]) if p)

        def fmt(spec, fallback):
            if not spec:
                return ""
            try:
                return spec.format(**parts)
            except (KeyError, IndexError):
                return fallback

        return fmt(REPOS_FORMAT, parts["dirty"]), fmt(SYNC_FORMAT, parts["sync"]), parts

    def render(self):
        keys = ("host", "city", "hostcity", "cpu", "mem", "memp", "memtot", "load", "disk", "up", "time", "tz")
        fields = {k: "-" for k in keys}
        fields.update(self.render_repos()[2])
        host = os.uname().nodename.split(".")[0]
        town = self.cached_city()
        fields["host"] = host
        fields["city"] = town or "-"
        fields["hostcity"] = f"{host}@{town}" if town else host
        fields["time"], fields["tz"] = clock()
        try:
            fields["load"] = f"{os.getloadavg()[0]:.2f}"
        except OSError:
            pass
        try:
            st = os.statvfs("/")
            fields["disk"] = f"{(1 - st.f_bavail / st.f_blocks) * 100:02.0f}%"
        except (OSError, ZeroDivisionError):
            pass
        try:
            fields["cpu"] = self.cpu()
        except (OSError, IndexError, ValueError):
            pass
        try:
            used, total = meminfo()
            fields["mem"], fields["memtot"] = human(used), human(total)
            fields["memp"] = f"{used / total * 100:02.0f}%"
        except (OSError, KeyError, ZeroDivisionError):
            pass
        try:
            fields["up"] = uptime()
        except (OSError, IndexError, ValueError):
            pass
        return fields

    def sample(self):
        """(sys_line, res_line, time_line) off ONE field build - cpu() is a delta and must be read once a tick."""
        fields = self.render()

        def fmt(spec):
            if not spec:
                return ""
            try:
                return spec.format(**fields)
            except (KeyError, IndexError):
                return fields["hostcity"]

        return fmt(FORMAT), fmt(RES_FORMAT), fmt(TIME_FORMAT)


def ensure_pin(entries):
    """Resolve every PIN-labelled space, creating one at the top of the sidebar if none is left."""
    matches = [entry["workspace_id"] for entry in entries if entry.get("label") == PIN]
    if matches:
        if entries[0].get("label") != PIN:
            # A reorder can displace it, so index 0 is re-asserted rather than only set on create.
            request("workspace.move", {"workspace_id": matches[0], "insert_index": 0})
            entries = (request("workspace.list", {}).get("result") or {}).get("workspaces") or entries
        return set(matches), entries
    # Adopt+relabel any existing home space: matching the exact label alone spawned a twin on every rename.
    for entry in entries:
        if (entry.get("label") or "").split()[-1:] == [USER]:
            wid = entry["workspace_id"]
            request("workspace.rename", {"workspace_id": wid, "label": PIN})
            return {wid}, entries
    created = (request("workspace.create", {"label": PIN, "cwd": os.path.expanduser("~"),
                                            "focus": False}).get("result") or {})
    wid = ((created.get("workspace") or {}).get("workspace_id"))
    if not wid:
        return set(), entries
    request("workspace.move", {"workspace_id": wid, "insert_index": 0})
    refreshed = (request("workspace.list", {}).get("result") or {}).get("workspaces") or entries
    return {wid}, refreshed


def publish(line, res_line="", repos_line="", sync_line="", time_line="", focused_hint=None):
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
        targets, entries = ensure_pin(entries)
    seq = time.time_ns()
    for entry in entries:
        wid = entry["workspace_id"]
        on_target = wid in targets
        wanted = line if on_target else None
        # Empty lines are sent as None so herdr drops the token and the row collapses on the pin.
        wanted_res = (res_line or None) if on_target else None
        wanted_repos = (repos_line or None) if on_target else None
        wanted_sync = (sync_line or None) if on_target else None
        wanted_time = (time_line or None) if on_target else None
        held = entry.get("tokens") or {}
        fresh = (wanted, wanted_res, wanted_repos, wanted_sync, wanted_time)
        names = (TOKEN, RES_TOKEN, REPOS_TOKEN, SYNC_TOKEN, TIME_TOKEN)
        # Only redundant CLEARS are skippable: the write is what refreshes ttl_ms, so an unchanged line still needs it.
        if not any(fresh) and not any(held.get(t) is not None for t in names):
            continue
        request("workspace.report_metadata", {
            "workspace_id": wid,
            "source": SOURCE,
            "tokens": dict(zip(names, fresh)),
            "seq": seq,
            **({"ttl_ms": TTL_MS} if any(fresh) else {}),
        })


def stream(sampler):
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.connect(SOCK)
    req = {"id": SOURCE, "method": "events.subscribe",
           "params": {"subscriptions": [{"type": t} for t in SUBSCRIPTIONS]}}
    conn.sendall((json.dumps(req) + "\n").encode())
    (line, res_line, time_line), (repos_line, sync_line, _) = sampler.sample(), sampler.render_repos()
    publish(line, res_line, repos_line, sync_line, time_line)
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
                publish(line, res_line, repos_line, sync_line, time_line,
                        (msg.get("data") or {}).get("workspace_id"))
                continue
            (line, res_line, time_line), (repos_line, sync_line, _) = sampler.sample(), sampler.render_repos()
            publish(line, res_line, repos_line, sync_line, time_line)
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
        sampler.sample()          # prime the cpu delta
        time.sleep(0.2)
        (line, res_line, time_line), (repos_line, sync_line, _) = sampler.sample(), sampler.render_repos()
        if arg == "--print":
            # repos + sync share a row; herdr puts its own separator between them.
            for out in (line, res_line, time_line, " · ".join(p for p in (repos_line, sync_line) if p)):
                print(out)
        else:
            publish(line, res_line, repos_line, sync_line, time_line)
        return
    daemon()


if __name__ == "__main__":
    main()
