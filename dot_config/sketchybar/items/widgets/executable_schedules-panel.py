#!/usr/bin/python3

import datetime as dt
import json
import os
import plistlib
import re
import subprocess
import tempfile
from pathlib import Path

UID = os.getuid()
HOME = Path.home()
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "sketchybar" / "schedules.json"
PLIST_LOCATIONS = (
    (HOME / "Library/LaunchAgents", f"gui/{UID}"),
    (Path("/Library/LaunchAgents"), f"gui/{UID}"),
    (Path("/Library/LaunchDaemons"), "system"),
)
SECTION_ORDER = {
    "NIX · LAUNCHD": 0,
    "USER · LAUNCHD": 1,
    "APP · LAUNCHD": 2,
    "CLAUDE · COWORK": 3,
    "MACOS · CRON": 4,
}
KNOWN_NAMES = {
    "org.nixos.claude-cost-refresh": "Claude cost refresh",
    "org.nixos.github-auto-push": "GitHub auto push",
    "org.nixos.log-cleanup": "Log cleanup",
    "org.nixos.sb-audit-reminder": "Vault audit reminder",
    "org.nixos.sketchybar-watchdog": "SketchyBar watchdog",
    "org.nixos.usage-sampler": "Usage sampler",
    "org.nixos.nix-gc": "Nix garbage collection",
    "org.nixos.nix-optimise": "Nix store optimise",
    "org.git-scm.git.daily": "Git maintenance daily",
    "org.git-scm.git.hourly": "Git maintenance hourly",
    "org.git-scm.git.weekly": "Git maintenance weekly",
    "com.google.GoogleUpdater.wake": "Google updater",
    "com.microsoft.update.agent": "Microsoft updater",
    "com.microsoft.EdgeUpdater.wake.system": "Edge updater",
    "us.zoom.updater": "Zoom updater",
}


def run(command):
    return subprocess.run(command, text=True, capture_output=True, check=False)


def clean(value):
    return str(value).replace("\t", " ").replace("\n", " ").strip()


def emit(*fields):
    print("\t".join(clean(field) for field in fields))


def human_duration(seconds):
    seconds = max(0, int(seconds))
    if seconds < 60:
        return f"{seconds}s"
    minutes, seconds = divmod(seconds, 60)
    if minutes < 60:
        return f"{minutes}m {seconds:02d}s"
    hours, minutes = divmod(minutes, 60)
    if hours < 24:
        return f"{hours}h {minutes:02d}m"
    days, hours = divmod(hours, 24)
    return f"{days}d {hours:02d}h"


def friendly_name(label):
    if label in KNOWN_NAMES:
        return KNOWN_NAMES[label]
    name = re.sub(r"^(org\.nixos\.|com\.[^.]+\.|org\.[^.]+\.)", "", label)
    return name.replace("-", " ").replace("_", " ").strip().title()


def section_for(label, path):
    if label.startswith("org.nixos."):
        return "NIX · LAUNCHD"
    if path.parent == HOME / "Library/LaunchAgents" and label.startswith("com.gnohj."):
        return "USER · LAUNCHD"
    return "APP · LAUNCHD"


def disabled_labels(domain):
    result = run(["/bin/launchctl", "print-disabled", domain])
    return set(re.findall(r'"([^"]+)"\s*=>\s*disabled', result.stdout))


def launch_state(label, domain, plist_disabled, disabled):
    if plist_disabled or label in disabled:
        return {"status": "disabled", "runs": None, "active": False, "problem": True}
    result = run(["/bin/launchctl", "print", f"{domain}/{label}"])
    if result.returncode != 0:
        return {"status": "unloaded", "runs": None, "active": False, "problem": True}
    state_match = re.search(r"^\s*state = (.+)$", result.stdout, re.MULTILINE)
    runs_match = re.search(r"^\s*runs = (\d+)$", result.stdout, re.MULTILINE)
    exit_match = re.search(r"^\s*last exit code = (-?\d+)$", result.stdout, re.MULTILINE)
    state = state_match.group(1) if state_match else ""
    runs = int(runs_match.group(1)) if runs_match else None
    if state == "running":
        return {"status": "running", "runs": runs, "active": True, "problem": False}
    if exit_match and int(exit_match.group(1)) != 0:
        return {"status": "failed", "runs": runs, "active": True, "problem": True}
    return {"status": "scheduled", "runs": runs, "active": True, "problem": False}


def calendar_entries(value):
    if isinstance(value, dict):
        return [value]
    if isinstance(value, list):
        return [entry for entry in value if isinstance(entry, dict)]
    return []


