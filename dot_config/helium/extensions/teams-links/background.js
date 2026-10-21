const CLOSE_DELAY_MS = 1500;

chrome.webNavigation.onBeforeNavigate.addListener(
  async ({ tabId, frameId, url }) => {
    if (frameId !== 0) return;
    const tab = await chrome.tabs.get(tabId);
    const win = await chrome.windows.get(tab.windowId);
    if (win.type !== "normal") return;

    const { pathname, search, hash } = new URL(url);
    await chrome.tabs.update(tabId, {
      url: `msteams:${pathname}${search}${hash}`,
    });
    setTimeout(() => chrome.tabs.remove(tabId).catch(() => {}), CLOSE_DELAY_MS);
  },
  { url: [{ hostEquals: "teams.microsoft.com", pathPrefix: "/l/" }] },
);
