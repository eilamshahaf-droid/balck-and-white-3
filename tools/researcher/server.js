// Local researcher: searches free open-licence image sources and saves picks into a folder
// (e.g. one synced by Google Drive). Zero dependencies; needs Node 18+.
const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = 5177;
const ROOT = __dirname;
const CONFIG_FILE = path.join(ROOT, "config.json");
const UA = "SpinCycleResearcher/1.0 (local tool)";
const HAIKU_MODEL = "claude-haiku-5-5";
const DEFAULTS = {
  outputDir: path.join(ROOT, "downloads"),
  pexelsKey: "",
  unsplashKey: "",
  anthropicKey: "",
};

function loadConfig() {
  try {
    return { ...DEFAULTS, ...JSON.parse(fs.readFileSync(CONFIG_FILE, "utf8")) };
  } catch {
    return { ...DEFAULTS };
  }
}
function saveConfig(cfg) {
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(cfg, null, 2));
}
const mask = (k) => (k ? "••••" + k.slice(-4) : "");

async function getJson(url, headers = {}) {
  const r = await fetch(url, { headers: { "User-Agent": UA, ...headers } });
  if (!r.ok) throw new Error(`${new URL(url).host}: HTTP ${r.status}`);
  return r.json();
}

// Each provider returns [{id, provider, title, thumb, full, author, license, page, download?}]
const providers = {
  async wikimedia(q, n) {
    const p = new URLSearchParams({
      action: "query", format: "json", generator: "search", gsrnamespace: "6",
      gsrsearch: `${q} filetype:bitmap`, gsrlimit: String(n), prop: "imageinfo",
      iiprop: "url|extmetadata|mime|size", iiurlwidth: "400",
    });
    const j = await getJson("https://commons.wikimedia.org/w/api.php?" + p);
    return Object.values(j.query?.pages || {})
      .sort((a, b) => a.index - b.index)
      .map((pg) => {
        const i = pg.imageinfo?.[0];
        if (!i || !/^image\/(jpeg|png)$/.test(i.mime)) return null;
        const m = i.extmetadata || {};
        return {
          id: "wm" + pg.pageid, provider: "Wikimedia Commons",
          title: pg.title.replace(/^File:/, ""), thumb: i.thumburl, full: i.url,
          author: (m.Artist?.value || "").replace(/<[^>]+>/g, ""),
          license: m.LicenseShortName?.value || "see page", page: i.descriptionurl,
        };
      })
      .filter(Boolean);
  },
  async pexels(q, n, cfg) {
    if (!cfg.pexelsKey) throw new Error("Pexels: no key (Settings)");
    const j = await getJson(
      `https://api.pexels.com/v1/search?query=${encodeURIComponent(q)}&per_page=${n}`,
      { Authorization: cfg.pexelsKey });
    return j.photos.map((p) => ({
      id: "px" + p.id, provider: "Pexels", title: p.alt || "Pexels photo",
      thumb: p.src.medium, full: p.src.large2x, author: p.photographer,
      license: "Pexels licence (free)", page: p.url,
    }));
  },
  async unsplash(q, n, cfg) {
    if (!cfg.unsplashKey) throw new Error("Unsplash: no key (Settings)");
    const j = await getJson(
      `https://api.unsplash.com/search/photos?query=${encodeURIComponent(q)}&per_page=${n}`,
      { Authorization: "Client-ID " + cfg.unsplashKey });
    return j.results.map((p) => ({
      id: "us" + p.id, provider: "Unsplash", title: p.alt_description || "Unsplash photo",
      thumb: p.urls.small, full: p.urls.regular, author: p.user.name,
      license: "Unsplash licence (free)", page: p.links.html,
      download: p.links.download_location,
    }));
  },
};

async function search({ query, sources, count }, cfg) {
  const results = [];
  const errors = [];
  await Promise.all(
    sources.map(async (s) => {
      try {
        if (!providers[s]) throw new Error("unknown source " + s);
        results.push(...(await providers[s](query, count, cfg)));
      } catch (e) {
        errors.push(e.message);
      }
    }));
  return { results, errors };
}

