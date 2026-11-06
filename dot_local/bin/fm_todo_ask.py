#!/usr/bin/env python3
"""Todo pane calls: firstmate's "> Your call:" lines as a question, lettered options and a recommendation, and the captain's answer."""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import textwrap
import time

STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "rexpad")
RAW_FILE = os.path.join(STATE, "firstmate.status")
ANSWERS_FILE = os.path.join(STATE, "firstmate.answers.json")
FM_TODO = os.path.expanduser("~/.local/bin/fm-todo")
LEVEL = r"🔴|🟡|♻️|♻|🟢|✅"
LINE = re.compile(rf"^\s*({LEVEL})\s*([0-9]+)\.\s*(.*)$")
TICKET = re.compile(r"\b[A-Z][A-Z]+-[0-9]+\b")
PR = re.compile(r"\bPR #?([0-9]+)\b")
QUESTION = re.compile(r"^Your call:\s*(.+)$", re.I)
OPTION = re.compile(r"^\(([a-z])\)\s*(.+?)(?:\s+-\s+(.+))?$")
RECOMMEND = re.compile(r"^Recommend(?:ed|s)?\s*\(([a-z])\)\s*[:.-]?\s*(.*)$", re.I)
KEY = re.compile(r"\s*\[key=([A-Za-z0-9._-]+)\]")


def plain(text):
    text = re.sub(r"\*\*|`", "", text)
    return re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text).strip()


def parse(raw):
    items, cur = {}, None
    for line in raw.split("\n"):
        m = LINE.match(line)
        if m:
            cur = {"level": m[1], "number": int(m[2]), "head": plain(m[3]), "details": [], "question": "",
                   "options": [], "recommend": "", "why": "", "key": ""}
            items[cur["number"]] = cur
            continue
        if cur is None or not line.lstrip().startswith(">"):
            continue
        text = line.lstrip()[1:].strip()
        cur["details"].append(text)
        if q := QUESTION.match(text):
            question = q[1]
            if k := KEY.search(question):
                cur["key"], question = k[1], KEY.sub("", question)
            cur["question"] = question.strip()
        elif o := OPTION.match(text):
            cur["options"].append({"letter": o[1], "label": o[2].strip(), "why": (o[3] or "").strip()})
        elif r := RECOMMEND.match(text):
            cur["recommend"], cur["why"] = r[1], r[2].strip()
    for item in items.values():
        letters = {o["letter"] for o in item["options"]}
        if item["recommend"] not in letters:
            item["recommend"] = ""
        item["ref"], item["qid"] = ref_of(item), qid_of(item)
        item["fp"] = hashlib.sha1(json.dumps([item["question"], item["options"]]).encode()).hexdigest()[:10]
    counts = {}
    for item in items.values():
        counts[item["qid"]] = counts.get(item["qid"], 0) + 1
    for item in items.values():
        if counts[item["qid"]] > 1:
            item["qid"] += ":" + hashlib.sha1(item["head"].encode()).hexdigest()[:6]
    return items


def ref_of(item):
    head = item["head"]
    parts = TICKET.findall(head)[:1] + [f"PR #{n}" for n in PR.findall(head)[:1]]
    return " · ".join(parts) or re.sub(r"^\S+\s+-\s+", "", head)


def qid_of(item):
    project = item["head"].split(" ", 1)[0]
    ticket, pr = TICKET.search(item["head"]), PR.search(item["head"])
    anchor = "/".join(x for x in (ticket[0] if ticket else "", f"PR{pr[1]}" if pr else "") if x) or item["key"]
    return f"{project}:{anchor or hashlib.sha1(item['head'].encode()).hexdigest()[:8]}"


def current():
    try:
        with open(RAW_FILE) as f:
            return parse(f.read())
    except OSError:
        return {}


def find(qid):
    return next((i for i in current().values() if i["qid"] == qid), None)


def answers():
    try:
        with open(ANSWERS_FILE) as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def record(item, letter, note):
    data = answers()
    data[item["qid"]] = {"fp": item["fp"], "letter": letter, "note": note, "at": int(time.time())}
    cutoff = time.time() - 7 * 86400
    data = {k: v for k, v in data.items() if isinstance(v, dict) and v.get("at", 0) > cutoff}
    tmp = ANSWERS_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, ANSWERS_FILE)


