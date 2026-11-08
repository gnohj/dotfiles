// Read-only GitHub review threads for a PR review opened with FM_HUNK_PR=owner/repo#N: T docks them in a pane, j/k walks them and the diff follows.
import { useEffect, useRef, useSyncExternalStore, type ReactNode } from "react";
import type { ScrollBoxRenderable } from "@opentui/core";
import type { ExtensionPaneProps, HunkExtensionAPI } from "hunkdiff/extension";
import { execFile } from "node:child_process";

const PR = process.env.FM_HUNK_PR ?? "";

type Comment = { author: string; bot: boolean; body: string; at: string };
type Thread = {
  id: string;
  path: string;
  line: number;
  side: "old" | "new";
  status: "open" | "resolved" | "outdated";
  comments: Comment[];
};
type State = {
  phase: "loading" | "ready" | "error";
  threads: Thread[];
  all: Thread[];
  showHidden: boolean;
  resolved: number;
  outdated: number;
  error: string;
  active: string | null;
  mode: boolean;
  me: string;
};

let state: State = {
  phase: "loading",
  threads: [],
  all: [],
  showHidden: false,
  resolved: 0,
  outdated: 0,
  error: "",
  active: null,
  mode: false,
  me: "",
};
const listeners = new Set<() => void>();

function setState(patch: Partial<State>) {
  state = { ...state, ...patch };
  for (const l of listeners) l();
}

function useThreads(): State {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l);
      return () => listeners.delete(l);
    },
    () => state,
  );
}

const QUERY = `query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){pullRequest(number:$number){reviewThreads(first:100){nodes{id isResolved isOutdated path line originalLine diffSide comments(first:100){nodes{body createdAt author{login __typename}}}}}}}}`;

type GqlThread = {
  id: string;
  isResolved: boolean;
  isOutdated: boolean;
  path: string;
  line: number | null;
  originalLine: number | null;
  diffSide: "LEFT" | "RIGHT";
  comments: {
    nodes: {
      body: string;
      createdAt: string;
      author: { login: string; __typename: string } | null;
    }[];
  };
};

function gh(args: string[]): Promise<string> {
  const env = { ...process.env };
  delete env.GH_TOKEN;
  delete env.GITHUB_TOKEN;
  return new Promise((resolve, reject) =>
    execFile(
      "gh",
      args,
      { env, timeout: 15000, maxBuffer: 32 * 1024 * 1024 },
      (err, stdout, stderr) =>
        err
          ? reject(new Error((stderr || err.message).split("\n")[0]))
          : resolve(stdout),
    ),
  );
}

function ghGraphql(
  owner: string,
  name: string,
  number: string,
): Promise<string> {
  return gh([
    "api",
    "graphql",
    "-f",
    `query=${QUERY}`,
    "-F",
    `owner=${owner}`,
    "-F",
    `name=${name}`,
    "-F",
    `number=${number}`,
  ]);
}

function loadMe(): void {
  gh(["api", "user", "-q", ".login"]).then(
    (out) => setState({ me: out.trim() }),
    () => {},
  );
}

