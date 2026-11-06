// In a PR review opened for an agent, S sends every note saved since the last send as one message: to firstmate, or with FM_NOTES_TO=tab to the agent pane beside this one.
import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import type { HunkExtensionAPI } from "hunkdiff/extension";

const PR = process.env.FM_HUNK_PR ?? "";
const TICKET = process.env.FM_HUNK_TICKET ?? "";
const TO = process.env.FM_NOTES_TO ?? "";
const FM_TODO =
  process.env.FM_NOTES_SEND ?? join(homedir(), ".local", "bin", "fm-todo");

type Note = {
  id: string;
  parentId?: string;
  source?: string;
  fileKey?: string;
  anchor?: { preferred?: { side?: string; line?: number } };
  summary?: string;
};
type Snapshot = {
  files?: { fileKey?: string; path?: string }[];
  notes?: Note[];
};

const sent = new Set<string>();

function run(
  cmd: string,
  args: string[],
): Promise<{ err: string; out: string }> {
  return new Promise((resolve) =>
    execFile(cmd, args, { timeout: 8000 }, (err, stdout) =>
      resolve({ err: err ? err.message : "", out: stdout ?? "" }),
    ),
  );
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

// The agent pane is the other pane in this window: Rex when this is a Rex pane outside tmux, else tmux.
type Mate = { kind: "rex"; session: string; block: string } | { kind: "tmux"; pane: string };

async function tabmate(): Promise<Mate | null> {
  const env = process.env;
  if (env.TERM_PROGRAM === "rex" && env.REX_BLOCK && !env.TMUX) {
    const session = env.REX_SESSION ?? "";
    const me = env.REX_BLOCK;
    const { out } = await run("rex", ["--autostart=false", "block", "ls", "-s", session, "--json"]);
    try {
      const blocks = (JSON.parse(out || "{}").blocks ?? []) as { block_id: string; window_id: string }[];
      const mine = blocks.find((b) => b.block_id === me);
      const other = mine && blocks.find((b) => b.window_id === mine.window_id && b.block_id !== me);
      return other ? { kind: "rex", session, block: other.block_id } : null;
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
  const to = await tabmate();
  if (!to) return "no agent pane beside this one";
  if (to.kind === "tmux") return (await run("tmux", ["send-keys", "-t", to.pane, "-l", text + "\r"])).err;
  const first = await run("rex", ["--autostart=false", "send", "-s", to.session, "-b", to.block, text]);
  if (first.err) return first.err;
  return (await run("rex", ["--autostart=false", "send", "-s", to.session, "-b", to.block, "\r"])).err;
}

export default function (hunk: HunkExtensionAPI) {
  if (!PR) return;
  const number = PR.split("#")[1] ?? PR;
  const work = TICKET ? `${TICKET} / PR #${number}` : `PR #${number}`;
  const who = TO === "tab" ? "the agent" : "firstmate";
  hunk.registerCommand(
    { id: "send", title: `Send saved notes to ${who}`, key: "S" },
    async (ctx) => {
      const snap = (ctx.review?.snapshot?.() ?? {}) as Snapshot;
      const paths = new Map(
        (snap.files ?? []).map((f) => [f.fileKey ?? "", f.path ?? ""]),
      );
      const notes = (snap.notes ?? []).filter(
        (n) =>
          n.source === "user" && !sent.has(n.id) && (n.summary ?? "").trim(),
      );
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
      const session = await hunkSessionId();
      const items = notes.map((n, i) => {
        const at = n.anchor?.preferred;
        const where = at?.line ? `:${at.line} (${at.side})` : "";
        const thread = n.parentId ? ` replying to ${n.parentId}` : "";
        const body = (n.summary ?? "").replace(/\s*\n\s*/g, " ").trim();
        return `(${i + 1}) ${paths.get(n.fileKey ?? "") || n.fileKey}${where} note ${n.id}${thread}: ${body}`;
      });
      const head =
        TO === "tab"
          ? `${notes.length} Hunk note${plural} from the reviewer on ${work} [hunk session ${session}]: `
          : `Captain, ${notes.length} Hunk note${plural} on ${work} [hunk session ${session}]: `;
      const tail =
        TO === "tab"
          ? ` -- answer each on its own line with: hunk session comment add ${session} --reply-to <note id> --author reviewer --summary "<answer>"; questions back to me go the same way.`
          : "";
      const err = await send(head + items.join(" ; ") + tail);
      if (err) {
        ctx.notify(`${who} not reached: ${err}`, "error");
        return;
      }
      for (const n of notes) sent.add(n.id);
      ctx.notify(`${notes.length} sent to ${who}`, "info");
    },
  );
}