def matches_calendar_day(day, entry):
    if "Month" in entry and day.month != int(entry["Month"]):
        return False
    if "Day" in entry and day.day != int(entry["Day"]):
        return False
    if "Weekday" in entry:
        expected = int(entry["Weekday"])
        expected = 0 if expected == 7 else expected
        actual = (day.weekday() + 1) % 7
        if actual != expected:
            return False
    return True


def next_calendar(value, now):
    start = now.replace(second=0, microsecond=0) + dt.timedelta(minutes=1)
    best = None
    for entry in calendar_entries(value):
        for offset in range(366 * 8):
            day = (start + dt.timedelta(days=offset)).date()
            if not matches_calendar_day(day, entry):
                continue
            hours = [int(entry["Hour"])] if "Hour" in entry else range(24)
            minutes = [int(entry["Minute"])] if "Minute" in entry else range(60)
            for hour in hours:
                for minute in minutes:
                    try:
                        candidate = dt.datetime.combine(day, dt.time(hour, minute)).astimezone()
                    except ValueError:
                        continue
                    if candidate >= start and (best is None or candidate < best):
                        best = candidate
            if best is not None and best.date() == day:
                break
    return best


def load_cache():
    try:
        return json.loads(CACHE.read_text())
    except (OSError, json.JSONDecodeError):
        return {"jobs": {}}


def save_cache(cache):
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=CACHE.parent, delete=False) as handle:
        json.dump(cache, handle)
        temporary = handle.name
    os.replace(temporary, CACHE)


def interval_remaining(label, interval, runs, now, cache):
    jobs = cache.setdefault("jobs", {})
    previous = jobs.get(label, {})
    last_seen = previous.get("last_seen")
    if previous and runs is not None and previous.get("runs") != runs:
        last_seen = now.timestamp()
    jobs[label] = {"runs": runs, "last_seen": last_seen}
    if last_seen is None:
        return f"every {human_duration(interval)}"
    elapsed = max(0, now.timestamp() - last_seen)
    remaining = interval - (elapsed % interval)
    return human_duration(remaining)


def plist_jobs(now, cache):
    jobs = []
    disabled_by_domain = {}
    for directory, domain in PLIST_LOCATIONS:
        if not directory.is_dir():
            continue
        if domain not in disabled_by_domain:
            disabled_by_domain[domain] = disabled_labels(domain)
        for path in sorted(directory.glob("*.plist")):
            try:
                with path.open("rb") as handle:
                    plist = plistlib.load(handle)
            except (OSError, plistlib.InvalidFileException):
                continue
            interval = plist.get("StartInterval")
            calendar = plist.get("StartCalendarInterval")
            if not interval and not calendar:
                continue
            label = str(plist.get("Label") or path.stem)
            state = launch_state(label, domain, bool(plist.get("Disabled")), disabled_by_domain[domain])
            if state["status"] in {"disabled", "unloaded", "failed", "running"}:
                remaining = state["status"]
            elif interval:
                remaining = interval_remaining(label, int(interval), state["runs"], now, cache)
            else:
                next_run = next_calendar(calendar, now)
                remaining = human_duration((next_run - now).total_seconds()) if next_run else "unknown"
            jobs.append(
                {
                    "name": friendly_name(label),
                    "section": section_for(label, path),
                    "status": state["status"],
                    "remaining": remaining,
                    "active": state["active"],
                    "problem": state["problem"],
                }
            )
    return jobs


def parse_cron_field(field, minimum, maximum, names=None):
    names = names or {}
    values = set()
    for part in field.lower().split(","):
        base, _, step_text = part.partition("/")
        step = int(step_text) if step_text else 1
        if base == "*":
            start, end = minimum, maximum
        elif "-" in base:
            left, right = base.split("-", 1)
            start = names.get(left, int(left) if left.isdigit() else -1)
            end = names.get(right, int(right) if right.isdigit() else -1)
        else:
            value = names.get(base, int(base) if base.isdigit() else -1)
            start = end = value
        if start < minimum or end > maximum or start > end or step < 1:
            raise ValueError(field)
        values.update(range(start, end + 1, step))
    return values


def next_cron(expression, now):
    fields = expression.split()
    if len(fields) != 5:
        return None
    month_names = {
        name: index
        for index, name in enumerate("jan feb mar apr may jun jul aug sep oct nov dec".split(), 1)
    }
    day_names = {name: index for index, name in enumerate("sun mon tue wed thu fri sat".split())}
    try:
        minutes = parse_cron_field(fields[0], 0, 59)
        hours = parse_cron_field(fields[1], 0, 23)
        month_days = parse_cron_field(fields[2], 1, 31)
        months = parse_cron_field(fields[3], 1, 12, month_names)
        week_days = {0 if value == 7 else value for value in parse_cron_field(fields[4], 0, 7, day_names)}
    except ValueError:
        return None
    month_day_wild = fields[2] == "*"
    week_day_wild = fields[4] == "*"
    candidate = now.replace(second=0, microsecond=0) + dt.timedelta(minutes=1)
    limit = candidate + dt.timedelta(days=366 * 8)
    while candidate < limit:
        month_day_match = candidate.day in month_days
        week_day_match = ((candidate.weekday() + 1) % 7) in week_days
        day_match = (
            month_day_match and week_day_match
            if month_day_wild or week_day_wild
            else month_day_match or week_day_match
        )
        if candidate.month in months and day_match and candidate.hour in hours and candidate.minute in minutes:
            return candidate
        candidate += dt.timedelta(minutes=1)
    return None


