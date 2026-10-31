// Local map checker: builds hundreds of Map Lab maps in a hidden Edge or Chrome window, runs the
// planning checks and the traffic test on each, and compares them with real cities
// (targets.json). Uses no tokens. Stops and starts again where it left off: every map's result is
// kept in results.jsonl as soon as it is done.
//
//   node run-check.js [seeds per setting] [pages at once]
//
// At the end it writes SUMMARY_map_check.md (for people) and summary.json (for Claude).
"use strict";
const fs = require("fs");
const path = require("path");
const os = require("os");

const HERE = __dirname;
const SEEDS = Math.max(1, parseInt(process.argv[2] || process.env.MAP_SEEDS || "100", 10));
const PAGES = Math.max(1, parseInt(process.argv[3] || process.env.MAP_PAGES || String(Math.min(2, Math.max(1, Math.floor(os.cpus().length / 4)))), 10));
// Town, part of a city and metropolis, from one neighbourhood to a big city.
const SETTINGS = [
  ["city", 1.6], ["city", 0.9], ["city", 2.4], ["city", 3.2],
  ["town", 0.9], ["town", 1.6], ["town", 3.2],
  ["metro", 1.6], ["metro", 3.2],
];
const RESULTS = path.join(HERE, "results.jsonl");
const LOG = path.join(HERE, "map_check_log.txt");
const MAP_TIMEOUT_MS = 180000;
const RELOAD_EVERY = 40; // a fresh page now and then, so memory does not pile up

// Defects: each should be 0 on every map. Measures: compared with real cities.
const DEFECTS = [
  ["cutOff", "Buildings a car cannot reach or leave"],
  ["walkIslands", "Buildings no one can walk to"],
  ["failedTrips", "Share of random car trips with no way"],
  ["bldOnRoad", "Buildings on a road"],
  ["bldInWater", "Buildings in water"],
  ["bldOverlap", "Buildings overlapping"],
  ["roadOnWater", "Roads on water (not bridges)"],
  ["bridgesTooLong", "Bridges too long"],
  ["deadEndMain", "Main roads ending in nothing"],
  ["roundaboutBlocked", "Roundabouts blocked"],
];
const WATCH = [
  ["tightBends", "Tight bends"], ["shallowMerges", "Shallow merges"], ["sharpJunctions", "Sharp junctions"],
  ["staggeredT", "Staggered T junctions"], ["hugeBuiltBlocks", "Huge built blocks"], ["idleStreetsLeft", "Streets serving nothing"],
  ["longDetours", "Car trips over 4x the straight line"],
];
// [result key, title, targets path, how to read the real range]
const MEASURES = [
  ["m_kmStreetsPerKm2", "Street km per km2", "street_km_per_km2"],
  ["m_junctionsPerKm2", "Junctions per km2", "junctions_per_km2"],
  ["m_deadEndShare", "Dead-end share", "dead_end_share"],
  ["m_meanBlockM2", "Block area m2 (mean; real is median)", "block_area_median_m2"],
  ["m_driveDetourMedian", "Car detour, median", "drive_detour_median", "flow"],
  ["m_driveDetourP90", "Car detour, 90th percentile", "drive_detour_p90", "flow"],
  ["m_walkDetourMedian", "Walk detour, median", "walk_detour_median", "flow"],
  ["m_walkDetourP90", "Walk detour, 90th percentile", "walk_detour_p90", "flow"],
  ["m_driveTop5TripKmShare", "Car trip-km on busiest 5% of streets", "drive_top5_tripkm_share", "flow"],
  ["m_floorsMedian", "Floors, median", "levels_median", "rings"],
  ["m_homesNoSchool", "Homes with no school near", null],
  ["m_homesNoShop400", "Homes with no shop in 400 m", null],
  ["m_homesNoClinic", "Homes with no clinic near", null],
  ["m_homesNoPark", "Homes with no park near", null],
];

function log(line) {
  const text = `[${new Date().toISOString().replace("T", " ").slice(0, 19)}] ${line}`;
  console.log(text);
  fs.appendFileSync(LOG, text + "\n");
}