function clean(body: string): string {
  return body
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(
      /<\/?(details|summary|p|div|sub|sup|b|i|em|strong|br|img|a)\b[^>]*>/gi,
      "",
    )
    .replace(/\r/g, "")
    .replace(/\*\*(.+?)\*\*/g, "$1")
    .replace(/__(.+?)__/g, "$1")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/^#{1,6}\s+/gm, "")
    .replace(/^(\s*)[-*]\s+/gm, "$1• ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

async function load(): Promise<void> {
  const [slug, number] = PR.split("#");
  const [owner, name] = (slug ?? "").split("/");
  if (!owner || !name || !number) {
    setState({ phase: "error", error: `bad FM_HUNK_PR: ${PR}` });
    return;
  }
  setState({ phase: "loading" });
  try {
    const raw = JSON.parse(await ghGraphql(owner, name, number));
    const nodes: GqlThread[] =
      raw?.data?.repository?.pullRequest?.reviewThreads?.nodes ?? [];
    const rank = { open: 0, resolved: 1, outdated: 2 };
    const all: Thread[] = nodes
      .filter((t) => (t.line ?? t.originalLine) != null)
      .map((t) => ({
        id: t.id,
        path: t.path,
        line: (t.line ?? t.originalLine) as number,
        side: t.diffSide === "LEFT" ? "old" : "new",
        status: t.isResolved
          ? "resolved"
          : t.isOutdated || t.line == null
            ? "outdated"
            : "open",
        comments: t.comments.nodes.map((c) => ({
          author: c.author?.login ?? "ghost",
          bot: c.author?.__typename === "Bot",
          body: clean(c.body),
          at: c.createdAt,
        })),
      }));
    all.sort(
      (a, b) =>
        rank[a.status] - rank[b.status] ||
        a.path.localeCompare(b.path) ||
        a.line - b.line,
    );
    const threads = visible(all, state.showHidden);
    const keep = threads.some((t) => t.id === state.active)
      ? state.active
      : (threads[0]?.id ?? null);
    setState({
      phase: "ready",
      threads,
      all,
      resolved: nodes.filter((t) => t.isResolved).length,
      outdated: nodes.filter(
        (t) => !t.isResolved && (t.isOutdated || t.line == null),
      ).length,
      active: keep,
    });
  } catch (e) {
    setState({ phase: "error", error: (e as Error).message });
  }
}

function visible(all: Thread[], showHidden: boolean): Thread[] {
  return showHidden ? all : all.filter((t) => t.status === "open");
}

function toggleHidden(): void {
  const showHidden = !state.showHidden;
  const threads = visible(state.all, showHidden);
  setState({
    showHidden,
    threads,
    active: threads.some((t) => t.id === state.active) ? state.active : null,
  });
}

function move(to: 1 | -1 | "first" | "last") {
  const ids = state.threads.map((t) => t.id);
  if (ids.length === 0) return;
  const cur = state.active ? ids.indexOf(state.active) : -1;
  const next =
    to === "first"
      ? 0
      : to === "last"
        ? ids.length - 1
        : Math.min(ids.length - 1, Math.max(0, cur + to));
  setState({ active: ids[next] });
}

function age(iso: string): string {
  const s = Math.max(0, (Date.now() - Date.parse(iso)) / 1000);
  if (s < 3600) return `${Math.floor(s / 60)}m`;
  if (s < 86400) return `${Math.floor(s / 3600)}h`;
  return `${Math.floor(s / 86400)}d`;
}

function wrap(text: string, width: number): string[] {
  const out: string[] = [];
  for (const raw of text.split("\n")) {
    if (!raw.trim()) {
      out.push("");
      continue;
    }
    const lead = raw.match(/^\s*/)?.[0] ?? "";
    let cur = "";
    for (const word of raw.trim().split(/\s+/)) {
      for (let w = word; w.length > 0;) {
        const room = width - lead.length - (cur ? cur.length + 1 : 0);
        if (w.length <= room) {
          cur = cur ? `${cur} ${w}` : w;
          w = "";
        } else if (cur) {
          out.push(lead + cur);
          cur = "";
        } else {
          out.push(lead + w.slice(0, width - lead.length));
          w = w.slice(width - lead.length);
        }
      }
    }
    if (cur) out.push(lead + cur);
  }
  return out;
}

type Theme = ExtensionPaneProps["theme"];
type Seg = { text: string; fg: string };

function codeSpans(lines: string[], fg: string, codeFg: string): Seg[][] {
  let inCode = false;
  return lines.map((line) => {
    const segs: Seg[] = [];
    line.split("`").forEach((part, i) => {
      if (i > 0) inCode = !inCode;
      if (part) segs.push({ text: part, fg: inCode ? codeFg : fg });
    });
    return segs;
  });
}

function Row({
  bar,
  segs,
  theme,
}: {
  bar: boolean;
  segs: Seg[];
  theme: Theme;
}): ReactNode {
  return (
    <text style={{ bg: theme.panel }}>
      <span fg={theme.accent}>{bar ? "▌" : " "}</span>
      {segs.map((s, i) => (
        <span key={i} fg={s.fg}>
          {s.text}
        </span>
      ))}
    </text>
  );
}

function authorSegs(c: Comment, me: string, theme: Theme): Seg {
  if (me && c.author === me) return { text: "you", fg: theme.fileModified };
  return {
    text: `@${c.author}${c.bot ? " (bot)" : ""}`,
    fg: c.bot ? theme.accentMuted : theme.accent,
  };
}

function threadRows(
  t: Thread,
  active: boolean,
  me: string,
  width: number,
  theme: Theme,
): Seg[][] {
  const room = Math.max(width - 6, 12);
  const slash = t.path.lastIndexOf("/");
  const rows: Seg[][] = [];
  const tag = t.status === "open" ? "" : ` · ${t.status}`;
  for (const line of wrap(
    `${t.path.slice(slash + 1)}:${t.line}${tag}`,
    width - 2,
  ))
    rows.push([
      {
        text: ` ${line}`,
        fg:
          t.status !== "open"
            ? theme.muted
            : active
              ? theme.accent
              : theme.text,
      },
    ]);
  if (!active) {
    const first = t.comments[0];
    const replies = t.comments.length - 1;
    const tail = ` · ${age(t.comments[t.comments.length - 1]?.at ?? first?.at ?? "")}${replies ? ` · ↳${replies}` : ""}`;
    if (first) {
      const who = authorSegs(first, me, theme);
      wrap(`${who.text}${tail}`, width - 3).forEach((line, k) =>
        rows.push(
          k === 0
            ? [
                { text: "  ", fg: theme.muted },
                { text: line.slice(0, who.text.length), fg: who.fg },
                { text: line.slice(who.text.length), fg: theme.muted },
              ]
            : [{ text: `  ${line}`, fg: theme.muted }],
        ),
      );
    }
    return rows;
  }
  if (slash > 0)
    for (const line of wrap(t.path.slice(0, slash), width - 2))
      rows.push([{ text: ` ${line}`, fg: theme.muted }]);
  t.comments.forEach((c, i) => {
    const reply = i > 0;
    const gutter = reply ? "  │ " : "  ";
    rows.push([]);
    rows.push([
      { text: reply ? "  ↳ " : "  ", fg: theme.border },
      authorSegs(c, me, theme),
      { text: ` · ${age(c.at)}`, fg: theme.muted },
    ]);
    for (const segs of codeSpans(
      wrap(c.body, room),
      theme.text,
      theme.badgeAdded,
    ))
      rows.push([{ text: gutter, fg: theme.border }, ...segs]);
  });
  return rows;
}

function ThreadsPane({
  files,
  width,
  theme,
  actions,
  currentLine,
  selectedFileId,
}: ExtensionPaneProps): ReactNode {
  const s = useThreads();
  const scroll = useRef<ScrollBoxRenderable | null>(null);

  const reveal = (t: Thread) => {
    const file = files.find((f) => f.path === t.path);
    if (file) actions.revealLine(file.id, t.side, t.line);
  };

  useEffect(() => {
    if (s.mode || s.phase !== "ready") return;
    const path = files.find((f) => f.id === selectedFileId)?.path;
    const hit = currentLine
      ? s.threads.find(
          (t) =>
            t.path === path &&
            t.side === currentLine.side &&
            t.line === currentLine.line,
        )
      : undefined;
    const id = hit?.id ?? null;
    if (id !== state.active) setState({ active: id });
  }, [
    currentLine?.side,
    currentLine?.line,
    selectedFileId,
    s.mode,
    s.phase,
    s.threads,
  ]);

  useEffect(() => {
    if (s.phase !== "ready" || !s.active) return;
    scroll.current?.scrollChildIntoView(`gh-${s.active}`);
    const t = s.threads.find((x) => x.id === s.active);
    if (t && s.mode) reveal(t);
  }, [s.active, s.mode, s.phase]);

  const hidden = s.resolved + s.outdated;
  const rule = ` ${"─".repeat(Math.max(width - 3, 4))}`;
  const pick = (t: Thread) => {
    setState({ active: t.id });
    reveal(t);
  };

  let body: ReactNode;
  if (s.phase === "loading" && s.threads.length === 0) {
    body = (
      <text
        content=" loading threads"
        style={{ fg: theme.muted, bg: theme.panel }}
      />
    );
  } else if (s.phase === "error") {
    body = (
      <text
        content={` ${s.error}`}
        style={{ fg: theme.badgeRemoved, bg: theme.panel }}
      />
    );
  } else {
    body = (
      <>
        <text
          content={` ${s.all.filter((t) => t.status === "open").length} open`}
          style={{ fg: theme.muted, bg: theme.panel }}
        />
        {hidden ? (
          <text
            content={` ${[s.resolved ? `${s.resolved} resolved` : "", s.outdated ? `${s.outdated} outdated` : ""].filter(Boolean).join(" · ")}`}
            style={{ fg: theme.muted, bg: theme.panel }}
          />
        ) : null}
        {hidden ? (
          <text
            content={` H ${s.showHidden ? "hides" : "shows"} ${hidden === 1 ? "it" : "them"}`}
            style={{ fg: theme.accentMuted, bg: theme.panel }}
          />
        ) : null}
        {s.threads.map((t) => {
          const active = t.id === s.active;
          return (
            <box
              key={t.id}
              id={`gh-${t.id}`}
              style={{ flexDirection: "column", backgroundColor: theme.panel }}
              onMouseDown={() => pick(t)}
            >
              <text
                content={rule}
                style={{ fg: theme.border, bg: theme.panel }}
              />
              {threadRows(t, active, s.me, width, theme).map((segs, i) => (
                <Row key={i} bar={active} segs={segs} theme={theme} />
              ))}
            </box>
          );
        })}
      </>
    );
  }

  return (
    <scrollbox
      ref={scroll}
      width="100%"
      height="100%"
      focused={false}
      scrollY={true}
      rootOptions={{ backgroundColor: theme.panel }}
      wrapperOptions={{ backgroundColor: theme.panel }}
      viewportOptions={{ backgroundColor: theme.panel }}
      contentOptions={{ backgroundColor: theme.panel }}
      verticalScrollbarOptions={{ visible: false }}
      horizontalScrollbarOptions={{ visible: false }}
    >
      <box
        style={{
          width: "100%",
          flexDirection: "column",
          backgroundColor: theme.panel,
        }}
      >
        <text
          content={` GitHub threads · #${PR.split("#")[1] ?? ""}`}
          style={{ fg: theme.accent, bg: theme.panel }}
        />
        <text
          content={
            s.mode
              ? " j/k threads · esc back to diff"
              : " T threads · c note · S send"
          }
          style={{ fg: theme.accentMuted, bg: theme.panel }}
        />
        {body}
      </box>
    </scrollbox>
  );
}

export default function (hunk: HunkExtensionAPI) {
  if (!PR) return;
  void load();
  loadMe();
  hunk.on("session_reload", () => void load());

  hunk.registerPane({
    id: "threads",
    title: "GitHub threads",
    placement: "right",
    width: { preferred: 34, min: 22, max: 56, fraction: 0.16 },
    defaultOpen: true,
    currentLine: true,
    component: ThreadsPane,
  });

  hunk.registerKeyboardMode({
    id: "threads",
    title: "GitHub threads",
    onKey: (key) => {
      switch (key.name) {
        case "j":
        case "down":
          move(1);
          return "handled";
        case "k":
        case "up":
          move(-1);
          return "handled";
        case "g":
          move("first");
          return "handled";
        case "G":
          move("last");
          return "handled";
        case "T":
        case "q":
        case "escape":
        case "return":
        case "enter":
          return "exit";
        default:
          return "pass";
      }
    },
    onEnter: () => setState({ mode: true }),
    onExit: () => setState({ mode: false }),
  });

  hunk.registerCommand(
    { id: "toggle", title: "Walk GitHub review threads", key: "T" },
    (ctx) => {
      if (!ctx.panes.isOpen("threads")) ctx.panes.open("threads");
      if (state.threads.length > 0) {
        if (!state.active) setState({ active: state.threads[0].id });
        ctx.keyboardModes.enterMode("threads");
      } else if (state.phase === "ready")
        ctx.notify("no open review threads on this PR", "info");
    },
  );

  hunk.registerCommand(
    {
      id: "hidden",
      title: "Show resolved and outdated GitHub threads",
      key: "H",
    },
    () => toggleHidden(),
  );

  hunk.registerCommand(
    { id: "close", title: "Toggle GitHub threads pane" },
    (ctx) => {
      if (ctx.keyboardModes.isActive("threads")) ctx.keyboardModes.exitMode();
      ctx.panes.toggle("threads");
    },
  );
}