def cron_jobs(now):
    result = run(["/usr/bin/crontab", "-l"])
    if result.returncode != 0:
        return []
    aliases = {
        "@yearly": "0 0 1 1 *",
        "@annually": "0 0 1 1 *",
        "@monthly": "0 0 1 * *",
        "@weekly": "0 0 * * 0",
        "@daily": "0 0 * * *",
        "@midnight": "0 0 * * *",
        "@hourly": "0 * * * *",
    }
    jobs = []
    index = 0
    for raw_line in result.stdout.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", line):
            continue
        index += 1
        if line.startswith("@reboot"):
            expression = None
            command = line[len("@reboot") :].strip()
            remaining = "at login"
        elif line.startswith("@"):
            alias, _, command = line.partition(" ")
            expression = aliases.get(alias)
            next_run = next_cron(expression, now) if expression else None
            remaining = human_duration((next_run - now).total_seconds()) if next_run else "unknown"
        else:
            parts = line.split(None, 5)
            if len(parts) < 6:
                continue
            expression = " ".join(parts[:5])
            command = parts[5]
            next_run = next_cron(expression, now)
            remaining = human_duration((next_run - now).total_seconds()) if next_run else "unknown"
        executable = Path(command.split()[0]).name if command else f"Job {index}"
        jobs.append(
            {
                "name": f"{executable} #{index}",
                "section": "MACOS · CRON",
                "status": "scheduled",
                "remaining": remaining,
                "active": True,
                "problem": remaining == "unknown",
            }
        )
    return jobs


def claude_jobs(now):
    root = HOME / "Library/Application Support/Claude"
    paths = list(root.glob("claude-code-sessions/*/*/scheduled-tasks.json"))
    paths.extend(root.glob("local-agent-mode-sessions/*/*/scheduled-tasks.json"))
    tasks = {}
    for path in paths:
        try:
            payload = json.loads(path.read_text())
            modified_at = path.stat().st_mtime
        except (OSError, json.JSONDecodeError):
            continue
        for task in payload.get("scheduledTasks", []):
            task_id = str(task.get("id") or "scheduled-task")
            previous = tasks.get(task_id)
            if previous is None or modified_at > previous[0]:
                tasks[task_id] = (modified_at, task)
    jobs = []
    for task_id, (_, task) in tasks.items():
        enabled = bool(task.get("enabled", True))
        cron_expression = task.get("cronExpression")
        fire_at = task.get("fireAt")
        next_run = next_cron(cron_expression, now) if cron_expression else None
        if fire_at:
            try:
                next_run = dt.datetime.fromisoformat(str(fire_at).replace("Z", "+00:00")).astimezone()
            except ValueError:
                next_run = None
        if not enabled:
            status = remaining = "disabled"
        elif next_run and next_run >= now:
            status = "scheduled"
            remaining = human_duration((next_run - now).total_seconds())
        elif fire_at:
            status = remaining = "complete"
        else:
            status = "scheduled"
            remaining = "unknown"
        jobs.append(
            {
                "name": task_id.replace("-", " ").replace("_", " ").title(),
                "section": "CLAUDE · COWORK",
                "status": status,
                "remaining": remaining,
                "active": status == "scheduled",
                "problem": status == "scheduled" and remaining == "unknown",
            }
        )
    return jobs


def main():
    now = dt.datetime.now().astimezone()
    cache = load_cache()
    jobs = plist_jobs(now, cache) + claude_jobs(now) + cron_jobs(now)
    save_cache(cache)
    jobs.sort(key=lambda job: (SECTION_ORDER[job["section"]], job["name"].lower()))
    active = sum(job["active"] for job in jobs)
    problems = sum(job["problem"] for job in jobs)
    emit("summary", active, problems, len(jobs))
    current_section = None
    for job in jobs:
        if job["section"] != current_section:
            current_section = job["section"]
            count = sum(candidate["section"] == current_section for candidate in jobs)
            emit("section", current_section, count)
        emit("job", job["name"], job["remaining"], job["status"])


if __name__ == "__main__":
    main()
