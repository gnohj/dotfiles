#!/usr/bin/env python3
"""herdr popup (prefix+t): CPU and memory per workspace and pane, summed over each pane's process tree, with a memory trend."""
import curses
import json
import os
import platform
import socket
import subprocess
import sys
import time
import unicodedata

sys.dont_write_bytecode = True

HERDR = os.environ.get("HERDR_BIN_PATH", "herdr")
REFRESH = 1.0
TREE_REFRESH = 3.0
CPU_WINDOW = 3
SPARK = " ▁▂▃▄▅▆▇█"
STATUS_COLOR = {"working": 3, "idle": 2, "done": 2, "blocked": 5}


def herdr_json(*args):
    try:
        out = subprocess.run([HERDR, *args], capture_output=True, text=True, timeout=5).stdout
        return json.loads(out).get("result", {})
    except (OSError, ValueError, subprocess.SubprocessError):
        return {}


def socket_call(method, params):
    path = os.environ.get("HERDR_SOCKET_PATH")
    if not path:
        return
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.settimeout(2)
        s.connect(path)
        s.sendall((json.dumps({"id": "rm", "method": method, "params": params}) + "\n").encode())
        s.recv(4096)


def system_ram():
    if platform.system() == "Darwin":
        out = subprocess.run(["sysctl", "-n", "hw.memsize"], capture_output=True, text=True).stdout
        return int(out.strip() or 0)
    with open("/proc/meminfo") as f:
        for line in f:
            if line.startswith("MemTotal:"):
                return int(line.split()[1]) * 1024
    return 0


def cpu_seconds(field):
    # ps TIME is [[DD-]HH:]MM:SS[.ss] on both BSD and procps.
    days, _, clock = field.rpartition("-")
    total = 0.0
    for part in clock.split(":"):
        total = total * 60 + float(part)
    return total + (int(days) * 86400 if days else 0)


LINUX = sys.platform.startswith("linux")
CLK_TCK = os.sysconf("SC_CLK_TCK") if LINUX else 100


def proc_cpu_seconds(pid):
    # procps prints TIME in whole seconds, too coarse for 1s samples; /proc counts clock ticks, as btop reads it.
    with open(f"/proc/{pid}/stat") as f:
        fields = f.read().rsplit(")", 1)[1].split()
    return (int(fields[11]) + int(fields[12])) / CLK_TCK


class CpuMeter:
    # btop's method (CPU time delta over wall time): macOS ps pcpu is a ~1 minute decaying average that reports spikes late.
    def __init__(self):
        self.prev, self.prev_at = {}, None

    def sample(self):
        out = subprocess.run(["ps", "-A", "-o", "pid=,ppid=,time=,rss=,comm="], capture_output=True, text=True).stdout
        now = time.monotonic()
        elapsed = now - self.prev_at if self.prev_at else None
        procs, children, times = {}, {}, {}
        for line in out.splitlines():
            parts = line.split(None, 4)
            if len(parts) < 5:
                continue
            pid, ppid = int(parts[0]), int(parts[1])
            try:
                used = proc_cpu_seconds(pid) if LINUX else cpu_seconds(parts[2])
            except (OSError, ValueError, IndexError):
                continue
            times[pid] = used
            before = self.prev.get(pid, 0.0)
            # A pid missing from the last sample started since then; a smaller total means the pid was reused.
            delta = used - before if used >= before else used
            cpu = delta / elapsed * 100 if elapsed else 0.0
            procs[pid] = (cpu, int(parts[3]) * 1024, os.path.basename(parts[4]))
            children.setdefault(ppid, []).append(pid)
        self.prev, self.prev_at = times, now
        return procs, children


def tree_usage(root, procs, children):
    cpu = mem = 0
    stack, seen = [root], set()
    while stack:
        pid = stack.pop()
        if pid in seen or pid not in procs:
            continue
        seen.add(pid)
        c, m, _ = procs[pid]
        cpu, mem = cpu + c, mem + m
        stack.extend(children.get(pid, []))
    return cpu, mem


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit in ("B", "KB") else f"{n:.1f} {unit}"
        n /= 1024


def sparkline(values, width):
    values = values[-width:]
    if not values:
        return ""
    lo, hi = min(values), max(values)
    # Scaled between the window's low and high, so a steady workspace draws a flat baseline rather than a solid block.
    if hi - lo < max(hi * 0.01, 1 << 20):
        return (SPARK[1] * len(values)).rjust(width)
    return "".join(SPARK[1 + int((v - lo) / (hi - lo) * (len(SPARK) - 2) + 0.5)] for v in values).rjust(width)