// Optional pay-per-use filter: Claude Haiku looks at each thumbnail. Cents per hundred images.
async function haikuFilter(items, criteria, cfg) {
  if (!cfg.anthropicKey) throw new Error("No Anthropic key (Settings)");
  return Promise.all(items.map(async (it) => {
    try {
      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "x-api-key": cfg.anthropicKey, "anthropic-version": "2023-06-01",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model: HAIKU_MODEL, max_tokens: 80,
          messages: [{ role: "user", content: [
            { type: "image", source: { type: "url", url: it.thumb } },
            { type: "text", text: `Does this image match: "${criteria}"? ` +
              'Reply only with JSON {"ok":true|false,"why":"<8 words>"}' },
          ] }],
        }),
      });
      const j = await r.json();
      const m = (j.content?.[0]?.text || "").match(/\{.*\}/s);
      const v = m ? JSON.parse(m[0]) : { ok: true, why: "unparsed" };
      return { ...it, ok: !!v.ok, why: v.why };
    } catch (e) {
      return { ...it, ok: true, why: "filter failed: " + e.message };
    }
  }));
}

const slug = (s) => s.toLowerCase().replace(/\.[a-z0-9]+$/, "").replace(/[^a-z0-9]+/g, "-")
  .replace(/^-|-$/g, "").slice(0, 50) || "image";

async function save({ items, folder }, cfg) {
  const sub = folder.replace(/[<>:"|?*\x00-\x1f]/g, "").replace(/^[\\/]+/, "");
  const dir = path.resolve(cfg.outputDir, sub);
  if (path.relative(cfg.outputDir, dir).startsWith("..")) throw new Error("Folder escapes output dir");
  fs.mkdirSync(dir, { recursive: true });
  const saved = [];
  for (const it of items) {
    if (it.download) {
      fetch(it.download, { headers: { Authorization: "Client-ID " + cfg.unsplashKey } })
        .catch(() => {}); // Unsplash API rule: report each download
    }
    const r = await fetch(it.full, { headers: { "User-Agent": UA } });
    if (!r.ok) throw new Error(`${it.title}: HTTP ${r.status}`);
    const ext = (r.headers.get("content-type") || "").includes("png") ? "png" : "jpg";
    const name = `${it.id}_${slug(it.title)}.${ext}`;
    fs.writeFileSync(path.join(dir, name), Buffer.from(await r.arrayBuffer()));
    fs.appendFileSync(path.join(dir, "CREDITS.txt"),
      `${name} | ${it.provider} | ${it.author} | ${it.license} | ${it.page}\n`);
    saved.push(name);
  }
  return { dir, saved };
}


// Chat: Haiku turns a natural request (Hebrew is fine) into searches and saves, by tool calls.
const known = new Map(); // id -> item, so the model can only save what a search returned
const TOOLS = [
  {
    name: "search_images",
    description: "Search free open-licence photo sources. Use English queries. Returns id, title, " +
      "licence for each result. Call several times with different queries if needed.",
    input_schema: { type: "object", properties: {
      query: { type: "string" },
      sources: { type: "array", items: { type: "string", enum: ["wikimedia", "pexels", "unsplash"] } },
      count: { type: "integer", description: "results per source, default 10, max 30" },
    }, required: ["query"] },
  },
  {
    name: "save_images",
    description: "Save images (ids from search_images) into a subfolder of the output folder.",
    input_schema: { type: "object", properties: {
      ids: { type: "array", items: { type: "string" } },
      folder: { type: "string", description: "short English subfolder name" },
    }, required: ["ids", "folder"] },
  },
];
const SYSTEM = "You are a small research assistant inside a local tool for a game studio. The user " +
  "(chatting in Hebrew) asks for reference images. Turn the request into English searches with " +
  "search_images (default source wikimedia, add others only if the user has keys or asks), pick " +
  "the results whose titles fit best, and save them with save_images when the user asked to " +
  "save or collect them. Answer briefly in Hebrew: what you searched, how many you saved and " +
  "where. Wikimedia titles are descriptive; skip diagrams, maps and logos.";

async function runTool(name, input, cfg, state) {
  if (name === "search_images") {
    const { results, errors } = await search({
      query: input.query, sources: input.sources?.length ? input.sources : ["wikimedia"],
      count: Math.min(input.count || 10, 30) }, cfg);
    results.forEach((r) => known.set(r.id, r));
    state.shown.push(...results);
    return JSON.stringify({ errors, results: results.map((r) =>
      ({ id: r.id, title: r.title.slice(0, 90), license: r.license })) });
  }
  const picks = (input.ids || []).map((id) => known.get(id)).filter(Boolean);
  const out = await save({ items: picks, folder: input.folder || "misc" }, cfg);
  state.saved.push(...out.saved);
  return JSON.stringify({ saved: out.saved.length, dir: out.dir });
}

async function chat({ messages }, cfg) {
  if (!cfg.anthropicKey) throw new Error("NO_KEY");
  const state = { shown: [], saved: [] };
  const convo = messages.map((m) => ({ role: m.role, content: m.content }));
  for (let turn = 0; turn < 8; turn++) {
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": cfg.anthropicKey, "anthropic-version": "2023-06-01",
        "content-type": "application/json" },
      body: JSON.stringify({ model: HAIKU_MODEL, max_tokens: 1000, system: SYSTEM,
        tools: TOOLS, messages: convo }),
    });
    const j = await r.json();
    if (!r.ok) throw new Error(j.error?.message || "Anthropic HTTP " + r.status);
    convo.push({ role: "assistant", content: j.content });
    const calls = j.content.filter((b) => b.type === "tool_use");
    if (!calls.length) {
      const reply = j.content.filter((b) => b.type === "text").map((b) => b.text).join("\n");
      return { reply, shown: state.shown, saved: state.saved };
    }
    const resultsBlocks = [];
    for (const c of calls) {
      let content;
      try { content = await runTool(c.name, c.input, cfg, state); }
      catch (e) { content = "Error: " + e.message; }
      resultsBlocks.push({ type: "tool_result", tool_use_id: c.id, content });
    }
    convo.push({ role: "user", content: resultsBlocks });
  }
  return { reply: "(stopped after too many steps)", shown: state.shown, saved: state.saved };
}

