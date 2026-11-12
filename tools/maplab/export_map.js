#!/usr/bin/env node
// Makes a stage's map file for the game from the Map Lab generator.
//   node tools/maplab/export_map.js data/maps/slums/stage.json
// The stage file names the Map Lab settings (a map code from the page, and/or settings), the game scale, which game
// district kind each Map Lab archetype becomes, and the style file of each kind
// (data/maps/styles/<kind>.json), which can change that kind's streets, land use and buildings.
// It writes the map next to the stage file (stage.json -> map.json) and prints the numbers the
// Balance Tester checks: units in the start district and how many units from its core the far edge is.
"use strict";
const fs = require("fs");
const path = require("path");
const gen = require("./generator.js");

const stagePath = process.argv[2];
if (!stagePath) { console.error("usage: export_map.js <stage.json>"); process.exit(1); }
const stage = JSON.parse(fs.readFileSync(stagePath, "utf8"));
const root = path.resolve(path.dirname(stagePath), stage.root || "../..");
const S = stage.scale;

// ---------- Style files: a game district kind's own streets, land use and buildings ----------
const kindOf = id => stage.kinds[id] || "";
const facades = {};
for (const [archetype, kind] of Object.entries(stage.kinds)) {
  const file = path.join(root, "maps", "styles", kind.toLowerCase().replace(/[^a-z]+/g, "_") + ".json");
  if (!fs.existsSync(file)) continue;
  const style = JSON.parse(fs.readFileSync(file, "utf8"));
  if (style.street_style || style.land_use) {
    const [st, mix] = gen.MIXES[archetype];
    gen.MIXES[archetype] = [style.street_style || st, style.land_use || mix];
  }
  if (style.buildings) Object.assign(gen.NEIGHBOURHOOD[archetype], style.buildings);
  if (style.rise !== undefined) gen.RISE[archetype] = style.rise;
  if (style.peak !== undefined) gen.PEAKS[archetype] = style.peak;
  facades[archetype] = style.facades || {};
}

// A map code copied from the Map Lab page (Save and share) holds its settings and the player's
// changes (roundabouts, block uses); "params" in the stage file go on top of it.
let fromCode = {}, edits = undefined;
if (stage.code) {
  const body = /^ML\d+:([A-Za-z0-9_-]+)$/.exec(stage.code.trim());
  if (!body) { console.error("not a Map Lab code: " + stage.code); process.exit(1); }
  const state = JSON.parse(Buffer.from(body[1].replace(/-/g, "+").replace(/_/g, "/"), "base64").toString("utf8"));
  fromCode = state.p || {};
  if (state.e) edits = { roundabouts: state.e.roundabouts || [], blocks: state.e.blocks || [] };
}
const params = { ...gen.DEFAULTS, ...fromCode, ...stage.params };
const m = gen.buildMap(params, edits);
const r2 = v => Math.round(v * S * 100) / 100;
const xz = p => [r2(p[0]), r2(p[1])];

// ---------- Roads ----------
const roads = [];
m.lines.forEach(l => {
  const t = gen.ROADS[l.type];
  if (!t || !t.lanes || l.pts.length < 2) return;
  roads.push({ pts: l.pts.flatMap(xz), tier: l.tier, width: r2(t.total), road: r2(t.road), walk: r2(t.walk),
    oneway: !!t.oneWay && !l.twoWay, fast: l.tier === "expressway" || l.tier === "ramp" });
});

// ---------- The walking graph: junctions, plus points along every street ----------
const STEP = stage.walk_step || 20;
const nodes = [], edges = [], junction = new Map();
const addNode = (x, y) => { nodes.push(r2(x), r2(y)); return nodes.length / 2 - 1; };
m.graph.nodes.forEach((n, i) => junction.set(i, addNode(n.x, n.y)));
m.lines.forEach((l, li) => {
  if (l.tier === "expressway" || l.tier === "ramp" || l.pts.length < 2) return;
  const cum = m.graph.cums[li], len = cum[cum.length - 1];
  const stops = m.graph.lineNodes[li].map(v => ({ s: v.s, id: junction.get(v.node) }));
  if (!stops.length || stops[0].s > 1) stops.unshift({ s: 0, id: -1 });
  if (stops[stops.length - 1].s < len - 1) stops.push({ s: len, id: -1 });
  const at = s => { let i = 1; while (i < cum.length - 1 && cum[i] < s) i++;
    const a = l.pts[i - 1], b = l.pts[i], t = (s - cum[i - 1]) / Math.max(1e-6, cum[i] - cum[i - 1]);
    return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]; };
  let prev = -1;
  for (let k = 0; k < stops.length; k++) {
    const stop = stops[k];
    const id = stop.id >= 0 ? stop.id : addNode(...at(stop.s));
    if (prev >= 0) {
      const from = stops[k - 1].s, n = Math.max(1, Math.round((stop.s - from) / STEP));
      let last = prev;
      for (let j = 1; j < n; j++) { const mid = addNode(...at(from + (stop.s - from) * j / n)); edges.push(last, mid); last = mid; }
      if (last !== id) edges.push(last, id);
    }
    prev = id;
  }
});