// The real range of one measure over every neighbourhood type (or ring) in targets.json.
function realRange(targets, key, where) {
  const lows = [], highs = [], mids = [];
  const take = m => { if (m && typeof m.min === "number") { lows.push(m.min); highs.push(m.max); mids.push(m.median); } };
  if (where === "flow") for (const t of Object.values(targets.neighbourhood_types_flow || {})) take(t[key]);
  else if (where === "rings") for (const r of targets.rings || []) take(r.metrics && r.metrics[key]);
  else for (const t of Object.values(targets.neighbourhood_types || {})) take(t.metrics && t.metrics[key]);
  if (!lows.length) return null;
  mids.sort((a, b) => a - b);
  return { min: Math.min(...lows), max: Math.max(...highs), median: mids[Math.floor(mids.length / 2)] };
}

function readDone() {
  const done = new Map();
  if (!fs.existsSync(RESULTS)) return done;
  for (const line of fs.readFileSync(RESULTS, "utf8").split("\n")) {
    if (!line.trim()) continue;
    try { const r = JSON.parse(line); done.set(r.key, r); } catch { /* a line cut short by a stop */ }
  }
  return done;
}

async function launch() {
  let pw;
  for (const name of ["playwright-core", "playwright"]) { try { pw = require(name); break; } catch { /* try the next */ } }
  if (!pw) throw new Error("playwright-core is missing: run run_map_check.cmd, which installs it.");
  for (const channel of ["msedge", "chrome", undefined]) {
    try { return await pw.chromium.launch({ channel, headless: true }); } catch { /* try the next browser */ }
  }
  throw new Error("Neither Microsoft Edge nor Google Chrome could be started.");
}

async function openPage(browser) {
  const page = await browser.newPage({ viewport: { width: 1200, height: 800 } });
  page.on("pageerror", e => log("page error: " + e.message));
  await page.goto(require("url").pathToFileURL(path.join(HERE, "map-lab.html")).href);
  await page.waitForFunction(() => typeof map !== "undefined" && map && document.getElementById("busy").hidden, null, { timeout: 120000 });
  await page.addScriptTag({ path: path.join(HERE, "checks-in-page.js") });
  await page.addScriptTag({ path: path.join(HERE, "probe-in-page.js") });
  return page;
}

function withTimeout(promise, ms) {
  let timer;
  return Promise.race([promise, new Promise((_, reject) => { timer = setTimeout(() => reject(new Error("timed out")), ms); })])
    .finally(() => clearTimeout(timer));
}

async function worker(browser, queue, total, counter) {
  let page = await openPage(browser), built = 0;
  while (queue.length) {
    const job = queue.shift();
    if (built && built % RELOAD_EVERY === 0) { await page.close().catch(() => {}); page = await openPage(browser); }
    let row;
    try {
      row = await withTimeout(page.evaluate(([s, c, z]) => probeMap(s, c, z), [job.seed, job.context, job.size]), MAP_TIMEOUT_MS);
    } catch (e) {
      row = { seed: job.seed, context: job.context, size: job.size, error: String(e.message || e).slice(0, 300) };
      log(`map ${job.key} failed: ${row.error}`);
      await page.close().catch(() => {});
      page = await openPage(browser);
    }
    row.key = job.key;
    fs.appendFileSync(RESULTS, JSON.stringify(row) + "\n");
    built++; counter.n++;
    if (counter.n % 10 === 0 || !queue.length) log(`${counter.n} of ${total} maps done`);
  }
  await page.close().catch(() => {});
}

function stats(values) {
  const v = values.filter(x => typeof x === "number" && isFinite(x)).sort((a, b) => a - b);
  if (!v.length) return null;
  const at = f => v[Math.min(v.length - 1, Math.floor(v.length * f))];
  return { mean: v.reduce((a, b) => a + b, 0) / v.length, median: at(0.5), p90: at(0.9), max: v[v.length - 1], n: v.length };
}
const fmt = x => (x === null || x === undefined ? "-" : Math.abs(x) >= 100 ? String(Math.round(x)) : Math.abs(x) >= 10 ? x.toFixed(1) : x.toFixed(2));

