// S sends unsent notes on an agent PR review to firstmate (or FM_NOTES_TO=tab: the agent pane beside it); notes persist per PR and the status row tracks progress.
import { execFile } from "node:child_process";
import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { HunkExtensionAPI } from "hunkdiff/extension";

const PR = process.env.FM_HUNK_PR ?? "";
const TICKET = process.env.FM_HUNK_TICKET ?? "";
const TO = process.env.FM_NOTES_TO ?? "";
const FM_TODO =
  process.env.FM_NOTES_SEND ?? join(homedir(), ".local", "bin", "fm-todo");
const FM_TODO_BIN = join(homedir(), ".local", "bin", "fm-todo");
const NOTES_DIR = join(homedir(), ".local", "state", "rexpad", "hunk", "notes");
const NOTES_FILE = join(NOTES_DIR, `${PR.replace(/[/#]/g, "_")}.json`);

type Live = {
  noteId: string;
  parentId?: string;
  source: string;
  filePath: string;
  newRange?: [number, number];
  oldRange?: [number, number];
  body: string;
  author: string;
  createdAt: string;
};
type Saved = {
  key: string;
  parent?: string;
  filePath: string;
  side: "old" | "new";
  line: number;
  body: string;
  author: string;
  mine: boolean;
  sent: boolean;
  at: string;
};
type StatusCtx = {
  statusLine: {
    set(item: { id: string; spans: { text: string; tone?: string }[] }): void;
    clear(id: string): void;
  };
};

const keyOf = new Map<string, string>();
const sentKeys = new Set<string>();
const mineKeys = new Set<string>();
let session = "";
let restored = false;
let unmapped: Saved[] = [];
let lastSaved = "";
let statusCtx: StatusCtx | null = null;
let sentAt = 0;
let progress = { mate: "", stage: "", crew: "" };

function run(
  cmd: string,
  args: string[],
  input?: string,
  timeout = 8000,
): Promise<{ err: string; out: string }> {
  return new Promise((resolve) => {
    const child = execFile(cmd, args, { timeout }, (err, stdout) =>
      resolve({ err: err ? err.message : "", out: stdout ?? "" }),
    );
    if (input !== undefined) child.stdin?.end(input);
  });
}

async function hunkSessionId(): Promise<string> {
  const { out } = await run("hunk", ["session", "list", "--json"]);
  try {
    const sessions = JSON.parse(out || "{}").sessions ?? [];
    return (
      sessions.find((s: { pid?: number }) => s.pid === process.pid)
        ?.sessionId ?? ""
    );
  } catch {
    return "";
  }
}

async function liveNotes(): Promise<Live[] | null> {
  const { err, out } = await run("hunk", [
    "session",
    "comment",
    "list",
    session,
    "--type",
    "all",
    "--json",
  ]);
  if (err) return null;
  try {
    return (JSON.parse(out).comments ?? []) as Live[];
  } catch {
    return null;
  }
}

function readSaved(): Saved[] {
  try {
    return JSON.parse(readFileSync(NOTES_FILE, "utf8")) as Saved[];
  } catch {
    return [];
  }
}

function anchor(n: Live): { side: "old" | "new"; line: number } {
  return n.newRange
    ? { side: "new", line: n.newRange[0] }
    : { side: "old", line: n.oldRange?.[0] ?? 0 };
}

function keyFor(id: string): string {
  return keyOf.get(id) ?? id;
}

async function applyOne(item: Record<string, unknown>): Promise<string> {
  const { out } = await run(
    "hunk",
    ["session", "comment", "apply", session, "--stdin", "--json"],
    JSON.stringify({ comments: [item] }),
  );
  try {
    return JSON.parse(out).result?.applied?.[0]?.commentId ?? "";
  } catch {
    return "";
  }
}

// Hunk only lets the UI create user notes, so a restored note of yours comes back as an agent note authored "you".
async function restore(): Promise<number> {
  const saved = readSaved();
  let lost = 0;
  const liveOf = new Map<string, string>();
  for (const n of saved) {
    if (n.mine) mineKeys.add(n.key);
    if (n.sent) sentKeys.add(n.key);
    const author = n.mine ? "you" : n.author;
    const parent = n.parent ? liveOf.get(n.parent) : undefined;
    const target = parent
      ? { replyTo: parent }
      : {
          filePath: n.filePath,
          [n.side === "new" ? "newLine" : "oldLine"]: n.line,
        };
    const id = await applyOne({ ...target, summary: n.body, author });
    if (!id) {
      lost++;
      unmapped.push(n);
      continue;
    }
    liveOf.set(n.key, id);
    keyOf.set(id, n.key);
  }
  return lost;
}