def send(text):
    text = re.sub(r"[\x00-\x1f\x7f]+", " ", text).strip()
    result = subprocess.run([FM_TODO, "send", text], capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(result.stderr.strip() or "could not reach the firstmate pane")
    subprocess.Popen([FM_TODO, "refresh"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def live(qid, fp):
    item = find(qid)
    if item is None or not item["question"]:
        raise SystemExit("That call is no longer on the board.")
    if item["fp"] != fp:
        raise SystemExit("firstmate changed that call since the board drew it. Open it again.")
    return item


def answer(qid, fp, letter, note=""):
    item = live(qid, fp)
    note = " ".join(note.split())
    key = f" [key={item['key']}]" if item["key"] else ""
    if letter:
        option = next((o for o in item["options"] if o["letter"] == letter), None)
        if option is None:
            raise SystemExit(f"That call has no option ({letter}).")
        send(f"Captain, answer on {item['ref']}: ({letter}) {option['label']}" + (f" - {note}" if note else "") + key)
    elif note:
        send(f"Captain, answer on {item['ref']}: {note}{key}")
    else:
        return
    record(item, letter, note)


def menu_rows(qid, fp, chat_url):
    from fm_todo_action import act
    item = live(qid, fp)
    sent = answers().get(qid) or {}
    sent = sent.get("letter") if sent.get("fp") == fp else ""
    rows = []
    for o in item["options"]:
        tag = "sent" if o["letter"] == sent else "recommended" if o["letter"] == item["recommend"] else ""
        star = "*" if o["letter"] == (item["recommend"] or sent) else ""
        rows.append((f"({o['letter']}) {o['label']}", act("answer", qid=qid, fp=fp, letter=o["letter"]), star, tag))
    rows.append(("Something else…", chat_url, "" if item["recommend"] or sent else "*", ""))
    return rows


def wrap(text, width, indent="  "):
    return textwrap.wrap(text, width, initial_indent=indent, subsequent_indent=indent) or [indent]


def card(title, ref, qid):
    item = find(qid) if qid else None
    width = max(40, shutil.get_terminal_size((80, 24)).columns - 4)
    dim, bold, yellow, off = "\033[2m", "\033[1m", "\033[33m", "\033[0m"
    header = [f"{bold}  {title}{off}"] + ([f"{dim}  {ref}{off}"] if ref and ref not in title else []) + [""]
    details = item["details"] if item else context_lines(title)
    for d in details:
        if QUESTION.match(d) or OPTION.match(d) or RECOMMEND.match(d):
            continue
        header += [f"{dim}{ln}{off}" for ln in wrap(d, width)]
    if item and item["question"]:
        header += [""] + [f"{yellow}{bold}{ln}{off}" for ln in wrap("Your call: " + item["question"], width)]
        if item["recommend"]:
            label = next(o["label"] for o in item["options"] if o["letter"] == item["recommend"])
            header += [f"{yellow}{ln}{off}" for ln in wrap(f"Recommends ({item['recommend']}) {label}" + (f": {item['why']}" if item["why"] else ""), width)]
    options = item["options"] if item and item["question"] else []
    hint = "↑↓ pick a choice · type to add your words · Enter sends · Esc cancels" if options else "Enter sends to firstmate · Esc cancels"
    header += ["", f"{dim}  {hint}{off}"]
    rows = ["-\t✎  send only what I type"] if options else []
    for o in options:
        star = "  ★ recommended" if o["letter"] == item["recommend"] else ""
        rows.append(f"{o['letter']}\t({o['letter']}) {o['label']}" + (f" - {o['why']}" if o["why"] else "") + star)
    result = subprocess.run(
        ["fzf", "--disabled", "--print-query", "--layout=reverse", "--no-sort", "--ansi", "--wrap", "--header-first",
         "--header", "\n".join(header), "--delimiter", "\t", "--with-nth", "2..", "--prompt", "  › ",
         "--pointer", "▶", "--info", "hidden", "--no-scrollbar", "--border", "none", "--color", "header:-1",
         *([] if options else ["--no-separator"])],
        input="\n".join(rows), stdout=subprocess.PIPE, text=True)
    if result.returncode not in (0, 1):
        return
    out = result.stdout.split("\n")
    words = out[0].strip() if out else ""
    pick = out[1].split("\t", 1)[0] if len(out) > 1 and out[1] else "-"
    try:
        if item and item["question"]:
            if pick == "-" and not words:
                return
            answer(qid, item["fp"], "" if pick == "-" else pick, words)
        elif words:
            about = f"{title} ({ref})" if ref else title
            send(f"Captain, about {about}: {words}")
        else:
            return
        print(f"\n  \033[32mSent to firstmate.\033[0m")
        time.sleep(0.7)
    except SystemExit as error:
        print(f"\n  \033[31m{error}\033[0m\n  {dim}Press any key.{off}")
        subprocess.run(["bash", "-c", "read -r -n1 -s"])


def context_lines(title):
    want = re.sub(r"\s+", " ", title).strip()
    for name in ("firstmate", "firstmate.prs", "firstmate.tickets", "firstmate.reviews", "firstmate.outputs"):
        got = subprocess.run(["rexpad", "--list", name, "get"], capture_output=True, text=True)
        lines = got.stdout.split("\n")
        for i, line in enumerate(lines):
            m = re.match(r"^\s*(\* |- \[.\] )(.*)$", line)
            if not m or want not in board_plain(m[2]):
                continue
            out = []
            for sub in lines[i + 1:]:
                t = sub.strip()
                if not sub.startswith("  ") or t.startswith(("* ", "- [")):
                    break
                out.append(board_plain(t[2:] if t[:2] in (": ", "| ", "> ") else t))
            return out
    return []


def board_plain(s):
    s = re.sub(r" \{#\d+\}$", "", s)
    s = re.sub(r"\t.*$", "", s)
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)
    s = re.sub(r"\{\{([^{}]*?)(:[a-z]*[!.]?)?\}\}", r"\1", s)
    return s.replace("`", "").replace("**", "").strip()


def main(argv):
    cmd, args = (argv[0], argv[1:]) if argv else ("", [])
    if cmd == "card":
        return card(*(args + ["", "", ""])[:3])
    if cmd == "show":
        print(json.dumps(find(args[0]) or {}, indent=2))
        return
    if cmd == "parse":
        with open(args[0]) if args else sys.stdin as f:
            print(json.dumps(list(parse(f.read()).values()), indent=2, ensure_ascii=False))
        return
    raise SystemExit("usage: fm_todo_ask.py card TITLE [REF] [QID] | show QID | parse [FILE]")


if __name__ == "__main__":
    main(sys.argv[1:])