def fit(text, width):
    # Pads by display width. VS16 is dropped: curses counts 🖊️ as one cell while the terminal draws two, which shifts the row.
    out, used = "", 0
    for ch in text.replace("\ufe0f", ""):
        cw = 0 if unicodedata.combining(ch) or ord(ch) == 0x200D else 2 if unicodedata.east_asian_width(ch) in "WF" else 1
        if used + cw > width:
            break
        out, used = out + ch, used + cw
    return out + " " * (width - used)


class Model:
    def __init__(self):
        self.shell_pids = {}
        self.snapshot = {}
        self.snapshot_at = 0
        self.history = {}
        self.cpu_history = {}
        self.sort = "mem"
        self.folded = set()
        self.ram = system_ram()
        self.meter = CpuMeter()

    def refresh_tree(self):
        self.snapshot = herdr_json("api", "snapshot").get("snapshot", {})
        self.snapshot_at = time.time()
        live = {p["pane_id"] for p in self.snapshot.get("panes", [])}
        for pane_id in live - self.shell_pids.keys():
            info = herdr_json("pane", "process-info", "--pane", pane_id).get("process_info", {})
            if info.get("shell_pid"):
                self.shell_pids[pane_id] = info["shell_pid"]
        for gone in self.shell_pids.keys() - live:
            del self.shell_pids[gone]

    def rows(self):
        if time.time() - self.snapshot_at > TREE_REFRESH:
            self.refresh_tree()
        procs, children = self.meter.sample()
        agents = {a["pane_id"]: a for a in self.snapshot.get("agents", [])}
        panes_by_ws = {}
        for p in self.snapshot.get("panes", []):
            panes_by_ws.setdefault(p["workspace_id"], []).append(p)
        rows, groups, total_cpu, total_mem = [], [], 0.0, 0
        for ws in self.snapshot.get("workspaces", []):
            wid, members = ws["workspace_id"], []
            for p in panes_by_ws.get(wid, []):
                pid = self.shell_pids.get(p["pane_id"])
                cpu, mem = tree_usage(pid, procs, children) if pid else (0.0, 0)
                samples = self.cpu_history.setdefault(p["pane_id"], [])
                samples.append(cpu)
                del samples[:-CPU_WINDOW]
                cpu = sum(samples) / len(samples)
                agent = agents.get(p["pane_id"])
                if agent:
                    name, detail = agent.get("agent", "agent"), agent.get("title") or ""
                else:
                    kids = children.get(pid, []) if pid else []
                    name = procs[kids[0]][2] if kids and kids[0] in procs else "shell"
                    detail = procs[pid][2].lstrip("-") if pid in procs else ""
                members.append({"kind": "pane", "id": p["pane_id"], "name": name, "detail": detail,
                                "status": p.get("agent_status") or "", "cpu": cpu, "mem": mem})
            cpu, mem = sum(m["cpu"] for m in members), sum(m["mem"] for m in members)
            self.history.setdefault(wid, []).append(mem)
            self.history[wid] = self.history[wid][-200:]
            total_cpu, total_mem = total_cpu + cpu, total_mem + mem
            groups.append(({"kind": "ws", "id": wid, "name": ws.get("label") or wid, "cpu": cpu, "mem": mem}, members))
        for stale in self.cpu_history.keys() - {p["pane_id"] for p in self.snapshot.get("panes", [])}:
            del self.cpu_history[stale]
        order = (lambda r: (r["cpu"], r["mem"])) if self.sort == "cpu" else (lambda r: (r["mem"], r["cpu"]))
        for ws_row, members in sorted(groups, key=lambda g: order(g[0]), reverse=True):
            rows.append(ws_row)
            if ws_row["id"] not in self.folded:
                rows.extend(sorted(members, key=order, reverse=True))
        return rows, total_cpu, total_mem