function summarise(rows, targets) {
  const out = { written: new Date().toISOString(), seedsPerSetting: SEEDS, maps: rows.length, settings: [] };
  const md = [];
  md.push("# Map check summary", "");
  md.push(`Written ${out.written.slice(0, 16).replace("T", " ")} UTC. ${rows.length} maps, ${SEEDS} seeds for each of ${SETTINGS.length} settings.`, "");
  const errors = rows.filter(r => r.error);
  if (errors.length) md.push(`**${errors.length} maps failed to build or check** (see map_check_log.txt).`, "");
  for (const [context, size] of SETTINGS) {
    const set = rows.filter(r => r.context === context && r.size === size && !r.error);
    if (!set.length) continue;
    const s = { context, size, maps: set.length, defects: {}, watch: {}, measures: {} };
    md.push(`## ${context}, ${size} km across (${set.length} maps)`, "");
    md.push("| Defect | Maps with any | Mean | Worst | Worst seeds |", "| --- | --- | --- | --- | --- |");
    for (const [key, title] of DEFECTS) {
      const bad = set.filter(r => (r[key] || 0) > 0), st = stats(set.map(r => r[key] || 0));
      const worst = [...bad].sort((a, b) => b[key] - a[key]).slice(0, 5).map(r => r.seed);
      s.defects[key] = { mapsWithAny: bad.length, mean: st.mean, max: st.max, worstSeeds: worst };
      md.push(`| ${title} | ${bad.length} | ${fmt(st.mean)} | ${fmt(st.max)} | ${worst.join(", ")} |`);
    }
    md.push("", "| Worth watching | Mean | Worst |", "| --- | --- | --- |");
    for (const [key, title] of WATCH) {
      const st = stats(set.map(r => r[key] || 0)); s.watch[key] = st;
      md.push(`| ${title} | ${fmt(st.mean)} | ${fmt(st.max)} |`);
    }
    md.push("", "| Measure | Our median | Our range (10-90%) | Real cities (min, median, max) | In range |", "| --- | --- | --- | --- | --- |");
    for (const [key, title, tkey, where] of MEASURES) {
      const st = stats(set.map(r => r[key])); if (!st) continue;
      const lo = stats(set.map(r => r[key])), v = set.map(r => r[key]).filter(x => typeof x === "number").sort((a, b) => a - b);
      const p10 = v[Math.floor(v.length * 0.1)];
      const real = tkey ? realRange(targets, tkey, where) : null;
      const verdict = !real ? "" : st.median < real.min ? "LOW" : st.median > real.max ? "HIGH" : "yes";
      s.measures[key] = { ours: { median: st.median, p10, p90: lo.p90 }, real, verdict };
      md.push(`| ${title} | ${fmt(st.median)} | ${fmt(p10)} to ${fmt(lo.p90)} | ${real ? `${fmt(real.min)}, ${fmt(real.median)}, ${fmt(real.max)}` : "-"} | ${verdict} |`);
    }
    const ms = stats(set.map(r => r.ms));
    md.push("", `About ${(ms.mean / 1000).toFixed(1)} s per map.`, "");
    out.settings.push(s);
  }
  fs.writeFileSync(path.join(HERE, "summary.json"), JSON.stringify(out, null, 1));
  fs.writeFileSync(path.join(HERE, "SUMMARY_map_check.md"), md.join("\n") + "\n");
}

async function main() {
  const targets = JSON.parse(fs.readFileSync(path.join(HERE, "targets.json"), "utf8"));
  const done = readDone();
  const queue = [];
  for (let seed = 1; seed <= SEEDS; seed++) for (const [context, size] of SETTINGS) {
    const key = `${context}-${size}-${seed}`;
    if (!done.has(key)) queue.push({ key, seed, context, size });
  }
  const total = done.size + queue.length;
  log(`Starting: ${done.size} maps already done, ${queue.length} to go, ${PAGES} at once.`);
  if (queue.length) {
    const browser = await launch();
    const counter = { n: done.size };
    await Promise.all(Array.from({ length: PAGES }, () => worker(browser, queue, total, counter)));
    await browser.close();
  }
  const rows = [...readDone().values()];
  summarise(rows, targets);
  log(`Done. Summary in SUMMARY_map_check.md and summary.json (${rows.length} maps).`);
}

main().catch(e => { log("Stopped: " + (e.stack || e)); process.exitCode = 1; });
