import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { homedir } from "node:os";
import { join } from "node:path";
import { mock } from "bun:test";

const app = process.env.BABY_MENU_REPO ?? join(homedir(), "Developer/baby-menu-sidebar");
const require = createRequire(join(app, "package.json"));
const { JSDOM } = await import(require.resolve("jsdom"));
const dom = new JSDOM('<html><body><div id="root"></div></body></html>', { url: "http://localhost" });
for (const key of ["window", "document", "HTMLElement", "HTMLInputElement", "HTMLTextAreaElement", "HTMLSelectElement"])
  globalThis[key] = dom.window[key];
globalThis.IS_REACT_ACT_ENVIRONMENT = true;
document.documentElement.dataset.windowMode = "sidebar";

const timers = new Map();
window.setInterval = (callback) => {
  const id = timers.size + 1;
  timers.set(id, callback);
  return id;
};
window.clearInterval = (id) => timers.delete(id);
let clock = Date.parse("2026-10-08T01:12:00Z");
const originalNow = Date.now;
Date.now = () => clock;

const React = await import(require.resolve("react"));
const jsx = await import(require.resolve("react/jsx-runtime"));
mock.module("react", () => React);
mock.module("react/jsx-runtime", () => jsx);
mock.module("@babymenu/ui", () => ({ Switch: () => null }));
const { createRoot } = await import(require.resolve("react-dom/client"));
const { OperationsView } = await import("../dot_baby-menu-sidebar/extensions/operations/components.tsx");
const { refreshOperations } = await import("../dot_baby-menu-sidebar/extensions/operations/refresh.ts");
const { claudeFromUsage } = await import("../dot_baby-menu-sidebar/extensions/operations/claude-quota.ts");

function dashboard() {
  return {
    quotaProviders: [claudeFromUsage(`${clock / 1000}\t0.01\t${(clock + 3600000) / 1000}\t0.18\t${(clock + 86400000) / 1000}`, "personal", clock)],
    quotaGeneratedAt: new Date(clock).toISOString(),
    quotaColors: { danger: "#ff6a7a", warning: "#ffd86b", orange: "#f5a65b", live: "#6ae3b6", groups: [] },
    tokens: [], schedules: [], activeSchedules: 0, problemSchedules: 0,
    totalSchedules: 0, aiSchedules: 0, errors: [], refreshedAt: new Date(clock).toISOString(),
  };
}

window.babyMenu = { capabilities: { invoke: async () => dashboard() } };
const root = createRoot(document.getElementById("root"));
try {
  await React.act(async () => root.render(React.createElement(OperationsView, { variant: "usage" })));
  assert.equal(document.querySelectorAll('[role="alert"]').length, 0);
  assert.match(document.body.textContent, /99%/);

  clock += 300000;
  await React.act(async () => { for (const tick of timers.values()) tick(); });
  assert.match(document.querySelector('[role="alert"]').textContent, /Usage readings need attention/);
  assert.match(document.body.textContent, /Last update 5m ago/);
  assert.doesNotMatch(document.body.textContent, /99%|exhausted now/);

  await React.act(async () => refreshOperations());
  assert.equal(document.querySelectorAll('[role="alert"]').length, 0);
  assert.match(document.body.textContent, /99%/);

  window.babyMenu.capabilities.invoke = async () => { throw new Error("bridge disconnected"); };
  await React.act(async () => refreshOperations());
  assert.match(document.body.textContent, /Refresh failed. Previous readings are not current/);
  assert.doesNotMatch(document.body.textContent, /99%/);

  window.babyMenu.capabilities.invoke = async () => dashboard();
  await React.act(async () => refreshOperations());
  assert.equal(document.querySelectorAll('[role="alert"]').length, 0);

  await React.act(async () => root.unmount());
  assert.equal(timers.size, 0);
  console.log("Usage warning UI checks passed: stopped polling, hidden stale numbers, failed refresh, recovery, timer cleanup");
} finally {
  Date.now = originalNow;
  dom.window.close();
}
