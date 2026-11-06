const CLOSE_DELAY_MS = 1500;

const TEAMS_HOSTS = ["teams.microsoft.com", "teams.cloud.microsoft"];
const TEAMS_PATHS = ["/l/", "/meet/"];
const OUTLOOK_HOSTS = [
  "outlook.office.com",
  "outlook.office365.com",
  "outlook.cloud.microsoft",
];

const handOff = (url) => {
  const { hostname, pathname, search, hash } = new URL(url);
  if (TEAMS_HOSTS.includes(hostname)) {
    return `msteams:${pathname}${search}${hash}`;
  }
  return `outlook-pwa:${url}`;
};

chrome.webNavigation.onBeforeNavigate.addListener(
  async ({ tabId, frameId, url }) => {
    if (frameId !== 0) return;
    const tab = await chrome.tabs.get(tabId);
    const win = await chrome.windows.get(tab.windowId);
    if (win.type !== "normal") return;

    await chrome.tabs.update(tabId, { url: handOff(url) });
    setTimeout(() => chrome.tabs.remove(tabId).catch(() => {}), CLOSE_DELAY_MS);
  },
  {
    url: [
      ...TEAMS_HOSTS.flatMap((hostEquals) =>
        TEAMS_PATHS.map((pathPrefix) => ({ hostEquals, pathPrefix })),
      ),
      ...OUTLOOK_HOSTS.map((hostEquals) => ({ hostEquals })),
    ],
  },
);
