// Local researcher: searches free open-licence image sources and saves picks into a folder
// (e.g. one synced by Google Drive). Zero dependencies; needs Node 18+.
const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = 5177;
const ROOT = __dirname;
const CONFIG_FILE = path.join(ROOT, "config.json");
const UA = "SpinCycleResearcher/1.0 (local tool)";
const DEFAULTS = {
  outputDir: path.join(ROOT, "downloads"),
  pexelsKey: "",
  unsplashKey: "",
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

const slug = (s) => s.toLowerCase().replace(/\.[a-z0-9]+$/, "").replace(/[^a-z0-9]+/g, "-")
  .replace(/^-|-$/g, "").slice(0, 50) || "image";

async function save({ items, folder }, cfg) {
  const sub = folder.replace(/[<>:"|?*\x00-\x1f]/g, "").replace(/^[\\/]+/, "");
  const dir = path.resolve(cfg.outputDir, sub);
  if (path.relative(cfg.outputDir, dir).startsWith("..")) throw new Error("Folder escapes output dir");
  fs.mkdirSync(dir, { recursive: true });
  const saved = [];
  const failed = [];
  for (const it of items) {
    try {
      if (it.download) {
        fetch(it.download, { headers: { Authorization: "Client-ID " + cfg.unsplashKey } })
          .catch(() => {}); // Unsplash API rule: report each download
      }
      let r;
      for (let attempt = 0; attempt < 4; attempt++) {
        r = await fetch(it.full, { headers: { "User-Agent": UA } });
        if (r.status !== 429 && r.status < 500) break;
        await new Promise((ok) => setTimeout(ok, 1500 * (attempt + 1))); // rate limited: back off
      }
      if (!r.ok) throw new Error("HTTP " + r.status);
      const ext = (r.headers.get("content-type") || "").includes("png") ? "png" : "jpg";
      const name = `${it.id}_${slug(it.title)}.${ext}`;
      fs.writeFileSync(path.join(dir, name), Buffer.from(await r.arrayBuffer()));
      fs.appendFileSync(path.join(dir, "CREDITS.txt"),
        `${name} | ${it.provider} | ${it.author} | ${it.license} | ${it.page}\n`);
      saved.push(name);
    } catch (e) {
      failed.push(`${it.title.slice(0, 40)}: ${e.message}`);
    }
  }
  return { dir, saved, failed };
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
        outputDir: cfg.outputDir, pexelsKey: mask(cfg.pexelsKey), unsplashKey: mask(cfg.unsplashKey),
      });
    }
    if (req.method === "POST" && req.url === "/api/config") {
      const b = await readBody(req);
      const next = { ...cfg };
      if (b.outputDir) next.outputDir = b.outputDir;
      for (const k of ["pexelsKey", "unsplashKey"]) {
        if (typeof b[k] === "string" && b[k] && !b[k].startsWith("••••")) next[k] = b[k].trim();
      }
      saveConfig(next);
      return send(res, 200, { ok: true });
    }
    if (req.method === "POST" && req.url === "/api/search") {
      return send(res, 200, await search(await readBody(req), cfg));
    }
    if (req.method === "POST" && req.url === "/api/save") {
      return send(res, 200, await save(await readBody(req), cfg));
    }
    send(res, 404, { error: "not found" });
  } catch (e) {
    send(res, 500, { error: e.message });
  }
}).listen(PORT, "127.0.0.1", () => console.log(`Researcher running: http://localhost:${PORT}`));