const readBody = (req) => new Promise((res) => {
  let b = "";
  req.on("data", (c) => (b += c));
  req.on("end", () => res(b ? JSON.parse(b) : {}));
});
const send = (res, code, obj) => {
  res.writeHead(code, { "content-type": "application/json" });
  res.end(JSON.stringify(obj));
};

http.createServer(async (req, res) => {
  const cfg = loadConfig();
  try {
    if (req.method === "GET" && (req.url === "/" || req.url === "/index.html")) {
      res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
      return res.end(fs.readFileSync(path.join(ROOT, "public", "index.html")));
    }
    if (req.method === "GET" && req.url === "/api/config") {
      return send(res, 200, {
        outputDir: cfg.outputDir, pexelsKey: mask(cfg.pexelsKey),
        unsplashKey: mask(cfg.unsplashKey), anthropicKey: mask(cfg.anthropicKey),
      });
    }
    if (req.method === "POST" && req.url === "/api/config") {
      const b = await readBody(req);
      const next = { ...cfg };
      if (b.outputDir) next.outputDir = b.outputDir;
      for (const k of ["pexelsKey", "unsplashKey", "anthropicKey"]) {
        if (typeof b[k] === "string" && b[k] && !b[k].startsWith("••••")) next[k] = b[k].trim();
      }
      saveConfig(next);
      return send(res, 200, { ok: true });
    }
    if (req.method === "POST" && req.url === "/api/search") {
      return send(res, 200, await search(await readBody(req), cfg));
    }
    if (req.method === "POST" && req.url === "/api/chat") {
      return send(res, 200, await chat(await readBody(req), cfg));
    }
    if (req.method === "POST" && req.url === "/api/filter") {
      const b = await readBody(req);
      return send(res, 200, { items: await haikuFilter(b.items, b.criteria, cfg) });
    }
    if (req.method === "POST" && req.url === "/api/save") {
      return send(res, 200, await save(await readBody(req), cfg));
    }
    send(res, 404, { error: "not found" });
  } catch (e) {
    send(res, 500, { error: e.message });
  }
}).listen(PORT, "127.0.0.1", () => console.log(`Researcher running: http://localhost:${PORT}`));