// ---------- Districts ----------
const D = m.districts;
const districts = D.list.map((d, i) => ({ archetype: d.archetype.id, kind: kindOf(d.archetype.id), title: d.archetype.title,
  name: (stage.names || [])[i] || d.archetype.title, centre: xz([d.x, d.y]), start: i === D.start }));
const raster = (cell, value) => {
  const W = Math.ceil(gen.FIELD.w / cell), H = Math.ceil(gen.FIELD.h / cell), bytes = Buffer.alloc(W * H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++)
    bytes[y * W + x] = value(-gen.FIELD.w / 2 + (x + 0.5) * cell, -gen.FIELD.h / 2 + (y + 0.5) * cell);
  return { cell: r2(cell), w: W, h: H, data: bytes.toString("base64") };
};
const districtCells = raster(stage.district_cell || 8, (x, y) => { const d = D.at(x, y); return d >= 0 ? d : 255; });
// Ground: 0 street or verge, 1 + land use for a block, 250 water.
const g = m.grid;
const ground = raster(stage.ground_cell || 4, (x, y) => {
  const cx = Math.min(g.W - 1, Math.max(0, Math.floor((x - g.ox) / g.cell))), cy = Math.min(g.H - 1, Math.max(0, Math.floor((y - g.oy) / g.cell)));
  const label = g.labels[cy * g.W + cx];
  if (label >= 0) return m.uses[label] >= 0 ? m.uses[label] + 1 : 0;
  return label === -4 ? 250 : 0;
});

// ---------- Buildings ----------
const blockOf = (x, y) => { const cx = Math.floor((x - g.ox) / g.cell), cy = Math.floor((y - g.oy) / g.cell);
  return cx >= 0 && cy >= 0 && cx < g.W && cy < g.H ? g.labels[cy * g.W + cx] : -1; };
const PUBLIC = 3;
// A building on a district's bounding road can fall just outside every district: the nearest one takes it.
const districtNear = (x, y) => { const d = D.at(x, y); if (d >= 0) return d;
  let best = 0, bd = Infinity; D.list.forEach((o, i) => { const e = Math.hypot(o.x - x, o.y - y); if (e < bd) { bd = e; best = i; } }); return best; };
const buildings = m.buildings.map(b => {
  const q = b.poly, k = gen.KINDS[b.kind], cx = (q[0][0] + q[2][0]) / 2, cy = (q[0][1] + q[2][1]) / 2;
  const w = Math.hypot(q[1][0] - q[0][0], q[1][1] - q[0][1]), d = Math.hypot(q[3][0] - q[0][0], q[3][1] - q[0][1]);
  const district = districtNear(cx, cy), archetype = district >= 0 ? D.list[district].archetype.id : "";
  // The game turns a building so its local -z faces the street: the angle is that of the street
  // side, turned half round when the lot's corners run the other way.
  const ex = [q[1][0] - q[0][0], q[1][1] - q[0][1]], ey = [q[3][0] - q[0][0], q[3][1] - q[0][1]];
  const angle = Math.atan2(ex[1], ex[0]) + (ex[0] * ey[1] - ex[1] * ey[0] < 0 ? Math.PI : 0);
  return { c: xz([cx, cy]), size: [r2(w), r2(d)], angle: Math.round(angle * 1e4) / 1e4,
    floors: gen.floorsOf(b, m, params), storey: k.storey || 3.2, kind: b.kind, use: b.use, district, wall: !!b.wall,
    facade: (facades[archetype] || {})[b.kind] || "", block: blockOf(cx, cy), _x: cx, _y: cy, _poly: q };
});