function persist(notes: Live[]): void {
  const saved: Saved[] = notes
    .filter((n) => n.body?.trim())
    .map((n) => {
      const key = keyFor(n.noteId);
      if (n.source === "user") mineKeys.add(key);
      return {
        key,
        parent: n.parentId ? keyFor(n.parentId) : undefined,
        filePath: n.filePath,
        ...anchor(n),
        body: n.body,
        author: n.author,
        mine: mineKeys.has(key),
        sent: sentKeys.has(key),
        at: n.createdAt,
      };
    });
  const text = JSON.stringify([...saved, ...unmapped], null, 1);
  if (text === lastSaved) return;
  mkdirSync(NOTES_DIR, { recursive: true });
  writeFileSync(`${NOTES_FILE}.new`, text);
  renameSync(`${NOTES_FILE}.new`, NOTES_FILE);
  lastSaved = text;
}

function unsent(notes: Live[]): Live[] {
  return notes.filter((n) => {
    const key = keyFor(n.noteId);
    return mineKeys.has(key) || n.source === "user"
      ? !sentKeys.has(key) && n.body?.trim()
      : false;
  });
}

function answered(notes: Live[]): { total: number; done: number } {
  const replied = new Set(
    notes
      .filter(
        (n) =>
          n.parentId && !mineKeys.has(keyFor(n.noteId)) && n.source !== "user",
      )
      .map((n) => keyFor(n.parentId as string)),
  );
  const sent = notes.filter((n) => sentKeys.has(keyFor(n.noteId)));
  return {
    total: sent.length,
    done: sent.filter((n) => replied.has(keyFor(n.noteId))).length,
  };
}

function showStatus(notes: Live[]): void {
  if (!statusCtx) return;
  const { total, done } = answered(notes);
  if (total === 0 || (done === total && Date.now() / 1000 - sentAt > 120)) {
    statusCtx.statusLine.clear("progress");
    return;
  }
  const spans: { text: string; tone?: string }[] = [];
  const step = (text: string, tone: string) => {
    if (spans.length) spans.push({ text: " · ", tone: "muted" });
    spans.push({ text, tone });
  };
  if (done === total) {
    step(`${total} note${total > 1 ? "s" : ""} answered ✓`, "added");
  } else {
    const mate = progress.mate || "second mate";
    step(TO === "tab" ? "agent ✓" : "firstmate ✓", "added");
    if (TO !== "tab")
      step(
        progress.stage ? `${mate} ✓` : `${mate} …`,
        progress.stage ? "added" : "muted",
      );
    const crew =
      {
        working: ["crewmate working…", "accent"],
        blocked: ["crewmate needs you", "removed"],
        error: ["crewmate error", "removed"],
      }[progress.crew] ?? (progress.stage ? ["crewmate idle", "muted"] : null);
    if (crew) step(crew[0], crew[1]);
    step(`${done}/${total} answered`, "muted");
  }
  statusCtx.statusLine.set({ id: "progress", spans });
}

async function refreshProgress(): Promise<void> {
  if (TO === "tab") return;
  const { out } = await run(FM_TODO, ["note-progress", PR]);
  const [mate = "", stage = "", crew = ""] = out.replace(/\n$/, "").split("\t");
  progress = { mate, stage, crew };
}

async function poll(tick: number): Promise<void> {
  if (!session) session = await hunkSessionId();
  if (!session) return;
  if (!restored) {
    restored = true;
    const lost = await restore();
    if (lost)
      statusCtx?.statusLine.set({
        id: "restore",
        spans: [
          {
            text: `${lost} saved note${lost > 1 ? "s" : ""} no longer map onto this diff`,
            tone: "muted",
          },
        ],
      });
  }
  const notes = await liveNotes();
  if (!notes) return;
  persist(notes);
  const { total, done } = answered(notes);
  if (total > done && tick % 2 === 0) await refreshProgress();
  showStatus(notes);
}

async function hunkTabmate(): Promise<
  | { kind: "rex"; session: string; block: string }
  | { kind: "tmux"; pane: string }
  | null