def draw(scr, model, rows, total_cpu, total_mem, cursor, message):
    scr.erase()
    h, w = scr.getmaxyx()
    name_w = max(20, min(56, w - 60))
    trend_w = max(8, min(40, w - name_w - 26))

    def put(y, x, text, attr=0):
        if 0 <= y < h and x < w:
            try:
                scr.addnstr(y, x, text, max(0, w - x - 1), attr)
            except curses.error:
                pass

    cpu_h, mem_h = ("CPU ▼", "Memory") if model.sort == "cpu" else ("CPU", "Memory ▼")
    header = f"{'Name':<{name_w}}{cpu_h:>8}{mem_h:>12}  {'Memory trend':<{trend_w}}"
    put(0, 1, header, curses.A_DIM)
    put(1, 1, "─" * (w - 3), curses.A_DIM)
    body_h = h - 5
    top = max(0, cursor - body_h + 1)
    for i, row in enumerate(rows[top:top + body_h]):
        y, selected = 2 + i, top + i == cursor
        base = curses.A_REVERSE if selected else 0
        if selected:
            put(y, 1, " " * (w - 3), base)
        cpu_attr = curses.color_pair(3) if row["cpu"] >= 50 else 0
        if row["kind"] == "ws":
            arrow = "▸" if row["id"] in model.folded else "▾"
            put(y, 1, fit(f"{arrow} {row['name']}", name_w), base | curses.A_BOLD | curses.color_pair(4))
            spark = sparkline(model.history.get(row["id"], []), trend_w)
            put(y, 1 + name_w + 22, spark, base | curses.color_pair(6))
        else:
            dot = curses.color_pair(STATUS_COLOR.get(row["status"], 8))
            put(y, 1, "  ", base)
            put(y, 3, "●", dot | base)
            label = f" {row['name']}  "
            put(y, 4, label, base)
            put(y, 4 + len(label), row["detail"][:max(0, name_w - 4 - len(label))], base | curses.A_DIM)
        put(y, 1 + name_w, f"{row['cpu']:>7.1f}%", base | cpu_attr)
        put(y, 1 + name_w + 8, f"{human(row['mem']):>12}", base)
    put(h - 3, 1, "─" * (w - 3), curses.A_DIM)
    share = f"{total_mem / model.ram * 100:.0f}% of system RAM" if model.ram else ""
    put(h - 2, 1, f"{'Total':<{name_w}}{total_cpu:>7.1f}%{human(total_mem):>12}  {share}", curses.A_BOLD)
    put(h - 1, 1, message or "j/k move · space fold · s sort cpu/mem · enter focus · x close pane · q quit", curses.A_DIM)
    scr.refresh()


def main(scr):
    curses.curs_set(0)
    curses.use_default_colors()
    for n in range(1, 9):
        curses.init_pair(n, n, -1)
    curses.init_pair(8, 8 if curses.COLORS > 8 else 7, -1)
    scr.timeout(int(REFRESH * 1000))
    model, cursor, message, confirm = Model(), 0, "", None
    rows, total_cpu, total_mem = model.rows()

    def reload():
        # Re-sorting moves rows every refresh, so the cursor follows the selected id rather than its index.
        nonlocal rows, total_cpu, total_mem, cursor
        selected = rows[cursor]["id"] if 0 <= cursor < len(rows) else None
        rows, total_cpu, total_mem = model.rows()
        cursor = next((i for i, r in enumerate(rows) if r["id"] == selected), cursor)

    while True:
        cursor = max(0, min(cursor, len(rows) - 1))
        draw(scr, model, rows, total_cpu, total_mem, cursor, message)
        key = scr.getch()
        if key == -1:
            reload()
            continue
        message = ""
        row = rows[cursor] if rows else None
        if confirm:
            if key in (ord("y"), ord("Y")):
                subprocess.run([HERDR, "pane", "close", confirm], capture_output=True)
                model.snapshot_at = 0
                reload()
            confirm = None
            continue
        if key in (ord("q"), 27):
            return
        if key in (ord("j"), curses.KEY_DOWN):
            cursor += 1
        elif key in (ord("k"), curses.KEY_UP):
            cursor -= 1
        elif key == ord("g"):
            cursor = 0
        elif key == ord("G"):
            cursor = len(rows) - 1
        elif key == ord(" ") and row and row["kind"] == "ws":
            model.folded ^= {row["id"]}
            reload()
        elif key == ord("s"):
            model.sort = "mem" if model.sort == "cpu" else "cpu"
            reload()
        elif key in (10, 13, curses.KEY_ENTER) and row:
            if row["kind"] == "pane":
                socket_call("pane.focus", {"pane_id": row["id"]})
            else:
                socket_call("workspace.focus", {"workspace_id": row["id"]})
            return
        elif key == ord("x") and row and row["kind"] == "pane":
            confirm = row["id"]
            message = f"close pane {row['name']} ({row['id']})? y to confirm, any other key cancels"


if __name__ == "__main__":
    curses.wrapper(main)