// ---------- Units: what the player takes, a block or a run of it (the Designer's rule) ----------
const MAX = stage.unit_max || 12;
const units = [], unitOf = new Int32Array(buildings.length).fill(-1);
// Each district's core is its own unit: the public building nearest the district's middle.
D.list.forEach((d, di) => {
  let best = -1, bd = Infinity;
  buildings.forEach((b, i) => { if (b.district !== di) return; const dist = Math.hypot(b._x - d.x, b._y - d.y) * (b.use === PUBLIC ? 1 : 3);
    if (dist < bd) { bd = dist; best = i; } });
  if (best >= 0) { unitOf[best] = units.length; units.push({ district: di, core: true, buildings: [best] }); }
});
const byBlock = new Map();
buildings.forEach((b, i) => { if (unitOf[i] >= 0) return; const key = b.district + ":" + b.block; if (!byBlock.has(key)) byBlock.set(key, []); byBlock.get(key).push(i); });
for (const list of byBlock.values()) {
  const di = buildings[list[0]].district;
  const mx = list.reduce((a, i) => a + buildings[i]._x, 0) / list.length, my = list.reduce((a, i) => a + buildings[i]._y, 0) / list.length;
  list.sort((a, b) => Math.atan2(buildings[a]._y - my, buildings[a]._x - mx) - Math.atan2(buildings[b]._y - my, buildings[b]._x - mx));
  const parts = Math.ceil(list.length / MAX), per = list.length / parts;
  for (let p = 0; p < parts; p++) {
    const part = list.slice(Math.round(p * per), Math.round((p + 1) * per));
    part.forEach(i => { unitOf[i] = units.length; });
    units.push({ district: di, core: false, buildings: part });
  }
}
// Neighbours: buildings closer than the gap (across a street counts) make their units neighbours.
const GAP = stage.unit_gap || 60, MIN = stage.unit_min || 5;
const near = (p, q) => { let best = Infinity; for (const a of p) for (const b of q) best = Math.min(best, Math.hypot(a[0] - b[0], a[1] - b[1])); return best; };
const pairs = [];
for (let i = 0; i < buildings.length; i++) for (let j = i + 1; j < buildings.length; j++) {
  const a = buildings[i], b = buildings[j];
  if (Math.hypot(a._x - b._x, a._y - b._y) <= GAP + 120 && near(a._poly, b._poly) < GAP) pairs.push(i, j);
}
const linkUnits = () => {
  const next = units.map(() => new Set());
  for (let k = 0; k < pairs.length; k += 2) { const ua = unitOf[pairs[k]], ub = unitOf[pairs[k + 1]]; if (ua !== ub) { next[ua].add(ub); next[ub].add(ua); } }
  return next;
};
// A unit of only a few buildings joins its smallest neighbour in the district, if they fit together.
const middle = u => { const l = u.buildings; return [l.reduce((a, i) => a + buildings[i]._x, 0) / l.length, l.reduce((a, i) => a + buildings[i]._y, 0) / l.length]; };
for (let merged = true; merged;) {
  merged = false;
  const next = linkUnits();
  for (let i = 0; i < units.length; i++) {
    const u = units[i];
    if (u.core || !u.buildings.length || u.buildings.length >= MIN) continue;
    const [x, y] = middle(u);
    let best = -1, score = Infinity;
    for (const v of next[i]) {
      const o = units[v];
      if (o.core || o.district !== u.district || !o.buildings.length || o.buildings.length + u.buildings.length > MAX) continue;
      const [ox, oy] = middle(o), sc = o.buildings.length * 1000 + Math.hypot(ox - x, oy - y);
      if (sc < score) { score = sc; best = v; }
    }
    if (best < 0) continue;
    for (const b of u.buildings) unitOf[b] = best;
    units[best].buildings.push(...u.buildings);
    u.buildings = [];
    merged = true;
    break;
  }
}
// Drop the emptied units and number the rest again.
const renumber = new Int32Array(units.length).fill(-1);
const kept = units.filter(u => u.buildings.length);
units.forEach((u, i) => { renumber[i] = kept.indexOf(u); });
for (let i = 0; i < unitOf.length; i++) unitOf[i] = renumber[unitOf[i]];
units.length = 0; units.push(...kept);
const finalNext = linkUnits();
units.forEach((u, i) => { u.buildings.sort((a, b) => a - b); u.next = [...finalNext[i]].sort((a, b) => a - b); });

// ---------- Trees ----------
const trees = [];
for (const t of m.trees) trees.push(r2(t[0]), r2(t[1]), r2(t[2]));
for (const t of m.kerbTrees) trees.push(r2(t[0]), r2(t[1]), r2(t[2]));

for (const b of buildings) { b.unit = unitOf[buildings.indexOf(b)]; delete b._x; delete b._y; delete b._poly; delete b.block; }
const out = { version: 1, made_from: params, scale: S, size: [r2(gen.FIELD.w), r2(gen.FIELD.h)], roads, nodes, edges,
  districts, district_cells: districtCells, ground, buildings, units, trees };
const outPath = path.join(path.dirname(stagePath), "map.json");
fs.writeFileSync(outPath, JSON.stringify(out));

// ---------- The numbers to check ----------
const start = D.start, mine = units.map((u, i) => i).filter(i => units[i].district === start);
const core = mine.find(i => units[i].core);
const steps = new Map([[core, 0]]), queue = [core];
while (queue.length) { const u = queue.shift(); for (const v of units[u].next) if (!steps.has(v) && units[v].district === start) { steps.set(v, steps.get(u) + 1); queue.push(v); } }
const far = Math.max(...mine.map(i => steps.get(i) ?? -1));
const kinds = {};
for (const b of buildings) if (b.district === start) kinds[b.kind] = (kinds[b.kind] || 0) + 1;
console.log(`${outPath}: ${(fs.statSync(outPath).size / 1024).toFixed(0)} KB, ${buildings.length} buildings, ${units.length} units, ${roads.length} roads, ${nodes.length / 2} walk nodes`);
console.log(`start district ${districts[start].kind || districts[start].archetype}: ${mine.length} units, ${mine.reduce((a, i) => a + units[i].buildings.length, 0)} buildings, farthest unit ${far} steps from the core, ${mine.filter(i => !steps.has(i)).length} units cut off`);
console.log("buildings:", JSON.stringify(kinds));