> {
  const env = process.env;
  if (env.TERM_PROGRAM === "rex" && env.REX_BLOCK && !env.TMUX) {
    const rexSession = env.REX_SESSION ?? "";
    const me = env.REX_BLOCK;
    const { out } = await run("rex", [
      "--autostart=false",
      "block",
      "ls",
      "-s",
      rexSession,
      "--json",
    ]);
    try {
      const blocks = (JSON.parse(out || "{}").blocks ?? []) as {
        block_id: string;
        window_id: string;
      }[];
      const mine = blocks.find((b) => b.block_id === me);
      const other =
        mine &&
        blocks.find((b) => b.window_id === mine.window_id && b.block_id !== me);
      return other
        ? { kind: "rex", session: rexSession, block: other.block_id }
        : null;
    } catch {
      return null;
    }
  }
  if (env.TMUX && env.TMUX_PANE) {
    const { out } = await run("tmux", ["list-panes", "-F", "#{pane_id}"]);
    const other = out.split("\n").find((p) => p && p !== env.TMUX_PANE);
    return other ? { kind: "tmux", pane: other } : null;
  }
  return null;
}

async function send(text: string): Promise<string> {
  if (TO !== "tab") return (await run(FM_TODO, ["send", text])).err;
  const to = await hunkTabmate();
  if (!to) return "no agent pane beside this one";
  if (to.kind === "tmux")
    return (await run("tmux", ["send-keys", "-t", to.pane, "-l", text + "\r"]))
      .err;
  const first = await run("rex", [
    "--autostart=false",
    "send",
    "-s",
    to.session,
    "-b",
    to.block,
    text,
  ]);
  if (first.err) return first.err;
  return (
    await run("rex", [
      "--autostart=false",
      "send",
      "-s",
      to.session,
      "-b",
      to.block,
      "\r",
    ])
  ).err;
}

export default function (hunk: HunkExtensionAPI) {
  if (!PR) return;
  const number = PR.split("#")[1] ?? PR;
  const work = TICKET ? `${TICKET} / PR #${number}` : `PR #${number}`;
  const who = TO === "tab" ? "the agent" : "firstmate";
  let tick = 0;
  hunk.on("changeset_loaded", (_payload, ctx) => {
    statusCtx = ctx as unknown as StatusCtx;
  });
  setInterval(() => void poll(tick++), 3000).unref?.();
  void poll(tick++);

  hunk.registerCommand(
    { id: "open", title: "Open file at the PR commit in nvim", key: "o" },
    async (ctx) => {
      const file = ctx.selection.file;
      if (!file) {
        ctx.notify("no file selected", "info");
        return;
      }
      const at = ctx.selection.currentLine ?? { side: "new", line: 1 };
      const path =
        at.side === "old" ? (file.previousPath ?? file.path) : file.path;
      const repo = PR.split("#")[0];
      const { err } = await run(
        FM_TODO_BIN,
        ["pr-open", repo, number, at.side, String(at.line), path, TICKET],
        undefined,
        60000,
      );
      if (err) ctx.notify(`nvim not opened: ${err}`, "error");
    },
  );

  hunk.registerCommand(
    { id: "send", title: `Send saved notes to ${who}`, key: "S" },
    async (ctx) => {
      statusCtx = ctx as unknown as StatusCtx;
      if (!session) session = await hunkSessionId();
      const all = (await liveNotes()) ?? [];
      const notes = unsent(all);
      if (notes.length === 0) {
        ctx.notify("no unsent notes", "info");
        return;
      }
      const plural = notes.length > 1 ? "s" : "";
      const ok = await ctx.dialogs.confirm({
        title: `Send to ${who}`,
        body: `Send ${notes.length} note${plural} on ${work} to ${who}?`,
      });
      if (!ok) return;
      const items = notes.map((n, i) => {
        const at = anchor(n);
        const thread = n.parentId ? ` replying to ${n.parentId}` : "";
        const body = n.body.replace(/\s*\n\s*/g, " ").trim();
        return `(${i + 1}) ${n.filePath}:${at.line} (${at.side}) note ${n.noteId}${thread}: ${body}`;
      });
      const head =
        TO === "tab"
          ? `${notes.length} Hunk note${plural} from the reviewer on ${work} [hunk session ${session}]: `
          : `Captain, ${notes.length} Hunk note${plural} on ${work} [hunk session ${session}, pr ${PR}]: `;
      const tail =
        TO === "tab"
          ? ` -- answer each on its own line with: hunk session comment add ${session} --reply-to <note id> --author reviewer --summary "<answer>"; questions back to me go the same way.`
          : "";
      const err = await send(head + items.join(" ; ") + tail);
      if (err) {
        ctx.notify(`${who} not reached: ${err}`, "error");
        return;
      }
      for (const n of notes) sentKeys.add(keyFor(n.noteId));
      sentAt = Date.now() / 1000;
      if (TO !== "tab") await run(FM_TODO, ["note-stage", PR, ""]);
      progress = { mate: progress.mate, stage: "", crew: "" };
      persist(all);
      showStatus(all);
      ctx.notify(`${notes.length} sent to ${who}`, "info");
    },
  );
}
