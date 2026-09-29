// Preloaded into review sessions: a headed launch() opens a new app that macOS activates, so attach to the guarded browser instead.
const Module = require("node:module");

const endpoint = process.env.PLAYWRIGHT_MCP_CDP_ENDPOINT || process.env.CHROME_DEVTOOLS_AXI_BROWSER_URL || "";
const PATCHED = Symbol.for("review-browser-attach");

function note(what) {
  process.stderr.write(`review-browser-attach: ${what}\n`);
}

function headed(options) {
  return options && options.headless === false;
}

function patchPlaywrightType(type) {
  if (!type || type[PATCHED] || typeof type.launch !== "function") return;
  type[PATCHED] = true;
  const { launch, launchPersistentContext } = type;
  const attach = endpoint && typeof type.connectOverCDP === "function" && type.name() === "chromium";
  type.launch = function (options = {}) {
    if (!headed(options)) return launch.call(this, options);
    if (attach) {
      note(`headed ${type.name()}.launch() attached to ${endpoint}`);
      return this.connectOverCDP(endpoint);
    }
    note(`headed ${type.name()}.launch() forced headless`);
    return launch.call(this, { ...options, headless: true });
  };
  if (typeof launchPersistentContext === "function") {
    type.launchPersistentContext = async function (dir, options = {}) {
      if (!headed(options)) return launchPersistentContext.call(this, dir, options);
      if (attach) {
        note(`headed ${type.name()}.launchPersistentContext() attached to ${endpoint}`);
        const browser = await this.connectOverCDP(endpoint);
        return browser.contexts()[0] || browser.newContext();
      }
      note(`headed ${type.name()}.launchPersistentContext() forced headless`);
      return launchPersistentContext.call(this, dir, { ...options, headless: true });
    };
  }
}

function patchPuppeteer(pptr) {
  if (!pptr || pptr[PATCHED] || typeof pptr.launch !== "function" || typeof pptr.connect !== "function") return;
  pptr[PATCHED] = true;
  const { launch } = pptr;
  pptr.launch = function (options = {}) {
    if (!headed(options)) return launch.call(this, options);
    if (endpoint) {
      note(`headed puppeteer.launch() attached to ${endpoint}`);
      return this.connect({ browserURL: endpoint, defaultViewport: options.defaultViewport });
    }
    note("headed puppeteer.launch() forced headless");
    return launch.call(this, { ...options, headless: true });
  };
}

function patch(exports) {
  if (!exports || (typeof exports !== "object" && typeof exports !== "function")) return;
  for (const name of ["chromium", "firefox", "webkit"]) {
    try {
      if (exports[name] && typeof exports[name].connectOverCDP !== "undefined") patchPlaywrightType(exports[name]);
    } catch {}
  }
  try {
    if (typeof exports.launch === "function" && typeof exports.connect === "function" && typeof exports.executablePath === "function") patchPuppeteer(exports);
    if (exports.default && typeof exports.default.launch === "function") patch(exports.default);
  } catch {}
}

const load = Module._load;
Module._load = function (request, ...rest) {
  const exports = load.call(this, request, ...rest);
  // An ESM import reaches here as the package's absolute index.js path, not its name.
  if (/(^|[\\/])(playwright(-core|-chromium)?|@playwright[\\/]test|puppeteer(-core)?)([\\/]index\.c?js)?$/.test(request)) patch(exports);
  return exports;
};
