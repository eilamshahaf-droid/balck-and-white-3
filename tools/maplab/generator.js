// The Map Lab's city generator, taken from the browser Map Lab page (the plan view, menu,
// traffic test and 3D view are left out). export_map.js runs it and writes a stage file.
"use strict";
// All distances are real metres. The game shrinks them by 0.3 for its toy town.

// ---------- Data (from data/mapgen.tres and data/map_lab.tres) ----------
const ARCHETYPES = [
  ["forgotten", "Forgotten edge", [1, 0.2, 0]],
  ["immigrant", "Immigrant flats", [0.8, 0.6, 0.1]],
  ["public_housing", "Public housing towers", [0.7, 0.5, 0.1]],
  ["industrial", "Industrial yards", [1.0, 0.3, 0]],
  ["workers", "Workers' quarter", [0.8, 0.8, 0.2]],
  ["gentrifying", "Gentrifying front", [0.2, 1.0, 0.3]],
  ["university", "University quarter", [0.1, 1.0, 0.2]],
  ["nightlife", "Nightlife strip", [0.1, 0.8, 0.5]],
  ["financial", "Financial district", [0.0, 0.3, 1.0]],
  ["luxury", "Luxury enclave", [0.1, 0.5, 0.9]],
  ["civic", "Civic centre", [0.0, 0.1, 1.0]],
].map(([id, title, ring]) => ({ id, title, ring }));
// sep: street spacing against the slider when each district has its own style; cross: spacing of
// a second set of side streets across the first, 0 for none (old towns have both, grids leave the
// cross direction to the avenues; old cores reach 120 to 166 junctions per km2); dead: share of
// streets left as dead ends. Both from OpenStreetMap samples (Manhattan and Barcelona grids,
// Paris, Amsterdam and Tel Aviv cores, London terraces, Plano and Marzahn).
const STYLES = [
  { id: "planned_grid", title: "Planned grid", examples: "Chicago, Manhattan", grid: 1, radial: 0, reach: 600, wobble: 0.05, minor: 80, major: 200, dead: 0.03, sep: 1, cross: 0 },
  { id: "grid_sprawl", title: "Wide grid sprawl", examples: "Houston, Beijing", grid: 1, radial: 0, reach: 350, wobble: 0.15, minor: 120, major: 300, dead: 0.12, sep: 1.15, cross: 0 },
  { id: "compact_organic", title: "Compact organic", examples: "Paris, Tokyo", grid: 3, radial: 1, reach: 250, wobble: 0.4, minor: 70, major: 170, dead: 0.05, sep: 0.95, cross: 1.8 },
  { id: "winding_old", title: "Winding old town", examples: "London, Rome", grid: 3, radial: 3, reach: 200, wobble: 0.7, minor: 70, major: 150, dead: 0.12, sep: 0.9, cross: 1.7 },
];
// archetype -> street style, weights for homes, offices, industry, public, parks
const MIXES = {
  forgotten: ["winding_old", [0.6, 0.1, 0.2, 0.05, 0.05]],
  immigrant: ["compact_organic", [0.7, 0.2, 0.03, 0.05, 0.02]],
  public_housing: ["grid_sprawl", [0.75, 0.05, 0, 0.1, 0.1]],
  industrial: ["grid_sprawl", [0.1, 0.1, 0.75, 0.02, 0.03]],
  workers: ["compact_organic", [0.65, 0.1, 0.15, 0.05, 0.05]],
  gentrifying: ["compact_organic", [0.6, 0.25, 0.05, 0.05, 0.05]],
  university: ["compact_organic", [0.35, 0.15, 0, 0.4, 0.1]],
  nightlife: ["winding_old", [0.35, 0.55, 0, 0.05, 0.05]],
  financial: ["planned_grid", [0.1, 0.8, 0, 0.07, 0.03]],
  luxury: ["planned_grid", [0.7, 0.15, 0, 0.05, 0.1]],
  civic: ["planned_grid", [0.15, 0.3, 0, 0.45, 0.1]],
};
// name, block ground, building colour
const USES = [
  ["Homes", "#f4e7c8", "#e3bf6f"], ["Offices", "#dde5f3", "#7fa2e0"], ["Industry", "#e7dfec", "#a991c0"],
  ["Campus and civic centre", "#f3d9d6", "#d97b74"], ["Parks", "#c9e5b9", "#7fbf6a"], ["Squares", "#ebe5d6", "#ebe5d6"],
  ["Countryside", "#dfe8b6", "#dfe8b6"],
];
const HOMES = 0, OFFICES = 1, INDUSTRY = 2, PUBLIC = 3, PARK = 4, SQUARE = 5, FARM = 6, PAVEMENT = -1;
// Building kinds: frontage w, depth d, setback from the property line, gap to the next one (m);
// tall 0 low, 1 mid-rise, 2 high-rise (a longer shadow); floors in 3D (storey m, 3.2 if unset);
// colour; lawn: green kept round it (m).
// Public kinds are neighbourhood services: one within reach (m) of every home, as planners
// site schools, clinics and stations by catchment.
const KINDS = {
  suburban: { title: "Suburban house", group: "Homes", w: [9, 13], d: [9, 12], set: [5, 8], gap: [5, 9], tall: 0, floors: [1, 2], colour: "#f2d68e" },
  villa: { title: "Villa", group: "Homes", w: [16, 24], d: [14, 20], set: [9, 14], gap: [10, 16], tall: 0, floors: [2, 3], colour: "#ecc66a", lawn: 4 },
  row: { title: "Townhouses", group: "Homes", w: [12, 22], d: [14, 20], set: [0, 1], gap: [0, 0.5], tall: 0, floors: [2, 4], colour: "#e5b85e" },
  walkup: { title: "Walk-up flats, 4 to 6 floors", group: "Homes", w: [16, 26], d: [14, 18], set: [0, 2], gap: [0, 2], tall: 1, floors: [4, 6], colour: "#dba24c" },
  slab: { title: "Housing slab", group: "Homes", w: [36, 70], d: [11, 15], set: [4, 8], gap: [8, 14], tall: 1, floors: [6, 12], colour: "#c98e3e" },
  tower: { title: "Housing tower", group: "Homes", w: [20, 30], d: [20, 30], set: [6, 12], gap: [14, 24], tall: 2, floors: [12, 24], colour: "#b5773a" },
  luxury: { title: "Luxury tower", group: "Homes", w: [24, 34], d: [24, 34], set: [10, 16], gap: [18, 28], tall: 2, floors: [18, 40], colour: "#d2ad3c", lawn: 6 },
  mixed: { title: "Shops below, flats above", group: "Shops", w: [14, 24], d: [14, 20], set: [0, 0.5], gap: [0, 1], tall: 1, floors: [4, 7], colour: "#dba24c", base: "#ee7b4f" },
  corner: { title: "Corner shop", group: "Shops", w: [8, 12], d: [10, 14], set: [0, 1], gap: [0, 1], tall: 0, floors: [1, 2], colour: "#ee7b4f" },
  market: { title: "Supermarket", group: "Shops", w: [34, 46], d: [26, 34], set: [12, 18], gap: [6, 10], tall: 0, floors: [1, 1], storey: 7, colour: "#e0602f", reach: 650, main: true },
  strip: { title: "Shopping strip with parking", group: "Shops", w: [40, 60], d: [14, 18], set: [16, 22], gap: [6, 10], tall: 0, floors: [1, 1], storey: 6, colour: "#e0602f", reach: 1100, main: true },
  office: { title: "Offices", group: "Work", w: [18, 42], d: [16, 30], set: [0, 1], gap: [0, 3], tall: 0, floors: [3, 7], storey: 3.8, colour: "#7fa2e0" },
  officeTower: { title: "Office tower", group: "Work", w: [30, 50], d: [30, 45], set: [3, 8], gap: [10, 18], tall: 2, floors: [12, 40], storey: 3.8, colour: "#5b80c8" },
  industry: { title: "Works and warehouses", group: "Work", w: [26, 60], d: [20, 45], set: [5, 10], gap: [4, 10], tall: 0, floors: [1, 2], storey: 7, colour: "#a991c0" },
  school: { title: "School", group: "Public", w: [40, 56], d: [24, 32], set: [8, 14], gap: [8, 12], tall: 0, floors: [2, 3], storey: 3.8, colour: "#d9706a", icon: "S", reach: 550, lawn: 6 },
  community: { title: "Community centre", group: "Public", w: [24, 34], d: [18, 24], set: [6, 10], gap: [6, 10], tall: 0, floors: [2, 2], storey: 3.8, colour: "#d9706a", icon: "C", reach: 700 },
  worship: { title: "Place of worship", group: "Public", w: [16, 24], d: [22, 30], set: [4, 8], gap: [6, 10], tall: 0, floors: [1, 2], storey: 7, colour: "#c4605b", icon: "W", reach: 500 },
  clinic: { title: "Health clinic", group: "Public", w: [18, 26], d: [14, 20], set: [3, 6], gap: [4, 8], tall: 0, floors: [2, 3], colour: "#e0827b", icon: "+", reach: 800 },
  library: { title: "Library", group: "Public", w: [22, 30], d: [18, 24], set: [6, 10], gap: [6, 10], tall: 0, floors: [2, 3], storey: 4, colour: "#c4605b", icon: "L", reach: 1000 },
  fire: { title: "Fire station", group: "Public", w: [20, 28], d: [18, 24], set: [6, 10], gap: [6, 10], tall: 0, floors: [2, 2], storey: 4.5, colour: "#c94b45", icon: "F", reach: 1000, main: true },
  police: { title: "Police station", group: "Public", w: [22, 30], d: [18, 24], set: [4, 8], gap: [6, 10], tall: 0, floors: [2, 4], colour: "#c94b45", icon: "P", reach: 1300, main: true },
  hospital: { title: "Hospital", group: "Public", w: [60, 90], d: [40, 60], set: [12, 18], gap: [10, 16], tall: 1, floors: [5, 10], storey: 4, colour: "#e0827b", icon: "H", main: true },
  university: { title: "University", group: "Public", w: [30, 60], d: [24, 40], set: [8, 14], gap: [12, 20], tall: 1, floors: [3, 6], storey: 4, colour: "#c4605b", icon: "U", lawn: 6 },
  cityhall: { title: "City hall", group: "Public", w: [50, 70], d: [34, 46], set: [14, 20], gap: [12, 20], tall: 1, floors: [3, 5], storey: 4.5, colour: "#b5443f", icon: "CH", main: true, lawn: 8 },
};
// Footprint shapes. A building's lot is its rectangle; the shape is drawn inside it, so moving to a
// new shape never changes where buildings stand. Weights per kind; tiers: towers that step back as they rise.
const SHAPES = {
  suburban: { rect: 3, L: 2 }, villa: { L: 3, T: 1, rect: 1, rounded: 1 }, row: { rect: 1 },
  walkup: { rect: 4, L: 1, chamfer: 1 }, slab: { rect: 3, crescent: 2, chamfer: 1 },
  tower: { rect: 2, rounded: 2, round: 1, plus: 1, chamfer: 1 }, luxury: { rounded: 2, round: 2, chamfer: 1, rect: 1 },
  mixed: { rect: 4, L: 1, chamfer: 1 }, corner: { rect: 3, chamfer: 1 }, market: { rect: 1 }, strip: { rect: 2, L: 1 },
  office: { rect: 3, L: 2, U: 1, court: 1, chamfer: 1 }, officeTower: { rect: 2, rounded: 2, round: 1, chamfer: 2, plus: 1 },
  industry: { rect: 3, L: 1 }, school: { L: 2, U: 2, T: 1 }, community: { L: 1, rect: 1, rounded: 1 }, worship: { apse: 3, plus: 1 },
  clinic: { rect: 1, L: 1 }, library: { rounded: 1, rect: 1, round: 1 }, fire: { rect: 1 }, police: { rect: 1, L: 1 },
  hospital: { H: 2, T: 1, plus: 1 }, university: { U: 2, court: 2, L: 1 }, cityhall: { U: 2, court: 1 },
};
const PODIUM = { inset: 0.72, floors: 6 }; // a street-wall tower: its share of the lot, and the podium under it
const TIERED = { tower: 0.35, luxury: 0.4, officeTower: 0.6 }; // share of towers that step back as they rise
const ARC = 6; // straight pieces per quarter circle
// The same spot always rolls the same number, so a building keeps its shape and height when nothing near it changes.
function rollAt(x, y) { return Math.abs(Math.sin(x * 12.9898 + y * 78.233) * 43758.5453) % 1; }
// The shape in lot metres: x along the street (0..W), y back from it (0..D). Returns outer ring and holes.
function shapeOf(kind, W, D, r) {
  const pick = (() => { const opts = Object.entries(SHAPES[kind] || { rect: 1 }), total = opts.reduce((a, o) => a + o[1], 0); let roll = r(0) * total; for (const [s, w] of opts) if ((roll -= w) <= 0) return s; return opts[0][0]; })();
  const m = Math.min(W, D), rect = (x0, y0, x1, y1) => [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
  const arc = (cx, cy, rad, a0, a1, rx = rad) => { const out = [], n = Math.max(2, Math.round(Math.abs(a1 - a0) / (Math.PI / 2) * ARC)); for (let i = 0; i <= n; i++) { const a = a0 + (a1 - a0) * i / n; out.push([cx + Math.cos(a) * rx, cy + Math.sin(a) * rad]); } return out; };
  const P = Math.PI;
  switch (pick) {
    case "L": { // front range along the street, a wing back on one side
      const a = D * (0.45 + r(1) * 0.15), b = W * (0.35 + r(2) * 0.2);
      return { outer: r(3) < 0.5 ? [[0, 0], [W, 0], [W, a], [b, a], [b, D], [0, D]] : [[0, 0], [W, 0], [W, D], [W - b, D], [W - b, a], [0, a]] };
    }
    case "T": { const a = D * (0.4 + r(1) * 0.15), b = W * (0.3 + r(2) * 0.15), c = (W - b) / 2; return { outer: [[0, 0], [W, 0], [W, a], [c + b, a], [c + b, D], [c, D], [c, a], [0, a]] }; }
    case "U": { // the courtyard open to the back
      const a = D * (0.35 + r(1) * 0.1), b = W * (0.25 + r(2) * 0.08); if (W < 24) return { outer: rect(0, 0, W, D) };
      return { outer: [[0, 0], [W, 0], [W, D], [W - b, D], [W - b, a], [b, a], [b, D], [0, D]] };
    }
    case "H": { const b = W * 0.3, a = D * 0.35; return { outer: [[0, 0], [b, 0], [b, a], [W - b, a], [W - b, 0], [W, 0], [W, D], [W - b, D], [W - b, D - a], [b, D - a], [b, D], [0, D]] }; }
    case "plus": {
      const bx = W * (0.3 + r(1) * 0.08), by = D * (0.3 + r(2) * 0.08);
      return { outer: [[bx, 0], [W - bx, 0], [W - bx, by], [W, by], [W, D - by], [W - bx, D - by], [W - bx, D], [bx, D], [bx, D - by], [0, D - by], [0, by], [bx, by]] };
    }
    case "court": { // a perimeter block round an inner yard
      const t = m * (0.26 + r(1) * 0.06); if (m < 26) return { outer: rect(0, 0, W, D) };
      return { outer: rect(0, 0, W, D), holes: [rect(t, t, W - t, D - t).reverse()] };
    }
    case "chamfer": { // corners cut at 45 degrees
      const c = m * (0.15 + r(1) * 0.12); return { outer: [[c, 0], [W - c, 0], [W, c], [W, D - c], [W - c, D], [c, D], [0, D - c], [0, c]] };
    }
    case "rounded": {
      const c = m * (0.18 + r(1) * 0.2);
      return { outer: [...arc(W - c, c, c, -P / 2, 0), ...arc(W - c, D - c, c, 0, P / 2), ...arc(c, D - c, c, P / 2, P), ...arc(c, c, c, P, 1.5 * P)] };
    }
    case "round": { // a round or oval tower in the middle of its lot
      const rx = W / 2, ry = Math.min(D / 2, rx * (0.85 + r(1) * 0.3)); return { outer: arc(W / 2, D / 2, ry, 0, 2 * P, Math.min(rx, ry * 1.3)).slice(0, -1) };
    }
    case "crescent": { // a slab bowed back from the street, the curve of a crescent
      const bow = Math.min(D * 0.45, W * 0.12), t = D - bow, n = ARC * 2, front = [];
      for (let i = 0; i <= n; i++) { const x = W * i / n, u = 2 * i / n - 1; front.push([x, bow * (1 - u * u)]); }
      return { outer: [...front, ...front.slice().reverse().map(([x, y]) => [x, y + t])] };
    }
    case "apse": { // a hall with a round end at the back
      const rad = Math.min(W / 2 * 0.8, D * 0.35), cx = W / 2, cy = D - rad;
      return { outer: [[0, 0], [W, 0], [W, cy], ...arc(cx, cy, rad, 0, P), [0, cy]] };
    }
    default: return { outer: rect(0, 0, W, D) };
  }
}
// The shape in map metres, and whether the tower steps back. Kept on the building after the first ask.
function formOf(b) {
  if (b.form) return b.form;
  const q = b.poly, W = Math.hypot(q[1][0] - q[0][0], q[1][1] - q[0][1]), D = Math.hypot(q[3][0] - q[0][0], q[3][1] - q[0][1]);
  const ex = [(q[1][0] - q[0][0]) / W, (q[1][1] - q[0][1]) / W], ey = [(q[3][0] - q[0][0]) / D, (q[3][1] - q[0][1]) / D];
  const cx = (q[0][0] + q[2][0]) / 2, cy = (q[0][1] + q[2][1]) / 2, r = k => rollAt(cx + k * 17.31, cy - k * 9.73);
  const map2 = ([x, y]) => [q[0][0] + ex[0] * x + ey[0] * y, q[0][1] + ex[1] * x + ey[1] * y];
  if (b.wall) {
    // On a street wall the building fills its lot, wall to wall; a tower there rises from a podium
    // that keeps the street line (Manhattan), its own shape set back above it.
    const box = [[0, 0], [W, 0], [W, D], [0, D]];
    if (b.tall < 2) return (b.form = { outer: box.map(map2), holes: [], centre: [cx, cy], tiered: false });
    const t = shapeOf(b.kind, W * PODIUM.inset, D * PODIUM.inset, r), ox = W * (1 - PODIUM.inset) / 2, oy = D * (1 - PODIUM.inset) / 2;
    return (b.form = { outer: box.map(map2), holes: [], centre: [cx, cy], tiered: r(7) < (TIERED[b.kind] || 0),
      tower: t.outer.map(([x, y]) => map2([x + ox, y + oy])) });
  }
  const s = shapeOf(b.kind, W, D, r);
  b.form = { outer: s.outer.map(map2), holes: (s.holes || []).map(h => h.map(map2)), centre: [cx, cy], tiered: !s.holes && r(7) < (TIERED[b.kind] || 0) };
  return b.form;
}
const HOME_KINDS = ["suburban", "villa", "row", "walkup", "slab", "tower", "luxury"], OFFICE_KINDS = ["office", "officeTower"];
// Services in the order they are sited: one each per catchment, from the widest reach down.
const SERVICES = ["police", "fire", "library", "strip", "clinic", "market", "community", "school", "worship"];
// archetype -> homes weights (suburban, villa, row, walk-up, slab, tower, luxury), offices
// (low, tower), share of homes frontage on main roads and on side streets that is shops below
// flats, chance of a corner shop by a junction, and whether shops come as a strip with parking.
const NEIGHBOURHOOD = {
  forgotten: { homes: [0.55, 0, 0.35, 0.1, 0, 0, 0], offices: [1, 0], mixedMain: 0.25, mixedSide: 0, corner: 0.15, strip: true },
  immigrant: { homes: [0, 0, 0.3, 0.6, 0.1, 0, 0], offices: [1, 0], mixedMain: 0.85, mixedSide: 0.25, corner: 0.35 },
  public_housing: { homes: [0, 0, 0, 0.2, 0.45, 0.35, 0], offices: [1, 0], mixedMain: 0.25, mixedSide: 0, corner: 0.1, strip: true },
  industrial: { homes: [0.4, 0, 0.5, 0.1, 0, 0, 0], offices: [1, 0], mixedMain: 0.15, mixedSide: 0, corner: 0.1, strip: true },
  workers: { homes: [0.25, 0, 0.5, 0.25, 0, 0, 0], offices: [1, 0], mixedMain: 0.5, mixedSide: 0.08, corner: 0.25 },
  gentrifying: { homes: [0, 0, 0.4, 0.4, 0, 0, 0.2], offices: [0.8, 0.2], mixedMain: 0.85, mixedSide: 0.2, corner: 0.3 },
  university: { homes: [0, 0, 0.3, 0.6, 0, 0.1, 0], offices: [0.8, 0.2], mixedMain: 0.75, mixedSide: 0.15, corner: 0.3 },
  nightlife: { homes: [0, 0, 0.3, 0.6, 0, 0, 0.1], offices: [0.9, 0.1], mixedMain: 1, mixedSide: 0.5, corner: 0.4 },
  financial: { homes: [0, 0, 0, 0.2, 0, 0.2, 0.6], offices: [0, 1], mixedMain: 0.6, mixedSide: 0.1, corner: 0.2 },
  luxury: { homes: [0.15, 0.5, 0, 0, 0, 0, 0.35], offices: [0.5, 0.5], mixedMain: 0.3, mixedSide: 0, corner: 0.05, strip: true },
  civic: { homes: [0, 0, 0.2, 0.5, 0, 0, 0.3], offices: [0.4, 0.6], mixedMain: 0.8, mixedSide: 0.3, corner: 0.3 },
};
// Street cross-sections. Widths in metres; lanes counted both ways.
const ROADS = {
  none: { title: "None" },
  boulevard: { title: "Boulevard: 6 lanes, planted median, parking", lanes: 6, lane: 3.3, median: 5, parking: 2, bike: 0, walk: 5, oneWay: false },
  avenue_bike: { title: "Avenue: 4 lanes, bike lanes, parking", lanes: 4, lane: 3.1, median: 0, parking: 2, bike: 2, walk: 4.5, oneWay: false },
  avenue: { title: "Avenue: 4 lanes, parking both sides", lanes: 4, lane: 3.1, median: 0, parking: 2, bike: 0, walk: 4.5, oneWay: false },
  oneway_avenue: { title: "One-way avenue: 4 lanes, parking", lanes: 4, lane: 3.1, median: 0, parking: 2, bike: 0, walk: 4.5, oneWay: true },
  street: { title: "Two-way street: 2 lanes, parking", lanes: 2, lane: 3.0, median: 0, parking: 2, bike: 0, walk: 3.2, oneWay: false },
  oneway: { title: "One-way street: 1 lane, parking both sides", lanes: 1, lane: 3.3, median: 0, parking: 2, bike: 0, walk: 3.2, oneWay: true },
  oneway_bike: { title: "One-way street: 1 lane, bike lane, parking", lanes: 1, lane: 3.3, median: 0, parking: 2, bike: 1, walk: 3.2, oneWay: true },
  lane: { title: "Narrow shared lane, no markings", lanes: 1, lane: 5.0, median: 0, parking: 0, bike: 0, walk: 1.5, oneWay: false, shared: true },
  promenade: { title: "Waterfront drive", lanes: 2, lane: 3.2, median: 0, parking: 1, bike: 0, walk: 6, oneWay: false },
  // Shoulders drawn as parking strips, verges as sidewalks; nobody walks there.
  expressway: { title: "Expressway: 4 lanes, one interchange", lanes: 4, lane: 3.6, median: 3, parking: 2, bike: 0, walk: 4, oneWay: false },
  ramp: { title: "Ramp", lanes: 1, lane: 4.0, median: 0, parking: 1, bike: 0, walk: 1.5, oneWay: true },
};
const PARKING = 2.4, BIKE = 1.8, LAWN = "#cfe4b4", PATH_COLOUR = "#efe6cf";
for (const r of Object.values(ROADS)) {
  if (!r.lanes) continue;
  r.road = r.lanes * r.lane + r.median + r.parking * PARKING + r.bike * BIKE;
  r.total = r.road + 2 * r.walk;
}
const FIELD = { w: 1600, h: 1330, step: 10, maxLen: 2400 };
const LAB = { slideStep: 3000, oneWayPasses: 3, townReach: 0.85, metroDensity: 0.5, townWobble: 0.25, metroLift: 1.4, metroFloor: 0.35, districtArea: 4.5e6, boroughLine: 1, hoodLabel: 190, singleDistrict: 1000, aspect: 1330 / 1600, coastWave: 420, gapFill: [0.45, 0.3], deadRef: 0.1, joinShort: 140, acrossReach: 40, wallSetback: 0.35, wallGap: 0.35, cell: 2, sliver: 450, square: 1300, joinReach: 2.0, mainOffices: 2.0, centrePublic: 2.5,
  bigBlock: 24000, bigParks: 3.0, maxPark: 45000,
  // Largest block before a street is cut through it (m², street-wall districts, others), up to
  // a few rounds; the share of big blocks kept whole as parks; the shortest cut (m); how far a
  // cul-de-sac in a huge block runs on to the next road (m).
  maxBlock: [12000, 20000], splitRounds: 6, keepWhole: 0.08, joinOn: 300, splitMin: 60, splitCos: 0.85,
  // Deep blocks filled behind the frontage: smallest block (m²), air between buildings, the
  // yard kept behind the frontage, and the deepest a building may stand from a street (m).
  // A street end is moved onto the middle of its junction from this far past the other road's kerb (m), the move fading out
  // along the street over snapFade (m).
  snapReach: 4, snapFade: 40,
  // People on foot: a passage through blocks longer than passageAt (m), passageWidth wide, in blocks
  // over passageArea (m²); park paths in parks over pathPark (m²), entrances at least doorGap apart;
  // street trees in a strip of treeStrip (m) beside a clear path of clearPath (m), every treeEvery.
  passageAt: 200, passageWidth: 3, passageArea: 9000, pathPark: 2500, doorGap: 25, maxDoors: 5, clearPath: 1.8, treeStrip: 1.2, treeEvery: 15,
  shallowDepth: [7, 14], infillMin: 5000, infillAir: 6, infillYard: 14, infillReach: 70,
  splitOffsets: [0, 0.4, -0.4, 0.8, -0.8], splitTurns: [0, 0.3, -0.3, 0.6, -0.6], edgeIndustry: 1.8, waterParks: 2.5,
  // Tightest centreline radius per tier (m), after local street design tables for 25 to 45 mph.
  radius: { boulevard: 220, avenue: 120, street: 40, expressway: 300, ramp: 40 },
  // Most a street may turn in all before it ends, so streets never spiral (degrees).
  maxTurn: { boulevard: 70, avenue: 110, street: 120 },
  // Two streets closer than their half widths cross only at about 53 degrees or steeper (cos 53).
  crossCos: 0.6,
  // Streets closer to parallel than this (cos 45) keep a tier's spacing apart.
  parallelCos: 0.7,
  // A bridge goes straight and is at most this many river widths long.
  bridgeRun: 1.3,
  // A neighbourhood park takes a homes block of this size (m²).
  pocketPark: [1500, 25000],
  // A dead end stops at least this far (m) beyond the edge of any other street.
  culDeSacGap: 20,
  // A dead end's turning circle, as a multiple of its street's width.
  bulb: 1.5,
  // Districts: grid cell (m), smallest district (m²); smaller pockets join a neighbour.
  districtCell: 8, minDistrict: 250000,
  // A bounding road ending this close (m) to the edge of the map is taken to run on to it.
  edgeReach: 40,
  // How the district-bounding roads run before the districts exist.
  borderStyle: { grid: 4, radial: 0, reach: 700, wobble: 0.15 },
  // Two T junctions from opposite sides closer than this (m) along a road are made one crossing.
  stagger: 40,
  // Traffic: junctions sampled as trip origins; a side street carrying this share of a typical
  // avenue's load, at least this long (m), becomes an avenue, up to this share of side-street km.
  trafficSources: 60, upgradeShare: 0.6, upgradeLength: 250, upgradeMax: 0.12,
  // Legs closer than this (degrees) or five or more legs make a junction a roundabout candidate.
  squareAngle: 70,
  // A slanting street is swung round over its last this many metres to meet its road square.
  squareReach: [50, 80, 35],
  // Chance an ordinary avenue crossing in a grid district gets a roundabout instead of signals.
  roundaboutChance: 0.15,
  // Roundabout outer diameter (m) by the highest road class: mini, single lane, two lanes (FHWA).
  roundabout: [18, 36, 56], miniIsland: 3, roundaboutGap: 15,
  // A roundabout the player places takes the junction within userReach (m) of the click; away from
  // any, it is put on the nearest road within roadReach (m).
  userReach: 30, roadReach: 25,
  // Fewest districts a map may have before its boulevards are drawn closer.
  minDistricts: 2,
  // A crossing stands one car length back from a roundabout; crossings at least this far apart (m);
  // a main road gets one at least this often (m), and twice as often by parks, schools and shops.
  carLength: 7, crossingGap: 60, crossingEvery: 220,
  // Building lines: extra front setback (m) on boulevards and avenues outside street-wall districts,
  // and the corner kept clear at a junction so drivers see each other (m).
  arterialSetback: { boulevard: 6, avenue: 3 }, sightCorner: 4,
  // Frontage sites every siteStep (m); tries per block for a service; the smallest block that
  // hosts one (m²); how near a junction a corner shop stands (m).
  siteStep: 2, siteTries: 40, serviceBlock: 2500, cornerReach: 30, cornerShops: 2,
  // Streets that serve nothing: a short cul-de-sac (under idleLength, m) with no building on it, and every
  // stretch of street with park on both sides, keeping what is left if over keepStretch (m);
  // rebuilt up to prunePasses times.
  // The smallest campus block (m²).
  idleLength: 150, keepStretch: 40, prunePasses: 3, campusMin: 6000,
  // Expressway route: grid (m), extra cost by the centre and on water, cost of a turn, smoothing
  // passes; ramps leave this far (m) from the bridge and meet the boulevard this far from it;
  // crossings flatter than this (degrees) get no interchange. No building this close (m) to it.
  express: { grid: 20, centre: 1.5, wet: 12, bank: 60, turn: 0.8, smooth: 120, gore: 170, terminal: 75, minAngle: 55, sizes: [1, 0.85, 1.2, 0.7] },
  noiseBuffer: 12,
  // A piece of town reached only off the map is joined by a street up to this long (m); shorter pieces
  // are left; a street from the middle of a piece costs this much more than one from a dead end.
  pieceLinks: 12, pieceReach: 320, pieceMin: 0, pieceMid: 60, bridgeAngle: 50,
  // A bridge that joins a piece spans at most this many river widths.
  bridgeSpan: 1.6,
  // Near its two ends (m) a joining street may pass close to the roads at the junctions it meets.
  pieceEnds: 22, pieceStagger: 40, pieceMeet: 55,
  // The shortest joining street (m); a bridge's road on land, both banks together (m).
  pieceShort: 10, bridgeLanding: 90, piecePasses: 3 };
// Dense districts build to the property line, so the buildings make a continuous street wall.
// How deep a building in a dense core may run back from the street (m): real cores cover 82 to 91%
// of each block inside the pavement line (Paris, Barcelona, Manhattan), Tel Aviv about 65%.
const WING = { financial: 40, nightlife: 32, civic: 30, gentrifying: 26, immigrant: 22 };
const STREET_WALL = new Set(["financial", "nightlife", "immigrant", "gentrifying", "civic"]);

const PATTERN_SLIDERS = [
  ["minor", "Side street spacing (m)", 50, 200, 5, 75],
  ["major", "Avenue spacing (m)", 120, 500, 10, 220],
  ["blvd", "Boulevard spacing (m)", 400, 1200, 20, 640],
  ["dead", "Dead ends", 0, 0.5, 0.01, 0.1],
  ["curvy", "Curviness", 0, 3, 0.05, 1],
];
const WATER_SLIDERS = [
  ["river", "River width (m), 0 for none", 0, 320, 10, 160],
  ["meander", "River bends", 0, 1.5, 0.05, 0.6],
  ["coast", "Sea along one side (m), 0 for none", 0, 400, 10, 0],
];
const USE_SLIDERS = [
  ["u0", "Homes", 0, 3, 0.05, 1], ["u1", "Offices", 0, 3, 0.05, 1],
  ["u2", "Industry", 0, 3, 0.05, 1], ["u4", "Parks", 0, 3, 0.05, 1],
  ["green", "Park within (m), 0 off", 0, 1000, 25, 400],
];
const QUICK_SLIDERS = [
  ["size", "City size (km across)", 0.6, 3.2, 0.1, 1.6],
  ["density", "Building density", 0, 2, 0.05, 1],
];
const HEIGHT_SLIDERS = [
  ["pull", "Downtown pull", 0, 2, 0.05, 1],
  ["spread", "Height range", 0, 2, 0.05, 1],
];
const ROAD_TIERS = [
  ["blvdType", "Boulevards", ["boulevard", "avenue_bike", "avenue", "none"], "boulevard"],
  ["mainType", "Avenues", ["avenue", "avenue_bike", "oneway_avenue", "street"], "avenue"],
  ["sideType", "Side streets", ["street", "oneway", "oneway_bike", "lane"], "oneway"],
  ["expressType", "Expressway", ["expressway", "none"], "expressway"],
];

// ---------- Seeded randomness ----------
function makeRng(seed) {
  let a = (seed >>> 0) || 1;
  const next = () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  return { f: next, range: (lo, hi) => lo + next() * (hi - lo), int: (lo, hi) => lo + Math.floor(next() * (hi - lo + 1)) };
}
function makeNoise(seed, freq) {
  const rng = makeRng(seed), table = new Float32Array(512);
  for (let i = 0; i < 512; i++) table[i] = rng.f() * 2 - 1;
  const h = (x, y) => table[((x * 374761393 + y * 668265263) >>> 0) % 509];
  const s = t => t * t * (3 - 2 * t);
  return (px, py) => {
    const x = px * freq, y = py * freq, x0 = Math.floor(x), y0 = Math.floor(y), fx = s(x - x0), fy = s(y - y0);
    const a = h(x0, y0), b = h(x0 + 1, y0), c = h(x0, y0 + 1), d = h(x0 + 1, y0 + 1);
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
  };
}

// ---------- Districts: the land the main roads enclose ----------
// A district is the land walled in by boulevards (avenues when there are none), the water and the
// edge of the map, so the districts move with the roads. Pockets too small to be a district join
// the neighbour they grow into first.
function findDistricts(walls, water, p, rng) {
  const C = LAB.districtCell, W = Math.ceil(FIELD.w / C), H = Math.ceil(FIELD.h / C), ox = -FIELD.w / 2, oy = -FIELD.h / 2;
  const WET = -2, WALL = -1, NONE = -3, raw = new Int32Array(W * H).fill(NONE);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++)
    if (water.isWater(ox + (x + 0.5) * C, oy + (y + 0.5) * C)) raw[y * W + x] = WET;
  const wall = new Uint8Array(W * H);
  // A road ending just short of the edge of the map still closes its district off.
  const toEdge = (e, inner) => {
    const hx = e[0] - inner[0], hy = e[1] - inner[1], l = Math.hypot(hx, hy) || 1, reach = LAB.edgeReach;
    const x = e[0] + hx / l * reach, y = e[1] + hy / l * reach;
    return insideField(x, y) ? null : [x, y];
  };
  for (const l of walls) {
    const r = ROADS[l.type].total / 2 / C, n0 = l.pts.length;
    const pts = [toEdge(l.pts[0], l.pts[1]), ...l.pts, toEdge(l.pts[n0 - 1], l.pts[n0 - 2])].filter(Boolean);
    for (let n = 0; n < pts.length - 1; n++) {
      const a = pts[n], b = pts[n + 1], steps = Math.max(1, Math.ceil(Math.hypot(b[0] - a[0], b[1] - a[1]) / C));
      for (let s = 0; s <= steps; s++) {
        const px = (a[0] + (b[0] - a[0]) * s / steps - ox) / C, py = (a[1] + (b[1] - a[1]) * s / steps - oy) / C;
        for (let y = Math.max(0, Math.floor(py - r)); y <= Math.min(H - 1, Math.floor(py + r)); y++)
          for (let x = Math.max(0, Math.floor(px - r)); x <= Math.min(W - 1, Math.floor(px + r)); x++) {
            const i = y * W + x;
            if ((px - x - 0.5) ** 2 + (py - y - 0.5) ** 2 <= r * r && raw[i] !== WET) { raw[i] = WALL; wall[i] = 1; }
          }
      }
    }
  }
  // Enclosed pieces of land.
  const pieces = [], stack = new Int32Array(W * H);
  for (let i = 0; i < raw.length; i++) {
    if (raw[i] !== NONE) continue;
    const id = pieces.length; let top = 0, cells = 0; stack[top++] = i; raw[i] = id;
    while (top) {
      const n = stack[--top], x = n % W, y = (n - x) / W; cells++;
      for (const m of [x > 0 ? n - 1 : -1, x < W - 1 ? n + 1 : -1, y > 0 ? n - W : -1, y < H - 1 ? n + W : -1])
        if (m >= 0 && raw[m] === NONE) { raw[m] = id; stack[top++] = m; }
    }
    pieces.push(cells * C * C);
  }
  const single = isSingle(p);
  let keep = pieces.map((a, i) => i).filter(i => pieces[i] >= LAB.minDistrict);
  if (!keep.length && pieces.length) keep = [pieces.indexOf(Math.max(...pieces))];
  // Pockets and the roads themselves join the district they grow into first.
  const at = new Int32Array(W * H).fill(-1), queue = new Int32Array(W * H); let head = 0, tail = 0;
  const index = single ? new Map(pieces.map((_, i) => [i, 0])) : new Map(keep.map((piece, d) => [piece, d]));
  if (single) keep = [0];
  for (let i = 0; i < raw.length; i++) if (index.has(raw[i])) { at[i] = index.get(raw[i]); queue[tail++] = i; }
  while (head < tail) {
    const n = queue[head++], x = n % W, y = (n - x) / W;
    for (const m of [x > 0 ? n - 1 : -1, x < W - 1 ? n + 1 : -1, y > 0 ? n - W : -1, y < H - 1 ? n + W : -1])
      if (m >= 0 && at[m] < 0 && raw[m] !== WET) { at[m] = at[n]; queue[tail++] = m; }
  }
  const list = keep.map(() => ({ cells: [], sx: 0, sy: 0, edge: false }));
  for (let i = 0; i < at.length; i++) {
    const d = at[i]; if (d < 0 || wall[i]) continue;
    const x = i % W, y = (i - x) / W, D = list[d];
    D.cells.push(i); D.sx += x; D.sy += y;
    if (x === 0 || y === 0 || x === W - 1 || y === H - 1) D.edge = true;
  }
  const point = i => [ox + (i % W + 0.5) * C, oy + (Math.floor(i / W) + 0.5) * C];
  for (const D of list) {
    const n = Math.max(1, D.cells.length), cx = D.sx / n, cy = D.sy / n;
    D.area = D.cells.length * C * C;
    let best = D.cells[0], bd = Infinity; // the label sits on the district cell nearest its middle
    for (const i of D.cells) { const d = (i % W - cx) ** 2 + (Math.floor(i / W) - cy) ** 2; if (d < bd) { bd = d; best = i; } }
    [D.x, D.y] = point(best ?? 0);
    const fromCentre = Math.hypot(D.x / (FIELD.w / 2), D.y / (FIELD.h / 2)) / Math.SQRT2;
    D.ring = fromCentre < 0.3 ? 2 : fromCentre < 0.6 ? 1 : 0; // 2 core, 0 edge
    if (p.context === "metro") D.ring = Math.max(1, D.ring);
    D.pick = () => point(D.cells[rng.int(0, D.cells.length - 1)] ?? 0);
  }
  // Archetypes: the cult starts in a district at the edge; the rest by how central they are, from
  // their district's list in a big city. A one-neighbourhood map is the kind the menu asks for.
  // Only built-up land counts towards districts: a town's fields do not make it a bigger city.
  let builtCells = 0;
  for (const D of list) for (const i of D.cells) { const [x, y] = point(i); if (water.built(x, y)) builtCells++; }
  const groupsFit = Math.round(builtCells * C * C / LAB.districtArea);
  const boroughs = !single && groupsFit >= 2 && list.length >= 4 ? groupDistricts(list, groupsFit, rng) : null;
  const used = new Set(), edges = list.filter(D => D.ring === 0 || D.edge);
  let start = list.indexOf(edges.length ? edges[rng.int(0, edges.length - 1)] : list[list.length - 1]);
  if (single) { start = 0; list[0].archetype = ARCHETYPES.find(a => a.id === p.kind) || ARCHETYPES[rng.int(0, ARCHETYPES.length - 1)]; }
  else if (start >= 0) { list[start].archetype = ARCHETYPES[0]; used.add(ARCHETYPES[0].id); }
  const inBorough = D => boroughs ? boroughs[D.borough].members : list;
  for (const ring of [2, 1, 0]) for (const D of list) {
    if (D.archetype || D.ring !== ring) continue;
    const near = new Set(inBorough(D).map(o => o.archetype && o.archetype.id));
    const theme = boroughs ? ARCHETYPES.filter(a => boroughs[D.borough].theme.ids.includes(a.id)) : ARCHETYPES;
    let pool = theme.filter(a => !(boroughs ? near : used).has(a.id));
    if (!pool.length) pool = theme;
    const total = pool.reduce((t, a) => t + a.ring[ring], 0);
    let pick = pool[rng.int(0, pool.length - 1)];
    if (total > 0) { let roll = rng.f() * total; for (const a of pool) { roll -= a.ring[ring]; if (roll <= 0) { pick = a; break; } } }
    D.archetype = pick; used.add(pick.id);
  }
  for (const D of list) {
    D.style = p.style >= 0 ? STYLES[p.style] : STYLES.find(st => st.id === MIXES[D.archetype.id][0]);
    D.mix = MIXES[D.archetype.id][1];
  }
  const cellAt = (x, y) => {
    const cx = Math.floor((x - ox) / C), cy = Math.floor((y - oy) / C);
    return cx < 0 || cy < 0 || cx >= W || cy >= H ? -1 : cy * W + cx;
  };
  return {
    list, start, W, H, C, cells: at, wall, perStyle: p.style < 0, boroughs, built: water.built,
    at: (x, y) => { const i = cellAt(x, y); return i < 0 ? -1 : at[i]; },
    isWall: (x, y) => { const i = cellAt(x, y); return i < 0 || wall[i] === 1; },
  };
}
// A big city groups its neighbourhoods into a few districts, each with a character: the middle is
// downtown, the ring round it lived-in, the edge rougher. Each neighbourhood draws its kind from
// its district's list.
const THEMES = [
  { ring: 0, ids: ["industrial", "public_housing", "workers", "forgotten", "immigrant"] },
  { ring: 1, ids: ["gentrifying", "university", "immigrant", "workers", "nightlife", "luxury"] },
  { ring: 2, ids: ["financial", "civic", "nightlife", "luxury", "gentrifying"] },
];
const COMPASS = ["East", "Northeast", "North", "Northwest", "West", "Southwest", "South", "Southeast"];
function groupDistricts(list, k, rng) {
  // Seeds spread apart (each the farthest from the ones before), then two rounds of nearest-centre.
  const seeds = [list[rng.int(0, list.length - 1)]].map(D => [D.x, D.y]);
  while (seeds.length < k) {
    let far = list[0], fd = -1;
    for (const D of list) { const d = Math.min(...seeds.map(s => Math.hypot(D.x - s[0], D.y - s[1]))); if (d > fd) { fd = d; far = D; } }
    seeds.push([far.x, far.y]);
  }
  for (let round = 0; round < 3; round++) {
    for (const D of list) {
      let best = 0, bd = Infinity;
      seeds.forEach((s, i) => { const d = Math.hypot(D.x - s[0], D.y - s[1]); if (d < bd) { bd = d; best = i; } });
      D.borough = best;
    }
    seeds.forEach((s, i) => {
      const own = list.filter(D => D.borough === i); if (!own.length) return;
      const w = own.reduce((a, D) => a + D.area, 0);
      s[0] = own.reduce((a, D) => a + D.x * D.area, 0) / w; s[1] = own.reduce((a, D) => a + D.y * D.area, 0) / w;
    });
  }
  const groups = seeds.map(([x, y], i) => ({ x, y, members: list.filter(D => D.borough === i) })).filter(g => g.members.length);
  groups.forEach((g, i) => { for (const D of g.members) D.borough = i; });
  const inner = groups.reduce((a, g) => (Math.hypot(g.x, g.y) < Math.hypot(a.x, a.y) ? g : a));
  const used = new Set();
  for (const g of groups) {
    const fromCentre = Math.hypot(g.x / (FIELD.w / 2), g.y / (FIELD.h / 2)) / Math.SQRT2;
    g.theme = THEMES[g === inner ? 2 : fromCentre < 0.55 ? 1 : 0];
    let name = g === inner ? "Downtown" : `${COMPASS[Math.round(((Math.atan2(g.y, g.x) + 2 * Math.PI) % (2 * Math.PI)) / (Math.PI / 4)) % 8]} ${g.theme.ring ? "Side" : "End"}`;
    for (let n = 2; used.has(name); n++) name = name.replace(/ \d+$/, "") + " " + n;
    used.add(name); g.name = name;
  }
  return groups;
}
// Before there are districts, the roads that will bound them follow one calm field over the city.
function cityWide(rng) {
  const D = { style: LAB.borderStyle, pick: () => [rng.range(-FIELD.w / 2, FIELD.w / 2), rng.range(-FIELD.h / 2, FIELD.h / 2)] };
  return { list: [D], at: () => 0 };
}
// City setting: a town fills the middle of the map and fields lie round it; in a city the map is a
// part of the city; a metropolis is denser and taller all over, with no rough outskirts in view.
function townShape(p) {
  if (p.context !== "town" || isSingle(p)) return () => true; // one neighbourhood is all town
  const rng = makeRng(p.seed + 104729), noise = makeNoise(rng.int(1, 1e9), 1 / 300);
  const cx = rng.range(-0.1, 0.1) * FIELD.w, cy = rng.range(-0.1, 0.1) * FIELD.h, R = LAB.townReach * Math.min(FIELD.w, FIELD.h) / 2;
  return (x, y) => {
    const a = Math.atan2(y - cy, x - cx);
    return Math.hypot(x - cx, y - cy) < R * (1 + LAB.townWobble * noise(Math.cos(a) * 600, Math.sin(a) * 600));
  };
}
const isSingle = p => p.size * 1000 < LAB.singleDistrict;
const insideField = (x, y) => Math.abs(x) <= FIELD.w / 2 && Math.abs(y) <= FIELD.h / 2;

// ---------- Water: a meandering river and a sea along one side ----------
function makeWater(p, rng) {
  const water = { river: null, riverWidth: p.river, coastSide: -1, coastDepth: p.coast, coastNoise: null, banks: [] };
  const hw = FIELD.w / 2, hh = FIELD.h / 2;
  if (p.coast > 0) {
    water.coastSide = rng.int(0, 3); // 0 east, 1 north, 2 west, 3 south
    water.coastNoise = makeNoise(rng.int(1, 1e9), 1 / LAB.coastWave);
  }
  if (p.river > 0) {
    const noise = makeNoise(rng.int(1, 1e9), 1 / 500);
    const vertical = rng.f() < 0.5, along = vertical ? hh : hw;
    let x = vertical ? rng.range(-hw * 0.5, hw * 0.5) : -hw - 50, y = vertical ? -hh - 50 : rng.range(-hh * 0.5, hh * 0.5);
    const base = vertical ? Math.PI / 2 : 0, pts = [];
    for (let s = 0; s < along * 4 && Math.abs(x) <= hw + 60 && Math.abs(y) <= hh + 60; s += 15) {
      pts.push([x, y]);
      const a = base + noise(s, 0) * p.meander * 1.4;
      x += Math.cos(a) * 15; y += Math.sin(a) * 15;
    }
    water.river = pts;
    water.riverGrid = new Map();
    pts.forEach((q, i) => { const k = Math.floor(q[0] / 40) * 100003 + Math.floor(q[1] / 40); if (!water.riverGrid.has(k)) water.riverGrid.set(k, []); water.riverGrid.get(k).push(i); });
  }
  water.coastLine = t => water.coastDepth + water.coastNoise(t, 0) * Math.min(120, water.coastDepth * 0.6);
  water.isSea = (x, y) => {
    if (water.coastSide < 0) return false;
    const [inward, t] = [[hw - x, y], [hh - y, x], [x + hw, y], [y + hh, x]][water.coastSide];
    return inward < water.coastLine(t);
  };
  water.riverDist = (x, y) => {
    if (!water.river) return Infinity;
    const cx = Math.floor(x / 40), cy = Math.floor(y / 40), reach = Math.ceil(water.riverWidth / 80) + 1;
    let best = Infinity;
    for (let dx = -reach; dx <= reach; dx++) for (let dy = -reach; dy <= reach; dy++) {
      const list = water.riverGrid.get((cx + dx) * 100003 + cy + dy); if (!list) continue;
      for (const i of list) { const q = water.river[i]; const d = (q[0] - x) ** 2 + (q[1] - y) ** 2; if (d < best) best = d; }
    }
    return Math.sqrt(best);
  };
  water.isRiver = (x, y) => water.riverDist(x, y) < water.riverWidth / 2;
  water.isWater = (x, y) => water.isSea(x, y) || water.isRiver(x, y);
  // Within margin metres of the water's edge.
  water.near = (x, y, margin) => {
    if (water.riverDist(x, y) < water.riverWidth / 2 + margin) return true;
    if (water.coastSide < 0) return false;
    const [inward, t] = [[hw - x, y], [hh - y, x], [x + hw, y], [y + hh, x]][water.coastSide];
    return inward < water.coastLine(t) + margin;
  };
  return water;
}
function offsetLine(pts, d) {
  return pts.map((q, i) => {
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)];
    const tx = b[0] - a[0], ty = b[1] - a[1], l = Math.hypot(tx, ty) || 1;
    return [q[0] - ty / l * d, q[1] + tx / l * d];
  });
}
// Keeps the runs of a line that are on land and on the map.
function landRuns(pts, water) {
  const runs = []; let cur = [];
  for (const q of pts) {
    if (insideField(q[0], q[1]) && !water.isWater(q[0], q[1])) cur.push(q);
    else { if (cur.length > 3) runs.push(cur); cur = []; }
  }
  if (cur.length > 3) runs.push(cur);
  return runs;
}
const DRIVE = () => ROADS.promenade.total / 2 + 2; // waterfront drive centre, from the water's edge
function waterfront(water) {
  const drive = DRIVE(), lines = [];
  if (water.river) for (const side of [1, -1]) lines.push(...landRuns(offsetLine(water.river, side * (water.riverWidth / 2 + drive)), water));
  if (water.coastSide >= 0) {
    const hw = FIELD.w / 2, hh = FIELD.h / 2, pts = [];
    const span = water.coastSide % 2 === 0 ? hh : hw;
    for (let t = -span - 20; t <= span + 20; t += 10) {
      const inward = water.coastLine(t) + drive;
      pts.push([[hw - inward, t], [t, hh - inward], [inward - hw, t], [t, inward - hh]][water.coastSide]);
    }
    lines.push(...landRuns(pts, water));
  }
  return lines;
}

// ---------- Street directions: each district lays its own patches and fans ----------
// Each district lays its own patches and fans; a point follows only its own district's, so the
// pattern changes where a district meets the next, at the road between them.
// cityAngle: the city's main bearing, shared by the bounding roads and the districts' streets so
// that a district's grid meets its bounding roads square.
function makeField(districts, curvy, cityAngle, rng) {
  const noise = makeNoise(rng.int(1, 1e9), 0.003);
  const bases = districts.list.map(D => {
    const st = D.style, turn = Math.PI / 2 * Math.min(1, st.wobble * 2), out = [];
    for (let n = 0; n < st.grid + st.radial; n++) {
      const [x, y] = D.pick();
      out.push({ x, y, angle2: (cityAngle + rng.range(-turn, turn)) * 2, fan: n >= st.grid, reachSq: st.reach * st.reach });
    }
    return out;
  });
  const wobbles = districts.list.map(D => D.style.wobble * curvy);
  return (px, py) => {
    const d = districts.at(px, py);
    if (d < 0) return [Math.cos(cityAngle), Math.sin(cityAngle)];
    let sx = 0, sy = 0;
    for (const b of bases[d]) {
      const ox = px - b.x, oy = py - b.y, w = Math.exp(-(ox * ox + oy * oy) / b.reachSq) + 1e-12;
      const a = b.fan ? Math.atan2(oy, ox) * 2 : b.angle2;
      sx += Math.cos(a) * w; sy += Math.sin(a) * w;
    }
    const ang = Math.atan2(sy, sx) / 2 + noise(px, py) * wobbles[d];
    return [Math.cos(ang), Math.sin(ang)];
  };
}

// ---------- Street tracer: boulevards, then avenues, then side streets ----------
// A street avoids running alongside an earlier street that follows the same direction, bends no
// tighter than its tier's radius, ends where it would merge into another street or cross it at
// a shallow angle, and only boulevards cross the river, on straight bridges.
// The street style at a point when each district keeps its own, or null.
function localStyle(districts, x, y) {
  if (!districts || !districts.perStyle) return null;
  const d = districts.at(x, y); return d < 0 ? null : districts.list[d].style;
}
// Share of streets left as dead ends at a point: the slider sets it, each district's style scales it.
function deadShareAt(districts, share, x, y) { const st = localStyle(districts, x, y); return st ? share * st.dead / LAB.deadRef : share; }
function traceStreets(field, tiers, water, existing, districts, rng, firstSeeds = []) {
  const hw = FIELD.w / 2, hh = FIELD.h / 2, lines = [];
  // Ramps are crossed by nothing; the expressway only by main roads, on bridges.
  const barrier = new Set(existing.map((l, n) => l.tier === "ramp" ? -1 - n : 0));
  const underpass = new Set(existing.map((l, n) => l.tier === "expressway" ? -1 - n : 0));
  const OCC = 12, occ = new Map(), occKey = (cx, cy) => cx * 100003 + cy;
  const occupy = (line, id) => {
    const pts = line.pts, half = ROADS[line.type].total / 2;
    for (let i = 0; i < pts.length; i++) {
      const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)];
      const l = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1, k = occKey(Math.floor(pts[i][0] / OCC), Math.floor(pts[i][1] / OCC));
      if (!occ.has(k)) occ.set(k, []);
      occ.get(k).push(pts[i][0], pts[i][1], (b[0] - a[0]) / l, (b[1] - a[1]) / l, half, id);
    }
  };
  // 0 clear, 1 crosses steeply, 2 merges or grazes another street.
  const clash = (x, y, tx, ty, half) => {
    const cx = Math.floor(x / OCC), cy = Math.floor(y / OCC); let res = 0;
    for (let dx = -3; dx <= 3; dx++) for (let dy = -3; dy <= 3; dy++) {
      const list = occ.get(occKey(cx + dx, cy + dy)); if (!list) continue;
      for (let i = 0; i < list.length; i += 6) {
        const reach = half + list[i + 4] + 2;
        if ((list[i] - x) ** 2 + (list[i + 1] - y) ** 2 > reach * reach) continue;
        if (barrier.has(list[i + 5]) || (street && underpass.has(list[i + 5]))) return 2;
        if (Math.abs(tx * list[i + 2] + ty * list[i + 3]) > LAB.crossCos) return 2;
        res = 1;
      }
    }
    return res;
  };
  existing.forEach((l, n) => occupy(l, -1 - n));
  let street = false;
  for (const tier of tiers) {
    street = tier.name === "street";
    const spacing = tier.spacing, half = ROADS[tier.type].total / 2;
    const scaleOf = st => (tier.cross ? st.cross : st.sep);
    const sepAt = (x, y) => { const st = tier.name === "street" ? localStyle(districts, x, y) : null; return spacing * (st ? scaleOf(st) : 1); };
    const scales = districts && districts.perStyle && tier.name === "street" ? STYLES.map(scaleOf).filter(v => v > 0) : [1];
    const widest = Math.max(...scales), closest = Math.min(...scales);
    const cell = spacing * widest / 2, taken = new Map();
    const maxBend = FIELD.step / LAB.radius[tier.name], maxTurn = LAB.maxTurn[tier.name] * Math.PI / 180;
    const key = (x, y) => Math.floor(x / cell) * 100003 + Math.floor(y / cell);
    // Where each street runs, cell by cell, so a new one keeps its distance from those it would
    // run alongside but may cross the others.
    const mark = pts => pts.forEach((q, i) => {
      const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)], l = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1, k = key(q[0], q[1]);
      if (!taken.has(k)) taken.set(k, []);
      taken.get(k).push([q[0], q[1], (b[0] - a[0]) / l, (b[1] - a[1]) / l]);
    });
    // The expressway sets no spacing: a road may run beside it, only not into it.
    for (const l of existing.concat(lines)) if (l.tier !== "expressway") mark(l.pts);
    const shore = DRIVE() - 2;
    const land = (x, y) => insideField(x, y) && !water.near(x, y, shore) && (!districts || water.built(x, y)); // streets stay in town
    const dir = (x, y) => { const d = field(x, y); return tier.dir === 0 ? d : [-d[1], d[0]]; };
    const seeds = [];
    const seedStep = spacing * closest;
    for (let x = -hw; x <= hw; x += seedStep) for (let y = -hh; y <= hh; y += seedStep)
      seeds.push([x + rng.f() * seedStep * 0.5, y + rng.f() * seedStep * 0.5]);
    for (let i = seeds.length - 1; i > 0; i--) { const j = rng.int(0, i); [seeds[i], seeds[j]] = [seeds[j], seeds[i]]; }
    for (const f of firstSeeds) if (f.dir === tier.dir) { const q = [f.x, f.y]; q.first = true; seeds.unshift(q); }
    // A street is marked only once it is done, so it never crowds itself.
    const crowded = (x, y, h) => {
      const cx = Math.floor(x / cell), cy = Math.floor(y / cell), r2 = (sepAt(x, y) / 2) ** 2;
      for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) {
        const list = taken.get((cx + dx) * 100003 + cy + dy);
        if (list && list.some(t => (t[0] - x) ** 2 + (t[1] - y) ** 2 < r2 && Math.abs(t[2] * h[0] + t[3] * h[1]) > LAB.parallelCos)) return true;
      }
      return false;
    };
    // Straight across the waterfront drives and the river from (x, y), or null when the far bank
    // is too far or the crossing is too shallow.
    const bridge = (x, y, h) => {
      const out = [], limit = water.riverWidth * LAB.bridgeRun + shore * 2 + FIELD.step;
      let wet = false;
      for (let run = FIELD.step; run <= limit; run += FIELD.step) {
        const bx = x + h[0] * run, by = y + h[1] * run;
        if (!insideField(bx, by) || water.isSea(bx, by)) return null;
        out.push([bx, by]);
        if (water.isRiver(bx, by)) wet = true;
        else if (!water.near(bx, by, shore)) return wet ? out : null;
      }
      return null;
    };
    // A side street stays in the district it starts in; avenues run on through several.
    const confined = districts && tier.name === "street";
    let home = -1;
    // In a grid, as in Manhattan or Barcelona, a street carries on across the boulevard into the
    // next gridded district instead of stopping at it.
    const gridded = d => d >= 0 && districts.list[d].style.grid === 1;
    const ownDistrict = (x, y) => {
      if (!confined) return true;
      const d = districts.at(x, y), wall = districts.isWall(x, y);
      if (d === home && !wall) return true;
      return gridded(home) && (wall || gridded(d));
    };
    const walk = (sx, sy, way) => {
      const pts = []; let x = sx, y = sy, h = dir(x, y); h = [h[0] * way, h[1] * way]; let len = 0, turned = 0;
      while (len < FIELD.maxLen) {
        let nh = dir(x + h[0] * FIELD.step / 2, y + h[1] * FIELD.step / 2);
        if (nh[0] * h[0] + nh[1] * h[1] < 0) nh = [-nh[0], -nh[1]];
        let bend = Math.atan2(h[0] * nh[1] - h[1] * nh[0], h[0] * nh[0] + h[1] * nh[1]);
        const most = pts.length ? maxBend : maxBend / 2; // the two halves of a street meet at its seed
        bend = Math.max(-most, Math.min(most, bend));
        turned += bend;
        if (Math.abs(turned) > maxTurn) break;
        const c = Math.cos(bend), s = Math.sin(bend);
        nh = [h[0] * c - h[1] * s, h[0] * s + h[1] * c];
        const nx = x + nh[0] * FIELD.step, ny = y + nh[1] * FIELD.step;
        const loops = len > FIELD.step * 8 && Math.hypot(nx - sx, ny - sy) < FIELD.step * 2;
        if (loops || crowded(nx, ny, nh)) break;
        if (tier.bridges && water.river && !land(nx, ny) && insideField(nx, ny) && !water.isSea(nx, ny)) {
          const span = bridge(x, y, nh);
          if (!span || span.some(q => clash(q[0], q[1], nh[0], nh[1], half) === 2)) break;
          h = nh;
          pts.push(...span); len += span.length * FIELD.step;
          [x, y] = span[span.length - 1]; continue;
        }
        if (!land(nx, ny) || !ownDistrict(nx, ny) || clash(nx, ny, nh[0], nh[1], half) === 2) break;
        pts.push([nx, ny]); x = nx; y = ny; h = nh; len += FIELD.step;
      }
      return pts;
    };
    for (const s of seeds) {
      const d0 = dir(s[0], s[1]);
      if (!land(s[0], s[1]) || (!s.first && crowded(s[0], s[1], d0))) continue;
      if (confined) { home = districts.at(s[0], s[1]); if (home < 0 || districts.isWall(s[0], s[1])) continue; }
      if (tier.cross && !(districts.perStyle && districts.list[home].style.cross)) continue; // grids have no cross streets
      if (clash(s[0], s[1], d0[0], d0[1], half)) continue;
      const back = walk(s[0], s[1], -1).reverse();
      let pts = back.concat([s], walk(s[0], s[1], 1));
      let chosenDead = false;
      if (tier.deadShare && rng.f() < deadShareAt(districts, tier.deadShare, s[0], s[1])) {
        const keep = Math.floor(pts.length * rng.range(0.3, 0.7));
        pts = rng.f() < 0.5 ? pts.slice(0, keep) : pts.slice(pts.length - keep);
        chosenDead = true;
      }
      if (pts.length * FIELD.step < spacing * 0.6 || pts.length < 4) continue;
      mark(pts);
      const line = { pts, type: tier.type, tier: tier.name, chosenDead };
      occupy(line, lines.length);
      lines.push(line);
    }
  }
  return lines;
}

// ---------- Streets that stop just short of another are carried on to meet it ----------
function joinEnds(lines, reach, deadShare, sideType, mainType, water, rng, districts = null) {
  const SNAP = 5, cell = SNAP * 2, grid = new Map();
  const key = (x, y) => Math.floor(x / cell) * 100003 + Math.floor(y / cell);
  lines.forEach((l, n) => l.pts.forEach((q, i) => { const k = key(q[0], q[1]); if (!grid.has(k)) grid.set(k, []); grid.get(k).push(n, q[0], q[1], i); }));
  const isMain = n => lines[n].tier !== "street";
  const apart = n => GRADE_SEPARATED.has(lines[n].tier);
  // The nearest point of another street within snap, or null. Given a heading, a street met at
  // a shallow angle does not count, so a carried-on street never slides into another.
  const hit = (x, y, own, snap = SNAP, mainOnly = false, hx = 0, hy = 0) => {
    let best = null, bd = snap * snap; const cx = Math.floor(x / cell), cy = Math.floor(y / cell);
    for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) {
      const list = grid.get((cx + dx) * 100003 + cy + dy); if (!list) continue;
      for (let i = 0; i < list.length; i += 4) {
        if (list[i] === own || apart(list[i]) || (mainOnly && !isMain(list[i]))) continue;
        const d = (list[i + 1] - x) ** 2 + (list[i + 2] - y) ** 2;
        if (d >= bd) continue;
        if (hx || hy) {
          const o = lines[list[i]].pts, j = Math.min(list[i + 3], o.length - 1), a = o[Math.max(0, j - 1)], b = o[Math.min(o.length - 1, j + 1)];
          const tl = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
          if (Math.abs((hx * (b[0] - a[0]) + hy * (b[1] - a[1])) / tl) > LAB.crossCos) continue;
        }
        bd = d; best = [list[i + 1], list[i + 2]];
      }
    }
    return best;
  };
  const blocked = (x, y, half) => {
    const cx = Math.floor(x / cell), cy = Math.floor(y / cell);
    for (let dx = -5; dx <= 5; dx++) for (let dy = -5; dy <= 5; dy++) {
      const list = grid.get((cx + dx) * 100003 + cy + dy); if (!list) continue;
      for (let i = 0; i < list.length; i += 4) if (apart(list[i]) && (list[i + 1] - x) ** 2 + (list[i + 2] - y) ** 2 < (ROADS[lines[list[i]].type].total / 2 + half + 2) ** 2) return true;
    }
    return false;
  };
  // Inside the carriageway of another street: 1 when met steeply enough to join it, 2 when not.
  const onStreet = (x, y, own, hx, hy) => {
    const cx = Math.floor(x / cell), cy = Math.floor(y / cell);
    for (let dx = -2; dx <= 2; dx++) for (let dy = -2; dy <= 2; dy++) {
      const list = grid.get((cx + dx) * 100003 + cy + dy); if (!list) continue;
      for (let i = 0; i < list.length; i += 4) {
        if (list[i] === own || apart(list[i])) continue;
        const r = ROADS[lines[list[i]].type].total / 2;
        if ((list[i + 1] - x) ** 2 + (list[i + 2] - y) ** 2 >= r * r) continue;
        const o = lines[list[i]].pts, j = Math.min(list[i + 3], o.length - 1), a = o[Math.max(0, j - 1)], b = o[Math.min(o.length - 1, j + 1)];
        const tl = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
        return Math.abs((hx * (b[0] - a[0]) + hy * (b[1] - a[1])) / tl) > LAB.crossCos ? 2 : 1;
      }
    }
    return 0;
  };
  lines.forEach((l, n) => {
    const pts = l.pts;
    if (apart(n)) return;
    for (const atStart of [true, false]) {
      const main = l.tier === "boulevard" || l.tier === "avenue";
      if (pts.length < 2) continue;
      const e = atStart ? pts[0] : pts[pts.length - 1], inner = atStart ? pts[1] : pts[pts.length - 2];
      const wantsDead = !main && rng.f() < deadShareAt(districts, deadShare, e[0], e[1]);
      if (wantsDead) l.chosenDead = true;
      const len = Math.hypot(e[0] - inner[0], e[1] - inner[1]) || 1, hx = (e[0] - inner[0]) / len, hy = (e[1] - inner[1]) / len;
      let joined = false;
      for (let m = 3; !wantsDead && m <= (main ? reach * 2 : reach); m += 3) {
        const x = e[0] + hx * m, y = e[1] + hy * m;
        if (water.isWater(x, y)) break;
        if (blocked(x, y, ROADS[l.type].total / 2)) break; // a street carried on never runs into the expressway
        const q = hit(x, y, n, SNAP, main, hx, hy);
        const on = q ? 1 : onStreet(x, y, n, hx, hy);
        if (on === 2 && m > 6) break; // would slide into another street at a shallow angle
        if (on === 1 && (q || !main)) { atStart ? pts.unshift([x, y]) : pts.push([x, y]); joined = true; break; }
      }
      const open = !joined && Math.abs(e[0]) < FIELD.w / 2 - 20 && Math.abs(e[1]) < FIELD.h / 2 - 20 && !water.near(e[0], e[1], DRIVE() + 8);
      if (main && open && !l.interchange) narrowTail(l, atStart, n); // the road to the interchange stays
    }
  });
  // A main road ends at another main road, the water or the edge of the map. Past its last
  // crossing with one, a dead-ending main road carries on as an ordinary street; a boulevard steps
  // down through an avenue as far as the next street it meets, so it never narrows at once.
  function narrowTail(l, atStart, n) {
    const pts = l.pts;
    let cut = 0;
    for (let k = 1; k < pts.length && !cut; k++) {
      const i = atStart ? k : pts.length - 1 - k;
      if (hit(pts[i][0], pts[i][1], n, 8, true)) cut = i;
    }
    const bridged = list => list.some(q => water.isRiver(q[0], q[1])); // a bridge stays a main road
    if (!cut) { if (!bridged(pts)) { l.tier = "street"; l.type = sideType; } return; }
    if (bridged(atStart ? pts.slice(0, cut) : pts.slice(cut + 1))) return;
    const tail = atStart ? pts.splice(0, cut) : pts.splice(cut + 1);
    atStart ? tail.push(pts[0]) : tail.unshift(pts[pts.length - 1]);
    if (atStart) tail.reverse(); // from the junction outwards
    let step = 0;
    if (l.tier === "boulevard") for (let k = 3; k < tail.length - 3 && !step; k++) if (hit(tail[k][0], tail[k][1], n, 8)) step = k;
    if (step) { lines.push({ pts: tail.slice(0, step + 1), type: mainType, tier: "avenue" }); tail.splice(0, step); }
    if (tail.length > 2) lines.push({ pts: tail, type: sideType, tier: "street" });
  }
}

// ---------- Dead ends: a cul-de-sac stops clear of every other street ----------
// A street that ends just beside another one, too shallow to meet it, is cut back. Cutting one
// street can strand another that met it, so this runs until nothing changes.
function settleDeadEnds(lines, water) {
  const CELL = 20, key = (x, y) => Math.floor(x / CELL) * 100003 + Math.floor(y / CELL);
  const segDist = (x, y, a, b) => {
    const vx = b[0] - a[0], vy = b[1] - a[1], l2 = vx * vx + vy * vy || 1;
    const t = Math.max(0, Math.min(1, ((x - a[0]) * vx + (y - a[1]) * vy) / l2));
    return Math.hypot(x - a[0] - vx * t, y - a[1] - vy * t);
  };
  let segs;
  const nearest = (q, own) => { // distance from q to the edge of the nearest other street
    let best = Infinity; const cx = Math.floor(q[0] / CELL), cy = Math.floor(q[1] / CELL);
    for (let dx = -3; dx <= 3; dx++) for (let dy = -3; dy <= 3; dy++) {
      const list = segs.get((cx + dx) * 100003 + cy + dy); if (!list) continue;
      for (const [a, b, half, n] of list) if (n !== own) best = Math.min(best, segDist(q[0], q[1], a, b) - half);
    }
    return best;
  };
  const free = e => Math.abs(e[0]) < FIELD.w / 2 - 20 && Math.abs(e[1]) < FIELD.h / 2 - 20 && !water.near(e[0], e[1], DRIVE() + 8);
  for (let round = 0; round < 6; round++) {
    segs = new Map();
    lines.forEach((l, n) => { const half = ROADS[l.type].total / 2;
      for (let i = 0; i < l.pts.length - 1; i++) {
        const a = l.pts[i], b = l.pts[i + 1], k = key((a[0] + b[0]) / 2, (a[1] + b[1]) / 2);
        if (!segs.has(k)) segs.set(k, []); segs.get(k).push([a, b, half, n]);
      } });
    let changed = false;
    lines.forEach((l, n) => {
      if (l.tier === "promenade" || GRADE_SEPARATED.has(l.tier)) return;
      const main = l.tier !== "street";
      for (const atStart of [true, false]) {
        const end = () => atStart ? l.pts[0] : l.pts[l.pts.length - 1];
        if (!free(end()) || nearest(end(), n) < 3) continue;
        // A main road stranded by a cut goes back to its last crossing; a street clears its neighbours.
        const cut = main ? () => nearest(end(), n) >= 3 : () => nearest(end(), n) < LAB.culDeSacGap;
        while (l.pts.length > 1 && cut()) { atStart ? l.pts.shift() : l.pts.pop(); changed = true; }
      }
    });
    // A street that meets nothing at either end is not part of the network: it goes.
    const loose = (l, n) => l.tier === "street" && [l.pts[0], l.pts[l.pts.length - 1]].every(e => free(e) && nearest(e, n) >= 3);
    for (let n = lines.length - 1; n >= 0; n--) if (lines[n].pts.length < 4 || loose(lines[n], n)) { lines.splice(n, 1); changed = true; }
    if (!changed) break;
  }
  lines.forEach((l, n) => {
    l.deadStart = free(l.pts[0]) && nearest(l.pts[0], n) >= 3;
    l.deadEnd = free(l.pts[l.pts.length - 1]) && nearest(l.pts[l.pts.length - 1], n) >= 3;
  });
}

// ---------- The expressway: the cheapest way across the land, then smoothed ----------
// After Galin et al. (2010): a weighted shortest path on a grid, its cost the length plus a
// charge for the dense centre and a heavy one for water, so it skirts the old town and crosses
// the river where it is narrow. Turning costs too, and the path is smoothed to a wide radius.
// The expressway meets no street: other main roads pass over it, side streets end beside it.
function makeExpressway(water, rng) {
  for (let attempt = 0; attempt < 8; attempt++) { const road = expresswayRoute(water, rng); if (road) return road; }
  return null;
}
function expresswayRoute(water, rng) {
  const G = LAB.express.grid, W = Math.ceil(FIELD.w / G) + 1, H = Math.ceil(FIELD.h / G) + 1, ox = -FIELD.w / 2, oy = -FIELD.h / 2;
  const at = (cx, cy) => [ox + cx * G, oy + cy * G];
  const DIRS = [[1, 0], [2, 1], [1, 1], [1, 2], [0, 1], [-1, 2], [-1, 1], [-2, 1], [-1, 0], [-2, -1], [-1, -1], [-1, -2], [0, -1], [1, -2], [1, -1], [2, -1]];
  const cost = new Float32Array(W * H);
  for (let cy = 0; cy < H; cy++) for (let cx = 0; cx < W; cx++) {
    const [x, y] = at(cx, cy), r = Math.hypot(x / (FIELD.w / 2), y / (FIELD.h / 2));
    // the river and its banks both cost, so it crosses square and never runs along the waterfront
    cost[cy * W + cx] = water.isSea(x, y) ? Infinity : 1 + LAB.express.centre * Math.exp(-r * r / 0.15) + (water.near(x, y, LAB.express.bank) ? LAB.express.wet : 0);
  }
  // Enters on one side of the map and leaves on the opposite side, off-centre.
  const vertical = rng.f() < 0.5, off = (rng.f() < 0.5 ? -1 : 1) * rng.range(0.1, 0.25);
  const ends = vertical ? [[Math.round((0.5 + off) * (W - 1)), 0], [Math.round((0.5 + off * rng.range(0.6, 1.2)) * (W - 1)), H - 1]]
    : [[0, Math.round((0.5 + off) * (H - 1))], [W - 1, Math.round((0.5 + off * rng.range(0.6, 1.2)) * (H - 1))]];
  if (ends.some(([cx, cy]) => cost[cy * W + cx] > 1 + LAB.express.centre)) return null; // starts in or by the water
  // A* over (cell, heading); a heading may change by one step of 22.5 degrees at a time.
  const S = W * H * 16, best = new Float64Array(S).fill(Infinity), from = new Int32Array(S).fill(-1);
  const [tx, ty] = ends[1], heap = [];
  const push = (f, s) => { heap.push([f, s]); let i = heap.length - 1; while (i) { const p = (i - 1) >> 1; if (heap[p][0] <= heap[i][0]) break; [heap[p], heap[i]] = [heap[i], heap[p]]; i = p; } };
  const pop = () => { const top = heap[0], last = heap.pop(); if (heap.length) { heap[0] = last; let i = 0;
    for (;;) { const a = i * 2 + 1, b = a + 1; let m = i; if (a < heap.length && heap[a][0] < heap[m][0]) m = a; if (b < heap.length && heap[b][0] < heap[m][0]) m = b; if (m === i) break; [heap[m], heap[i]] = [heap[i], heap[m]]; i = m; } }
    return top; };
  const startDir = vertical ? 4 : 0, s0 = (ends[0][1] * W + ends[0][0]) * 16 + startDir;
  best[s0] = 0; push(0, s0);
  let goal = -1;
  while (heap.length) {
    const [f, s] = pop(), d = s % 16, c = (s - d) / 16, cx = c % W, cy = (c - cx) / W;
    if (f - Math.hypot(tx - cx, ty - cy) * G > best[s] + 1e-6) continue;
    if (cx === tx && cy === ty) { goal = s; break; }
    for (const turn of [-1, 0, 1]) {
      const nd = (d + turn + 16) % 16, [mx, my] = DIRS[nd], nx = cx + mx, ny = cy + my;
      if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
      const step = Math.hypot(mx, my) * G, k = (cost[cy * W + cx] + cost[ny * W + nx]) / 2;
      if (!isFinite(k)) continue;
      const g = best[s] + step * k + (turn ? LAB.express.turn * G : 0), ns = (ny * W + nx) * 16 + nd;
      if (g < best[ns]) { best[ns] = g; from[ns] = s; push(g + Math.hypot(tx - nx, ty - ny) * G, ns); }
    }
  }
  if (goal < 0) return null;
  let pts = [];
  for (let s = goal; s >= 0; s = from[s]) { const c = (s - s % 16) / 16; pts.push(at(c % W, (c - c % W) / W)); }
  pts.reverse();
  // Run on past the edges, smooth to a wide radius, and resample at the field step.
  const lead = (a, b) => [a[0] + (a[0] - b[0]) * 3, a[1] + (a[1] - b[1]) * 3];
  pts = [lead(pts[0], pts[1]), ...pts, lead(pts[pts.length - 1], pts[pts.length - 2])];
  pts = resample(pts, FIELD.step);
  for (let it = 0; it < LAB.express.smooth; it++)
    pts = pts.map((q, i) => i === 0 || i === pts.length - 1 ? q : [(pts[i - 1][0] + q[0] * 2 + pts[i + 1][0]) / 4, (pts[i - 1][1] + q[1] * 2 + pts[i + 1][1]) / 4]);
  pts = resample(pts, FIELD.step).filter(q => Math.abs(q[0]) <= FIELD.w / 2 + 30 && Math.abs(q[1]) <= FIELD.h / 2 + 30);
  if (pts.some(q => water.isSea(q[0], q[1]))) return null;
  return { pts, type: "expressway", tier: "expressway" };
}
// The interchange wants a boulevard across the middle of the expressway, away from the water: a
// boulevard is started there first, in whichever of the two directions crosses it more squarely.
function interchangeSeed(express, field, water) {
  const cum = lineLengths(express), len = cum.at(-1);
  let best = null;
  for (let s = len * 0.3; s <= len * 0.7; s += 20) {
    const q = pointAt(express, cum, s);
    if (Math.abs(q[0]) > FIELD.w / 2 - 250 || Math.abs(q[1]) > FIELD.h / 2 - 250) continue;
    let dry = 400; for (let a = 0; a < 12; a++) for (const r of [100, 200, 300]) if (water.near(q[0] + Math.cos(a * Math.PI / 6) * r, q[1] + Math.sin(a * Math.PI / 6) * r, 0)) dry = Math.min(dry, r);
    const d = field(q[0], q[1]), cross = Math.abs(q[2] * d[1] - q[3] * d[0]), square = Math.max(cross, Math.sqrt(1 - cross * cross));
    const score = dry - Math.abs(s - len / 2) * 0.2 + square * 300;
    if (dry >= 200 && square > 0.85 && (!best || score > best.score)) best = { q, score };
  }
  if (!best) return [];
  const [x, y, tx, ty] = best.q, d = field(x, y), cross = Math.abs(tx * d[1] - ty * d[0]);
  const dir = cross >= Math.SQRT1_2 ? 0 : 1, h = dir === 0 ? d : [-d[1], d[0]];
  return [{ x: x + h[0] * 60, y: y + h[1] * 60, dir }];
}
// A side street never crosses the expressway or a ramp: it is cut where it would, and ends beside it.
function cutAtExpressway(lines) {
  const fast = lines.filter(l => GRADE_SEPARATED.has(l.tier)); if (!fast.length) return;
  const hash = segHash(fast, 20), keep = l => ROADS[l.type].total / 2 + (l.tier === "expressway" ? LAB.culDeSacGap : 10);
  const near = q => { let hit = false; hash.around(q[0], q[1], 2, (m, j) => { if (!hit && segDistT(q[0], q[1], fast[m].pts[j], fast[m].pts[j + 1])[0] < keep(fast[m])) hit = true; }); return hit; };
  for (let n = lines.length - 1; n >= 0; n--) {
    const l = lines[n]; if (l.tier !== "street" || !l.pts.some(near)) continue;
    const runs = []; let cur = [];
    for (const q of l.pts) { if (near(q)) { if (cur.length) runs.push(cur); cur = []; } else cur.push(q); }
    if (cur.length) runs.push(cur);
    lines.splice(n, 1, ...runs.filter(r => r.length >= 4).map(pts => ({ pts, type: l.type, tier: "street" })));
  }
}
// A bend sharper than a street of this design radius allows, by the turn at each point.
function tooTight(pts, R) {
  for (let i = 1; i < pts.length - 1; i++) {
    const a = pts[i - 1], q = pts[i], c = pts[i + 1];
    let d = Math.abs(Math.atan2(c[1] - q[1], c[0] - q[0]) - Math.atan2(q[1] - a[1], q[0] - a[0]));
    if (d > Math.PI) d = 2 * Math.PI - d;
    if (d > (Math.hypot(q[0] - a[0], q[1] - a[1]) + Math.hypot(c[0] - q[0], c[1] - q[1])) / 2 / R * 1.5) return true;
  }
  return false;
}
function resample(pts, step) {
  const out = [pts[0]]; let carry = 0;
  for (let i = 1; i < pts.length; i++) {
    const a = pts[i - 1], b = pts[i], len = Math.hypot(b[0] - a[0], b[1] - a[1]);
    let s = step - carry;
    while (s <= len) { out.push([a[0] + (b[0] - a[0]) * s / len, a[1] + (b[1] - a[1]) * s / len]); s += step; }
    carry = len - (s - step);
  }
  const last = pts[pts.length - 1];
  if (Math.hypot(last[0] - out[out.length - 1][0], last[1] - out[out.length - 1][1]) > step / 3) out.push(last);
  return out;
}

// ---------- One diamond interchange ----------
// Where the expressway passes under a boulevard (an avenue if there are none), four one-lane ramps
// leave and join it, each meeting the boulevard square at a signal. The two signals stand under
// 183 m apart, so this is a tight diamond, the urban kind. Interchanges keep 1.6 km apart, so a
// map this size has one. Crossings by the middle of the expressway are tried first.
function makeInterchange(express, roads, water) {
  const X = LAB.express, ecum = lineLengths(express), elen = ecum.at(-1), cands = [];
  const ehalf = ROADS.expressway.road / 2, rhalf = ROADS.ramp.road / 2;
  const hash = segHash(roads, 20);
  express.pts.forEach((a, i) => { if (i === express.pts.length - 1) return; const b = express.pts[i + 1];
    hash.around((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 1, (m, j) => {
      const road = roads[m]; if (road.tier !== "boulevard" && road.tier !== "avenue") return;
      const c = road.pts[j], d = road.pts[j + 1];
      const rx = b[0] - a[0], ry = b[1] - a[1], sx = d[0] - c[0], sy = d[1] - c[1], den = rx * sy - ry * sx;
      if (Math.abs(den) < 1e-9) return;
      const t = ((c[0] - a[0]) * sy - (c[1] - a[1]) * sx) / den, u = ((c[0] - a[0]) * ry - (c[1] - a[1]) * rx) / den;
      if (t < 0 || t >= 1 || u < 0 || u >= 1) return;
      const el = Math.hypot(rx, ry), cl = Math.hypot(sx, sy), cos = Math.abs((rx * sx + ry * sy) / el / cl);
      if (cos > Math.cos(X.minAngle * Math.PI / 180)) return;
      cands.push({ x: a[0] + rx * t, y: a[1] + ry * t, e: [rx / el, ry / el], c: [sx / cl, sy / cl], road: m, s: ecum[i] + t * el, rank: RANK[road.tier] });
    }); });
  cands.sort((p, q) => q.rank - p.rank || Math.abs(p.s - elen / 2) - Math.abs(q.s - elen / 2));
  // Each crossing is tried at full size, then tighter.
  for (const k of cands) for (const size of LAB.express.sizes) {
    const gore = X.gore * size, terminal = X.terminal * size;
    const n = [-k.e[1], k.e[0]], ramps = [];
    const cr = ROADS[roads[k.road].type].road / 2;
    for (const se of [1, -1]) for (const sn of [1, -1]) {
      const sc = Math.sign(k.c[0] * n[0] * sn + k.c[1] * n[1] * sn) || 1;
      let cn = [-k.c[1], k.c[0]]; if (cn[0] * k.e[0] * se + cn[1] * k.e[1] * se < 0) cn = [-cn[0], -cn[1]];
      // The ramp leaves the expressway alongside it, so it follows the expressway's own bend.
      const beside = (along, d) => { const q = pointAt(express, ecum, k.s + se * along); return [q[0] - q[3] * sn * d, q[1] + q[2] * sn * d]; };
      const P0 = beside(gore, ehalf + rhalf - 2), P1 = beside(gore * 0.45, ehalf + rhalf + 6); // starts on the shoulder
      const P3 = [k.x + k.c[0] * sc * terminal + cn[0] * 1, k.y + k.c[1] * sc * terminal + cn[1] * 1];
      const P2 = [P3[0] + cn[0] * (cr + 40), P3[1] + cn[1] * (cr + 40)];
      const curve = [];
      for (let t = 0; t <= 1.0001; t += 0.02) {
        const u = 1 - t;
        curve.push([u * u * u * P0[0] + 3 * u * u * t * P1[0] + 3 * u * t * t * P2[0] + t * t * t * P3[0], u * u * u * P0[1] + 3 * u * u * t * P1[1] + 3 * u * t * t * P2[1] + t * t * t * P3[1]]);
      }
      ramps.push({ pts: resample(curve, FIELD.step), type: "ramp", tier: "ramp" });
    }
    // Every ramp on dry land and on the map, clear of every road but its own two.
    const ok = ramps.every(r => r.pts.every((q, i) => {
      if (!insideField(q[0], q[1]) || water.near(q[0], q[1], DRIVE() + ROADS.promenade.total / 2 + 4)) return false;
      let clear = true;
      hash.around(q[0], q[1], 2, (m, j) => { if (m === k.road || !clear || roads[m] === express) return; const o = roads[m];
        if (segDistT(q[0], q[1], o.pts[j], o.pts[j + 1])[0] < ROADS.ramp.total / 2 + ROADS[o.type].total / 2) clear = false; });
      return clear;
    }));
    if (ok) { roads[k.road].interchange = true; return { x: k.x, y: k.y, ramps }; }
  }
  return null;
}

// ---------- The road graph: where streets meet ----------
// Each junction is a node; the streets leaving it are its legs. A street that passes through a
// junction gives it two legs, one that ends there gives it one.
const RANK = { street: 0, avenue: 1, promenade: 1, ramp: 1, boulevard: 2 };
const SPEED = { street: 30, avenue: 50, promenade: 40, ramp: 40, boulevard: 60 }; // km/h, for travel times
// Roads that meet no street at grade: the expressway, and its ramps everywhere but their ends.
const GRADE_SEPARATED = new Set(["expressway", "ramp"]);
function lineLengths(l) {
  const c = [0];
  for (let i = 1; i < l.pts.length; i++) c.push(c[i - 1] + Math.hypot(l.pts[i][0] - l.pts[i - 1][0], l.pts[i][1] - l.pts[i - 1][1]));
  return c;
}
// The point s metres along a line, and its heading there.
function pointAt(l, cum, s) {
  s = Math.max(0, Math.min(cum[cum.length - 1], s));
  let i = 0; while (i < cum.length - 2 && cum[i + 1] < s) i++;
  const a = l.pts[i], b = l.pts[i + 1] || a, len = cum[i + 1] - cum[i] || 1, t = (s - cum[i]) / len;
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, (b[0] - a[0]) / len, (b[1] - a[1]) / len];
}
function segHash(lines, cell) {
  const map = new Map(), key = (x, y) => Math.floor(x / cell) * 100003 + Math.floor(y / cell);
  lines.forEach((l, n) => { for (let i = 0; i < l.pts.length - 1; i++) {
    const a = l.pts[i], b = l.pts[i + 1], k = key((a[0] + b[0]) / 2, (a[1] + b[1]) / 2);
    if (!map.has(k)) map.set(k, []); map.get(k).push(n, i);
  } });
  return { map, cell, around(x, y, reach, f) {
    const cx = Math.floor(x / cell), cy = Math.floor(y / cell);
    for (let dx = -reach; dx <= reach; dx++) for (let dy = -reach; dy <= reach; dy++) {
      const list = map.get((cx + dx) * 100003 + cy + dy); if (list) for (let i = 0; i < list.length; i += 2) f(list[i], list[i + 1]);
    }
  } };
}
function segDistT(x, y, a, b) {
  const vx = b[0] - a[0], vy = b[1] - a[1], l2 = vx * vx + vy * vy || 1;
  const t = Math.max(0, Math.min(1, ((x - a[0]) * vx + (y - a[1]) * vy) / l2));
  return [Math.hypot(x - a[0] - vx * t, y - a[1] - vy * t), t];
}
function roadGraph(lines) {
  const cums = lines.map(lineLengths), hash = segHash(lines, 20), raw = [];
  const skip = n => lines[n].tier === "expressway";
  // Crossings of two centrelines.
  lines.forEach((l, n) => { if (skip(n)) return; for (let i = 0; i < l.pts.length - 1; i++) {
    const a = l.pts[i], b = l.pts[i + 1];
    hash.around((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 1, (m, j) => {
      if (m <= n || skip(m)) return;
      const c = lines[m].pts[j], d = lines[m].pts[j + 1];
      const rx = b[0] - a[0], ry = b[1] - a[1], sx = d[0] - c[0], sy = d[1] - c[1], den = rx * sy - ry * sx;
      if (Math.abs(den) < 1e-9) return;
      const t = ((c[0] - a[0]) * sy - (c[1] - a[1]) * sx) / den, u = ((c[0] - a[0]) * ry - (c[1] - a[1]) * rx) / den;
      if (t < 0 || t >= 1 || u < 0 || u >= 1) return;
      const x = a[0] + rx * t, y = a[1] + ry * t, sa = cums[n][i] + t * Math.hypot(rx, ry), sb = cums[m][j] + u * Math.hypot(sx, sy);
      raw.push([x, y, n, sa], [x, y, m, sb]);
    });
  } });
  // A street that ends inside another one's road meets it there.
  lines.forEach((l, n) => { if (skip(n)) return; for (const atStart of [true, false]) {
    const e = atStart ? l.pts[0] : l.pts[l.pts.length - 1], best = new Map();
    hash.around(e[0], e[1], 2, (m, j) => {
      if (m === n || skip(m)) return;
      const o = lines[m], [d, t] = segDistT(e[0], e[1], o.pts[j], o.pts[j + 1]);
      if (d >= ROADS[o.type].total / 2 + 3 || (best.has(m) && best.get(m)[0] <= d)) return;
      best.set(m, [d, j, t]);
    });
    for (const [m, [, j, t]] of best) {
      const o = lines[m], a = o.pts[j], b = o.pts[j + 1], x = a[0] + (b[0] - a[0]) * t, y = a[1] + (b[1] - a[1]) * t;
      raw.push([x, y, m, cums[m][j] + t * (cums[m][j + 1] - cums[m][j])], [x, y, n, atStart ? 0 : cums[n][cums[n].length - 1]]);
    }
  } });
  // Points of one junction lie close together: join them.
  const parent = raw.map((_, i) => i), find = i => { while (parent[i] !== i) i = parent[i] = parent[parent[i]]; return i; };
  const JOIN = 10, pk = (x, y) => Math.floor(x / JOIN) * 100003 + Math.floor(y / JOIN), byCell = new Map();
  raw.forEach((r, i) => { const k = pk(r[0], r[1]); if (!byCell.has(k)) byCell.set(k, []); byCell.get(k).push(i); });
  raw.forEach((r, i) => { const cx = Math.floor(r[0] / JOIN), cy = Math.floor(r[1] / JOIN);
    for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) for (const j of byCell.get((cx + dx) * 100003 + cy + dy) || [])
      if (j > i && Math.hypot(raw[j][0] - r[0], raw[j][1] - r[1]) < JOIN) parent[find(j)] = find(i); });
  const groups = new Map();
  raw.forEach((r, i) => { const g = find(i); if (!groups.has(g)) groups.set(g, []); groups.get(g).push(r); });
  const nodes = [], lineNodes = lines.map(() => []);
  for (const members of groups.values()) {
    const x = members.reduce((a, r) => a + r[0], 0) / members.length, y = members.reduce((a, r) => a + r[1], 0) / members.length;
    const byLine = new Map();
    for (const [, , n, s] of members) if (!byLine.has(n)) byLine.set(n, []), byLine.get(n).push(s); else byLine.get(n).push(s);
    const legs = [], id = nodes.length;
    for (const [n, list] of byLine) {
      const len = cums[n][cums[n].length - 1], s = list.reduce((a, v) => a + v, 0) / list.length;
      for (const sign of [1, -1]) {
        const room = sign > 0 ? len - s : s;
        if (room < 8) continue; // the street ends here
        const p = pointAt(lines[n], cums[n], s + sign * Math.min(15, room));
        const dx = p[0] - x, dy = p[1] - y, dl = Math.hypot(dx, dy) || 1;
        legs.push({ line: n, s, sign, dir: [dx / dl, dy / dl], tier: lines[n].tier, rank: RANK[lines[n].tier] });
      }
      lineNodes[n].push({ s, node: id });
    }
    if (legs.length < 2 || byLine.size < 2) { for (const n of byLine.keys()) lineNodes[n].pop(); continue; }
    legs.sort((a, b) => Math.atan2(a.dir[1], a.dir[0]) - Math.atan2(b.dir[1], b.dir[0]));
    nodes.push({ x, y, legs, rank: Math.max(...legs.map(g => g.rank)) });
  }
  lineNodes.forEach(list => list.sort((a, b) => a.s - b.s));
  // Edges: the stretch of a line between two junctions next to each other on it.
  const edges = [];
  lineNodes.forEach((list, n) => { for (let i = 0; i + 1 < list.length; i++) {
    const len = list[i + 1].s - list[i].s; if (len < 1 || list[i].node === list[i + 1].node) continue;
    edges.push({ a: list[i].node, b: list[i + 1].node, line: n, len, time: len / SPEED[lines[n].tier] });
  } });
  return { nodes, edges, lineNodes, cums };
}
// The smallest angle (degrees) between two legs of a junction next to each other.
function tightestAngle(node) {
  let least = 360; const L = node.legs;
  for (let i = 0; i < L.length; i++) {
    const a = L[i].dir, b = L[(i + 1) % L.length].dir;
    let d = Math.atan2(b[1], b[0]) - Math.atan2(a[1], a[0]); if (d <= 0) d += Math.PI * 2;
    if (L.length > 1) least = Math.min(least, d * 180 / Math.PI);
  }
  return least;
}

// ---------- Staggered junctions: two T junctions just apart on a road become one crossing ----------
// Two side streets meeting a road from opposite sides a few metres apart make drivers zig-zag
// across it. The shorter one is bent over to meet the other, so they cross as one junction.
function alignStaggers(lines, g, water) {
  const moved = new Set(), hash = segHash(lines, 20);
  const tee = node => {
    if (node.legs.length !== 3) return null;
    const through = node.legs.filter(l => node.legs.some(o => o !== l && o.line === l.line));
    const end = node.legs.find(l => !node.legs.some(o => o !== l && o.line === l.line));
    return through.length === 2 && end ? { road: through[0].line, s: through[0].s, end } : null;
  };
  let count = 0, cut = 0;
  g.lineNodes.forEach((list, road) => {
    for (let i = 0; i + 1 < list.length; i++) {
      const A = g.nodes[list[i].node], B = g.nodes[list[i + 1].node], gap = list[i + 1].s - list[i].s;
      if (gap < 2 || gap > LAB.stagger) continue;
      const ta = tee(A), tb = tee(B); if (!ta || !tb || ta.road !== road || tb.road !== road) continue;
      if (moved.has(ta.end.line) || moved.has(tb.end.line) || ta.end.line === tb.end.line) continue;
      const h = pointAt(lines[road], g.cums[road], list[i].s);
      const side = leg => Math.sign(h[2] * leg.dir[1] - h[3] * leg.dir[0]);
      if (side(ta.end) === side(tb.end)) continue;
      const lenA = g.cums[ta.end.line].at(-1), lenB = g.cums[tb.end.line].at(-1);
      const tries = lenA <= lenB ? [[ta.end, A, B], [tb.end, B, A]] : [[tb.end, B, A], [ta.end, A, B]];
      if (tries.some(([mover, from, to]) => bendOver(mover, from, to, road, mover === ta.end ? tb.end.line : ta.end.line))) { count++; continue; }
      // No room to bend either: the shorter one stops short of the road as a cul-de-sac.
      const [mover, from] = tries[0], l = lines[mover.line], keep = ROADS[lines[road].type].total / 2 + LAB.culDeSacGap + ROADS[l.type].total / 2;
      if (l.tier !== "street") continue;
      while (l.pts.length > 1) { const e = mover.sign > 0 ? l.pts[0] : l.pts.at(-1); if (Math.hypot(e[0] - from.x, e[1] - from.y) >= keep) break; mover.sign > 0 ? l.pts.shift() : l.pts.pop(); }
      moved.add(mover.line); cut++;
    }
  });
  return { joined: count, cut };
  // Bends a street's last stretch over so its end lands on the other junction.
  function bendOver(mover, from, to, road, other) {
    const l = lines[mover.line], cum = g.cums[mover.line], atStart = mover.sign > 0;
    const vx = to.x - from.x, vy = to.y - from.y, D = Math.max(60, Math.hypot(vx, vy) * 2.5);
    if (cum.at(-1) < D + 20 || l.tier === "promenade") return false;
    const pts = l.pts.map((q, k) => {
      const d = atStart ? cum[k] : cum.at(-1) - cum[k], w = Math.max(0, 1 - d / D);
      return [q[0] + vx * w, q[1] + vy * w];
    });
    // The bent street must stay clear of every other street away from its new junction.
    const half = ROADS[l.type].total / 2;
    const ok = pts.every((q, k) => {
      const d = atStart ? cum[k] : cum.at(-1) - cum[k];
      if (d > D + 5 || d < 30) return true;
      if (water.isWater(q[0], q[1])) return false;
      let clear = true;
      hash.around(q[0], q[1], 2, (m, j) => {
        const o = lines[m];
        if (m === mover.line || m === road || m === other || !clear || j + 1 >= o.pts.length) return;
        if (segDistT(q[0], q[1], o.pts[j], o.pts[j + 1])[0] < half + ROADS[o.type].total / 2 - 1) clear = false;
      });
      return clear;
    });
    for (let i = 1; i < pts.length - 1; i++) { // no tighter than its class may bend
      const a = pts[i - 1], q = pts[i], c = pts[i + 1];
      let d = Math.abs(Math.atan2(c[1] - q[1], c[0] - q[0]) - Math.atan2(q[1] - a[1], q[0] - a[0])); if (d > Math.PI) d = 2 * Math.PI - d;
      if (d > FIELD.step / (LAB.radius[l.tier] || 40) * 1.5) return false;
    }
    if (!ok) return false;
    l.pts = pts; moved.add(mover.line);
    return true;
  }
}

// ---------- A street that ends at a junction runs right into the middle of it ----------
// So its asphalt always meets the road it joins, with no gap and nothing sticking out beyond.
function snapEnds(lines, g) {
  for (const node of g.nodes) for (const leg of node.legs) {
    const l = lines[leg.line];
    if (node.legs.some(o => o !== leg && o.line === leg.line) || GRADE_SEPARATED.has(l.tier)) continue;
    const atStart = leg.sign > 0, end = atStart ? l.pts[0] : l.pts.at(-1), inner = atStart ? l.pts[1] : l.pts.at(-2);
    // From as far as the half width of the widest road it meets, so an end on a boulevard's kerb reaches too.
    const reach = Math.max(...node.legs.filter(o => o.line !== leg.line).map(o => ROADS[lines[o.line].type].total / 2), 0) + LAB.snapReach;
    if (!inner || Math.hypot(end[0] - node.x, end[1] - node.y) > reach) continue;
    // drop a last point that ran past the middle, then end exactly there
    if (Math.hypot(inner[0] - node.x, inner[1] - node.y) < 4 && l.pts.length > 3) atStart ? l.pts.shift() : l.pts.pop();
    // The shift fades out over the last stretch, so the street bends gently onto the middle.
    const pts = atStart ? l.pts : l.pts.slice().reverse(), dx = node.x - pts[0][0], dy = node.y - pts[0][1];
    const fade = Math.max(LAB.snapFade, Math.hypot(dx, dy) * 4); // a longer move fades out over longer
    for (let i = 0, s = 0; i < pts.length && s < fade; i++) {
      if (i) s += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
      const k = Math.max(0, 1 - s / fade);
      pts[i] = [pts[i][0] + dx * k, pts[i][1] + dy * k];
    }
    l.pts = atStart ? pts : pts.reverse();
    if (dx || dy) { if (atStart) l.deadStart = false; else l.deadEnd = false; }
  }
}

// ---------- Square junctions: a street meeting another at a slant is bent to meet it square ----------
// Junction legs closer than squareAngle make long, blind corners. The street that ends there has
// its last stretch swung round on a curve to meet the road it joins at right angles. Where there
// is no room, a street meeting at under 45 degrees is cut back to a cul-de-sac instead.
function squareUpEnds(lines, g, water) {
  const hash = segHash(lines, 20), done = new Set();
  let bent = 0, cut = 0;
  const legAngle = (a, b) => Math.acos(Math.max(-1, Math.min(1, a.dir[0] * b.dir[0] + a.dir[1] * b.dir[1]))) * 180 / Math.PI;
  for (const node of g.nodes) {
    if (node.legs.length < 2) continue;
    for (const leg of node.legs) {
      const l = lines[leg.line];
      if (l.tier !== "street" || done.has(leg.line) || node.legs.some(o => o !== leg && o.line === leg.line)) continue;
      const worst = Math.min(...node.legs.filter(o => o !== leg).map(o => legAngle(leg, o)));
      if (worst >= LAB.squareAngle) continue;
      const cum = g.cums[leg.line], len = cum.at(-1), atStart = leg.sign > 0;
      const through = node.legs.find(o => o.line !== leg.line && node.legs.some(p => p !== o && p.line === o.line));
      if (through && LAB.squareReach.some(reach => len > reach + 30 && squareUp(l, cum, atStart, lines[through.line], through.line, leg.line, reach))) { bent++; done.add(leg.line); continue; }
      // a side street slanting into a boulevard is worse than a cul-de-sac
      const major = node.legs.some(o => o.line !== leg.line && lines[o.line].tier === "boulevard");
      if (worst >= (major ? 60 : 45)) continue;
      // no room to bend: back off from the junction
      const keep = Math.max(...node.legs.filter(o => o !== leg).map(o => ROADS[lines[o.line].type].total / 2)) + LAB.culDeSacGap + ROADS[l.type].total / 2;
      while (l.pts.length > 1) { const e = atStart ? l.pts[0] : l.pts.at(-1); if (Math.hypot(e[0] - node.x, e[1] - node.y) >= keep) break; atStart ? l.pts.shift() : l.pts.pop(); }
      done.add(leg.line); cut++;
    }
  }
  function squareUp(l, cum, atStart, road, roadId, own, reach) {
    const len = cum.at(-1), from = atStart ? reach : len - reach;
    const P = pointAt(l, cum, from), dir = atStart ? [-P[2], -P[3]] : [P[2], P[3]];
    let best = null;
    for (let j = 0; j < road.pts.length - 1; j++) {
      const [d, t] = segDistT(P[0], P[1], road.pts[j], road.pts[j + 1]);
      if (!best || d < best.d) best = { d, j, q: [road.pts[j][0] + (road.pts[j + 1][0] - road.pts[j][0]) * t, road.pts[j][1] + (road.pts[j + 1][1] - road.pts[j][1]) * t] };
    }
    if (!best || best.d < 15 || best.d > reach * 1.6) return false;
    // Meet a junction already on the road nearby rather than make a staggered pair beside it.
    const junction = g.nodes.filter(o => o.legs.some(lg => lg.line === roadId) && Math.hypot(o.x - best.q[0], o.y - best.q[1]) < LAB.stagger)
      .sort((a, b) => Math.hypot(a.x - best.q[0], a.y - best.q[1]) - Math.hypot(b.x - best.q[0], b.y - best.q[1]))[0];
    const E = junction ? [junction.x, junction.y] : best.q, L = Math.hypot(P[0] - E[0], P[1] - E[1]);
    const a = road.pts[best.j], b = road.pts[best.j + 1], rl = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
    const across = [(a[1] - b[1]) / rl, (b[0] - a[0]) / rl], side = Math.sign((P[0] - E[0]) * across[0] + (P[1] - E[1]) * across[1]);
    const nrm = [across[0] * side, across[1] * side];
    if (L < 15 || dir[0] * (E[0] - P[0]) + dir[1] * (E[1] - P[1]) < 0) return false; // the road lies behind the street
    const P1 = [P[0] + dir[0] * L * 0.5, P[1] + dir[1] * L * 0.5], P2 = [E[0] + nrm[0] * L * 0.5, E[1] + nrm[1] * L * 0.5], curve = [];
    for (let t = 0; t <= 1.0001; t += 0.05) { const u = 1 - t;
      curve.push([u * u * u * P[0] + 3 * u * u * t * P1[0] + 3 * u * t * t * P2[0] + t * t * t * E[0], u * u * u * P[1] + 3 * u * u * t * P1[1] + 3 * u * t * t * P2[1] + t * t * t * E[1]]); }
    const kept = l.pts.filter((q, k) => atStart ? cum[k] > reach : cum[k] < from);
    const tail = resample(curve, FIELD.step);
    const pts = atStart ? tail.reverse().concat(kept) : kept.concat(tail);
    // no tighter than a street may bend, dry, and clear of every other street but the one it meets
    for (let i = 1; i < pts.length - 1; i++) {
      const a = pts[i - 1], q = pts[i], c = pts[i + 1];
      let d = Math.abs(Math.atan2(c[1] - q[1], c[0] - q[0]) - Math.atan2(q[1] - a[1], q[0] - a[0])); if (d > Math.PI) d = 2 * Math.PI - d;
      if (d > FIELD.step / LAB.radius.street * 1.5) return false;
    }
    const half = ROADS[l.type].total / 2;
    for (const q of tail) {
      if (water.isWater(q[0], q[1])) return false;
      if (Math.hypot(q[0] - E[0], q[1] - E[1]) < ROADS[road.type].total / 2 + half + 2) continue;
      let clear = true;
      hash.around(q[0], q[1], 2, (m, j) => { const o = lines[m]; if (m === own || m === roadId || !clear || j + 1 >= o.pts.length) return; // a street cut back since
        if (segDistT(q[0], q[1], o.pts[j], o.pts[j + 1])[0] < half + ROADS[o.type].total / 2 - 1) clear = false; });
      if (!clear) return false;
    }
    l.pts = pts;
    return true;
  }
  return { bent, cut };
}

// ---------- Road classes from traffic: busy side streets become avenues ----------
// Trips from home to work run on the quickest way through the graph. How many pass along each
// stretch is its load (edge betweenness, sampled from some of the junctions). A side street that
// carries as much as an avenue, joins main roads at both ends and has room to widen is made one.
function trafficLoads(g, rng) {
  const V = g.nodes.length, adj = Array.from({ length: V }, () => []);
  g.edges.forEach((e, i) => { adj[e.a].push(i); adj[e.b].push(i); });
  const load = new Float64Array(g.edges.length);
  const sources = [...Array(V).keys()];
  for (let i = sources.length - 1; i > 0; i--) { const j = rng.int(0, i); [sources[i], sources[j]] = [sources[j], sources[i]]; }
  const dist = new Float64Array(V), sigma = new Float64Array(V), delta = new Float64Array(V), preds = Array.from({ length: V }, () => []);
  for (const src of sources.slice(0, Math.min(V, LAB.trafficSources))) {
    dist.fill(Infinity); sigma.fill(0); delta.fill(0); preds.forEach(p => p.length = 0);
    dist[src] = 0; sigma[src] = 1;
    const heap = [[0, src]], order = [];
    const push = item => { heap.push(item); let i = heap.length - 1; while (i) { const p = (i - 1) >> 1; if (heap[p][0] <= heap[i][0]) break; [heap[p], heap[i]] = [heap[i], heap[p]]; i = p; } };
    const pop = () => { const top = heap[0], last = heap.pop(); if (heap.length) { heap[0] = last; let i = 0;
      for (;;) { const a = i * 2 + 1, b = a + 1; let m = i; if (a < heap.length && heap[a][0] < heap[m][0]) m = a; if (b < heap.length && heap[b][0] < heap[m][0]) m = b; if (m === i) break; [heap[m], heap[i]] = [heap[i], heap[m]]; i = m; } }
      return top; };
    while (heap.length) {
      const [d, v] = pop(); if (d > dist[v]) continue;
      order.push(v);
      for (const ei of adj[v]) {
        const e = g.edges[ei], w = e.a === v ? e.b : e.a, nd = d + e.time;
        if (nd < dist[w] - 1e-9) { dist[w] = nd; sigma[w] = sigma[v]; preds[w] = [[v, ei]]; push([nd, w]); }
        else if (Math.abs(nd - dist[w]) <= 1e-9) { sigma[w] += sigma[v]; preds[w].push([v, ei]); }
      }
    }
    for (let k = order.length - 1; k >= 0; k--) {
      const w = order[k];
      for (const [v, ei] of preds[w]) { const c = sigma[v] / sigma[w] * (1 + delta[w]); load[ei] += c; delta[v] += c; }
    }
  }
  return load;
}
function classifyByTraffic(lines, g, mainType, rng) {
  const load = trafficLoads(g, rng), lineLoad = lines.map(() => [0, 0]);
  g.edges.forEach((e, i) => { lineLoad[e.line][0] += load[i] * e.len; lineLoad[e.line][1] += e.len; });
  const mean = lines.map((_, n) => lineLoad[n][1] ? lineLoad[n][0] / lineLoad[n][1] : 0);
  lines.forEach((l, n) => { l.load = mean[n]; });
  const avenueLoads = lines.map((l, n) => l.tier === "avenue" ? mean[n] : -1).filter(v => v >= 0).sort((a, b) => a - b);
  const streetKm = lines.reduce((a, l, n) => a + (l.tier === "street" ? g.cums[n].at(-1) : 0), 0);
  const bar = avenueLoads.length ? avenueLoads[avenueLoads.length >> 1] * LAB.upgradeShare : Infinity;
  const hash = segHash(lines, 20), half = ROADS[mainType].total / 2;
  const meetsMain = node => node && node.legs.some(l => l.rank >= 1);
  const endNode = n => [g.lineNodes[n][0], g.lineNodes[n].at(-1)].map(e => e && g.nodes[e.node]);
  const roomy = n => {
    const l = lines[n], near = new Set(g.lineNodes[n].map(e => e.node));
    // bends no tighter than an avenue may
    for (let i = 1; i < l.pts.length - 1; i++) {
      const a = l.pts[i - 1], q = l.pts[i], c = l.pts[i + 1];
      let d = Math.abs(Math.atan2(c[1] - q[1], c[0] - q[0]) - Math.atan2(q[1] - a[1], q[0] - a[0])); if (d > Math.PI) d = 2 * Math.PI - d;
      if (d > FIELD.step / LAB.radius.avenue * 1.5) return false;
    }
    return l.pts.every(q => {
      if ([...near].some(id => Math.hypot(g.nodes[id].x - q[0], g.nodes[id].y - q[1]) < 45)) return true;
      let ok = true;
      hash.around(q[0], q[1], 2, (m, j) => {
        if (m === n || !ok) return;
        const o = lines[m];
        if (segDistT(q[0], q[1], o.pts[j], o.pts[j + 1])[0] < half + ROADS[o.type].total / 2 + 2) ok = false;
      });
      return ok;
    });
  };
  const order = lines.map((_, n) => n).filter(n => lines[n].tier === "street" && mean[n] >= bar).sort((a, b) => mean[b] - mean[a]);
  let km = 0, count = 0;
  for (const n of order) {
    const l = lines[n], len = g.cums[n].at(-1);
    if (l.deadStart || l.deadEnd || len < LAB.upgradeLength || km + len > streetKm * LAB.upgradeMax) continue;
    const [a, b] = endNode(n);
    if (!meetsMain(a) || !meetsMain(b) || !roomy(n)) continue;
    l.tier = "avenue"; l.type = mainType; l.upgraded = true; km += len; count++;
  }
  g.nodes.forEach(node => { node.legs.forEach(leg => { leg.tier = lines[leg.line].tier; leg.rank = RANK[leg.tier]; }); node.rank = Math.max(...node.legs.map(l => l.rank)); });
  return count;
}

// ---------- The player's roundabouts ----------
// Away from any junction, the road under the click is cut there, so the roundabout has a node to
// sit on; two legs of one road, like a roundabout calming a long straight.
function placeRoundabouts(lines, list) {
  let g = roadGraph(lines), cut = false;
  for (const r of list) {
    if (!r.on || g.nodes.some(n => Math.hypot(n.x - r.x, n.y - r.y) < LAB.userReach)) continue;
    let best = null;
    lines.forEach((l, n) => { if (GRADE_SEPARATED.has(l.tier) || l.tier === "promenade") return;
      for (let j = 0; j < l.pts.length - 1; j++) { const [d, t] = segDistT(r.x, r.y, l.pts[j], l.pts[j + 1]); if (d < LAB.roadReach && (!best || d < best.d)) best = { d, n, j, t }; } });
    if (!best) continue;
    const l = lines[best.n], a = l.pts[best.j], b = l.pts[best.j + 1], q = [a[0] + (b[0] - a[0]) * best.t, a[1] + (b[1] - a[1]) * best.t];
    const head = l.pts.slice(0, best.j + 1).concat([q]), tail = [q].concat(l.pts.slice(best.j + 1));
    if (lineLengths({ pts: head }).at(-1) < 30 || lineLengths({ pts: tail }).at(-1) < 30) continue;
    lines.splice(best.n, 1, { ...l, pts: head, deadEnd: false }, { ...l, pts: tail, deadStart: false });
    cut = true;
  }
  if (cut) g = roadGraph(lines);
  return g;
}
function blockAt(grid, x, y) {
  const cx = Math.floor((x - grid.ox) / grid.cell), cy = Math.floor((y - grid.oy) / grid.cell);
  return cx < 0 || cy < 0 || cx >= grid.W || cy >= grid.H ? WATER : grid.labels[cy * grid.W + cx];
}

// ---------- Paths for people on foot ----------
// Blocks longer than about 200 m get a passage through the middle, street to street, as walkable
// city codes ask for every 100 m or so of frontage (VTA; San Leandro: about 120 m at most).
function midBlockPassages(lines, grid, uses) {
  const { W, H, ox, oy, cell, labels } = grid, out = [], cells = new Map();
  grid.blocks.forEach((b, i) => { if ((uses[i] === HOMES || uses[i] === OFFICES || uses[i] === PUBLIC) && b.area >= LAB.passageArea) cells.set(i, []); });
  for (let i = 0; i < labels.length; i++) { const list = cells.get(labels[i]); if (list) list.push(i); }
  const labelAt = (x, y) => { const cx = Math.floor((x - ox) / cell), cy = Math.floor((y - oy) / cell);
    return cx < 0 || cy < 0 || cx >= W || cy >= H ? WATER : labels[cy * W + cx]; };
  for (const [i, list] of cells) {
    let c = 0, mx = 0, my = 0, vxx = 0, vyy = 0, vxy = 0;
    for (const k of list) { const x = k % W, y = (k - x) / W; c++; mx += x; my += y; }
    mx /= c; my /= c;
    for (const k of list) { const x = k % W - mx, y = (k - k % W) / W - my; vxx += x * x; vyy += y * y; vxy += x * y; }
    const long = 0.5 * Math.atan2(2 * vxy, vxx - vyy), lx = Math.cos(long), ly = Math.sin(long);
    const spread = Math.sqrt(Math.max(0, (vxx * lx * lx + 2 * vxy * lx * ly + vyy * ly * ly) / c)) * cell;
    if (spread * Math.sqrt(12) < LAB.passageAt) continue; // a rectangle's length is its spread times the root of 12
    const x0 = ox + (mx + 0.5) * cell, y0 = oy + (my + 0.5) * cell;
    if (labelAt(x0, y0) !== i) continue;
    const ends = [1, -1].map(sg => { let t = 0; while (labelAt(x0 - ly * sg * t, y0 + lx * sg * t) === i && t < 400) t += 1;
      const l = labelAt(x0 - ly * sg * t, y0 + lx * sg * t); return l === SIDE_ROAD || l === MAIN_ROAD ? [x0 - ly * sg * (t + 1), y0 + lx * sg * (t + 1)] : null; });
    if (ends[0] && ends[1]) out.push({ pts: [ends[0], ends[1]], width: LAB.passageWidth, kind: "passage" });
  }
  return out;
}
// Paths through a park join its entrances, as people walk them: from every junction and
// cul-de-sac at its edge, through a small square near the middle (desire lines). The main path
// is 3 m wide, the others 2 m (shared-use and access guidance: 1.7 to 3 m).
function parkPaths(lines, g, grid, uses) {
  const { W, ox, oy, cell, labels } = grid, out = [];
  const near = new Map();
  grid.blocks.forEach((b, i) => { if (uses[i] === PARK && b.area >= LAB.pathPark) near.set(i, []); });
  if (!near.size) return out;
  const ring = (x, y, r, f) => { for (let a = 0; a < 24; a++) f(x + Math.cos(a / 24 * Math.PI * 2) * r, y + Math.sin(a / 24 * Math.PI * 2) * r); };
  // Entrances: junctions and dead ends beside the park, stepped just inside it.
  const doors = g.nodes.map(n => [n.x, n.y, Math.max(...n.legs.map(l => ROADS[lines[l.line].type].total / 2))]);
  for (const l of lines) for (const [dead, e] of [[l.deadStart, l.pts[0]], [l.deadEnd, l.pts.at(-1)]]) if (dead) doors.push([e[0], e[1], ROADS[l.type].total / 2 * LAB.bulb]);
  for (const [x, y, r] of doors) {
    const seen = new Set();
    ring(x, y, r + 5, (px, py) => { const b = blockAt(grid, px, py); if (near.has(b) && !seen.has(b)) { seen.add(b); near.get(b).push([px, py]); } });
  }
  for (const [i, list] of near) {
    if (list.length < 2) continue;
    // The hub: the park's own cell nearest its middle.
    const b = grid.blocks[i];
    let hub = null, bd = Infinity;
    for (const n of b.samples) { const x = ox + (n % W + 0.5) * cell, y = oy + (Math.floor(n / W) + 0.5) * cell, d = (x - b.x) ** 2 + (y - b.y) ** 2; if (d < bd) { bd = d; hub = [x, y]; } }
    const inside = pts => pts.every(q => blockAt(grid, q[0], q[1]) === i);
    // Entrances far apart, the two farthest joined by the main path.
    // At most a few entrances, spread round the park: each next one the farthest from those taken.
    const doorsHere = [list[0]];
    while (doorsHere.length < LAB.maxDoors) {
      let pick = null, pd = LAB.doorGap;
      for (const q of list) { const d = Math.min(...doorsHere.map(o => Math.hypot(o[0] - q[0], o[1] - q[1]))); if (d > pd) { pd = d; pick = q; } }
      if (!pick) break;
      doorsHere.push(pick);
    }
    if (doorsHere.length < 2) continue;
    out.push({ hub, r: Math.min(10, Math.sqrt(b.area) / 12), kind: "plaza" });
    let far = [0, 1], fd = 0;
    doorsHere.forEach((p0, k) => doorsHere.forEach((p1, m) => { const d = Math.hypot(p0[0] - p1[0], p0[1] - p1[1]); if (d > fd) { fd = d; far = [k, m]; } }));
    doorsHere.forEach((q, k) => {
      // A gentle curve from the door to the hub, bowed a little to one side.
      const mx = (q[0] + hub[0]) / 2, my = (q[1] + hub[1]) / 2, len = Math.hypot(hub[0] - q[0], hub[1] - q[1]) || 1;
      const bow = ((k % 2) ? 1 : -1) * len * 0.12, ctrl = [mx - (hub[1] - q[1]) / len * bow, my + (hub[0] - q[0]) / len * bow];
      const curve = [];
      for (let t = 0; t <= 1.0001; t += 0.1) { const u = 1 - t; curve.push([u * u * q[0] + 2 * u * t * ctrl[0] + t * t * hub[0], u * u * q[1] + 2 * u * t * ctrl[1] + t * t * hub[1]]); }
      const pts = inside(curve.slice(1)) ? curve : [q, hub];
      if (inside(pts.slice(1))) out.push({ pts, width: far.includes(k) ? 3 : 2, kind: "path" });
    });
  }
  return out;
}
// Street trees in the furnishing strip by the kerb, one every 15 m, where the sidewalk leaves a
// 1.8 m clear path and a strip of 1.2 m or more for the tree (sidewalk zone guidance).
function streetTrees(lines, g, grid) {
  const out = [];
  for (const l of lines) {
    const road = ROADS[l.type];
    if (GRADE_SEPARATED.has(l.tier) || road.walk - LAB.clearPath < LAB.treeStrip) continue;
    const cum = lineLengths(l), len = cum.at(-1), off = road.road / 2 + LAB.treeStrip / 2 + 0.3;
    for (let s = LAB.treeEvery / 2; s < len; s += LAB.treeEvery) {
      const q = pointAt(l, cum, s);
      if (g.nodes.some(n => Math.abs(n.x - q[0]) < 30 && Math.abs(n.y - q[1]) < 30 && Math.hypot(n.x - q[0], n.y - q[1]) < road.total / 2 + 14)) continue;
      for (const side of [1, -1]) {
        const x = q[0] - q[3] * off * side, y = q[1] + q[2] * off * side;
        if (blockAt(grid, x - q[3] * side * road.walk, y + q[2] * side * road.walk) !== WATER) out.push([x, y, 2.2]);
      }
    }
  }
  return out;
}

// ---------- How each junction is run ----------
// By the two most important roads that meet there (Sustainable Safety: a road meets only its own
// class or the class next to it). A side street never cuts across a boulevard: the median runs
// on and it may turn right in and out only. Avenues meeting avenues get a roundabout where the
// streets meet at odd angles or in a winding district, if it fits; boulevards get signals.
function junctionControls(lines, g, districts, water, rng, user = []) {
  // The player's word comes first: a roundabout placed, or one taken away.
  const want = new Map();
  for (const r of user) {
    let best = null, bd = LAB.userReach;
    for (const node of g.nodes) { const d = Math.hypot(node.x - r.x, node.y - r.y); if (d < bd) { bd = d; best = node; } }
    if (best) want.set(best, r.on);
  }
  const order = g.nodes.map((_, i) => i).sort((a, b) => want.has(g.nodes[b]) - want.has(g.nodes[a]) || g.nodes[b].rank - g.nodes[a].rank);
  const discs = [];
  const styleAt = node => {
    for (const [dx, dy] of [[0, 0], [25, 25], [-25, 25], [25, -25], [-25, -25]]) { const d = districts.at(node.x + dx, node.y + dy); if (d >= 0) return districts.list[d].style.id; }
    return "planned_grid";
  };
  const fast = segHash(lines.map(l => GRADE_SEPARATED.has(l.tier) ? l : { pts: [] }), 20);
  const overFast = (node, R) => { let hit = false; fast.around(node.x, node.y, 3, (m, j) => {
    if (!hit && segDistT(node.x, node.y, lines[m].pts[j], lines[m].pts[j + 1])[0] < R + ROADS[lines[m].type].total / 2) hit = true; }); return hit; };
  const roomFor = (node, R) => {
    if (overFast(node, R)) return false;
    if (discs.some(d => Math.hypot(d.x - node.x, d.y - node.y) < d.R + R + LAB.roundaboutGap)) return false;
    if (g.nodes.some(o => o !== node && Math.hypot(o.x - node.x, o.y - node.y) < R + 25)) return false;
    for (let a = 0; a < 16; a++) if (water.near(node.x + Math.cos(a / 16 * Math.PI * 2) * R, node.y + Math.sin(a / 16 * Math.PI * 2) * R, 6)) return false;
    // every leg runs on past the circle before it ends
    return node.legs.every(leg => { const len = g.cums[leg.line].at(-1), room = leg.sign > 0 ? len - leg.s : leg.s; return room > R + 20; });
  };
  for (const id of order) {
    const node = g.nodes[id];
    const ranksByLine = [...new Set(node.legs.map(l => l.line))].map(n => RANK[lines[n].tier]).sort((a, b) => b - a);
    const first = ranksByLine[0], next = ranksByLine[1] ?? 0;
    const odd = node.legs.length >= 5 || tightestAngle(node) < LAB.squareAngle;
    const winding = styleAt(node) === "compact_organic" || styleAt(node) === "winding_old";
    const maxRoad = Math.max(...node.legs.map(l => ROADS[lines[l.line].type].road));
    let control;
    if (first === 2 && next === 0) control = "riro";
    else if (first === 2) control = "signal";
    else if (first === 1 && next === 1) control = odd || winding || rng.f() < LAB.roundaboutChance ? "roundabout" : "signal";
    else if (first === 1) control = "stop";
    else control = odd ? "roundabout" : node.legs.length === 3 ? "yield" : "allstop";
    if (first === 2 && next === 2 && odd) control = "roundabout";
    if (node.legs.length < 3) control = "bend"; // two streets running on into each other
    const forced = want.get(node);
    if (forced === true) control = "roundabout";
    if (forced === false && control === "roundabout") control = first === 0 ? (node.legs.length === 3 ? "yield" : "allstop") : "signal";
    if (control === "roundabout") {
      const R = Math.max(LAB.roundabout[forced ? Math.max(first, 1) : first] / 2, maxRoad / 2 + 4);
      if (forced ? !overFast(node, R) : roomFor(node, R)) { node.R = R; node.island = first === 0 ? LAB.miniIsland : R - (first === 2 ? 10 : 6); discs.push({ x: node.x, y: node.y, R, walk: Math.max(...node.legs.map(l => ROADS[lines[l.line].type].walk)) }); }
      else control = first === 0 ? (node.legs.length === 3 ? "yield" : "allstop") : "signal";
    }
    node.control = control;
  }
  return discs;
}

// ---------- Crossings and stop lines ----------
// Signals and roundabouts get a zebra on every leg (at a roundabout one car length back from the
// circle), junctions with a main road on every leg, side-street junctions none. A long main road
// gets mid-block crossings by parks, schools and shops, and in any case at most every few hundred
// metres, never within 60 m of another crossing.
function crossingsAndLines(lines, g, grid, uses, water) {
  const crossings = [], bars = [];
  const road = n => ROADS[lines[n].type];
  const legPoint = (leg, d) => pointAt(lines[leg.line], g.cums[leg.line], leg.s + leg.sign * d);
  const room = leg => { const len = g.cums[leg.line].at(-1), list = g.lineNodes[leg.line];
    const here = list.findIndex(e => Math.abs(e.s - leg.s) < 1); const next = list[here + leg.sign];
    return next ? Math.abs(next.s - leg.s) : (leg.sign > 0 ? len - leg.s : leg.s); };
  const byLine = lines.map(() => []), owner = lines.map(() => []);
  const add = (leg, d, kind, node) => {
    const p = legPoint(leg, d), at = leg.s + leg.sign * d;
    if (water.near(p[0], p[1], 2)) return;
    // two junctions close together share their crossings rather than stack them up
    if (owner[leg.line].some(([v, o]) => o !== node && Math.abs(v - at) < LAB.crossingGap / 2)) return;
    owner[leg.line].push([at, node]);
    const r = road(leg.line);
    crossings.push({ x: p[0], y: p[1], tx: p[2], ty: p[3], w: r.road, line: leg.line, kind, node });
    byLine[leg.line].push(leg.s + leg.sign * d);
  };
  const busiest = { signal: 0, roundabout: 1, riro: 2, stop: 3 };
  for (const node of g.nodes.slice().sort((a, b) => (busiest[a.control] ?? 9) - (busiest[b.control] ?? 9))) {
    const c = node.control, all = c === "signal" || c === "stop" || (c === "roundabout" && node.R > 12);
    for (const leg of node.legs) {
      const others = node.legs.filter(o => o.line !== leg.line), r = road(leg.line);
      const box = others.length ? Math.max(...others.map(o => road(o.line).road / 2)) : 0;
      const d = c === "roundabout" ? node.R + LAB.carLength : box + 3;
      if (room(leg) < d + 12) continue;
      const zebra = all || (c === "riro" && leg.rank === 0);
      if (zebra) add(leg, d, "junction", node);
      const bar = c === "roundabout" ? node.R + 0.5 : d + (zebra ? 2.5 : 0);
      const stopHere = c === "signal" || c === "allstop" || c === "roundabout" || c === "yield" && node.legs.filter(o => o.line === leg.line).length === 1
        || (c === "stop" || c === "riro") && leg.rank === 0;
      if (stopHere && !r.shared) {
        const p = legPoint(leg, bar), tx = -leg.sign * p[2], ty = -leg.sign * p[3]; // the way traffic comes in
        if (water.near(p[0], p[1], 2)) continue;
        const rx = ty, ry = -tx, from = r.oneWay ? -r.road / 2 : r.median / 2;
        bars.push({ a: [p[0] + rx * from, p[1] + ry * from], b: [p[0] + rx * r.road / 2, p[1] + ry * r.road / 2], give: c === "roundabout" || c === "yield" });
      }
    }
  }
  // Mid-block crossings on main roads.
  const blockUse = (x, y) => { const cx = Math.floor((x - grid.ox) / grid.cell), cy = Math.floor((y - grid.oy) / grid.cell);
    if (cx < 0 || cy < 0 || cx >= grid.W || cy >= grid.H) return -9; const l = grid.labels[cy * grid.W + cx]; return l >= 0 ? uses[l] : -9; };
  lines.forEach((l, n) => {
    if (l.tier === "street" || GRADE_SEPARATED.has(l.tier)) return;
    const len = g.cums[n].at(-1), r = road(n), nodesOn = g.lineNodes[n].map(e => e.s);
    const free = s => byLine[n].every(v => Math.abs(v - s) >= LAB.crossingGap) && nodesOn.every(v => Math.abs(v - s) >= 25);
    const draw = s => { const p = pointAt(l, g.cums[n], s); if (water.near(p[0], p[1], 4)) return false;
      crossings.push({ x: p[0], y: p[1], tx: p[2], ty: p[3], w: r.road, line: n, kind: "mid" }); byLine[n].push(s); return true; };
    for (let s = 40; s < len - 40; s += 10) {
      if (!free(s)) continue;
      const p = pointAt(l, g.cums[n], s), off = r.total / 2 + 6;
      const sides = [blockUse(p[0] - p[3] * off, p[1] + p[2] * off), blockUse(p[0] + p[3] * off, p[1] - p[2] * off)];
      const draws = sides.some(u => u === PARK || u === PUBLIC || u === SQUARE) || sides.every(u => u === OFFICES);
      const far = byLine[n].every(v => Math.abs(v - s) >= LAB.crossingEvery);
      if ((draws && byLine[n].every(v => Math.abs(v - s) >= LAB.crossingEvery / 2)) || far) draw(s);
    }
  });
  return { crossings, bars };
}

// ---------- Blocks: paint water and streets on a grid, fill what they enclose ----------
const EMPTY = -9, VERGE = -5, WATER = -4, MAIN_ROAD = -2, SIDE_ROAD = -1;
function findBlocks(lines, water, discs, rng) {
  const cell = LAB.cell, W = Math.ceil(FIELD.w / cell), H = Math.ceil(FIELD.h / cell);
  const ox = -FIELD.w / 2, oy = -FIELD.h / 2;
  // The water stays put while the streets change, so its cells are worked out once per map.
  if (!water.cells) {
    water.cells = new Uint8Array(W * H);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) water.cells[y * W + x] = water.isWater(ox + (x + 0.5) * cell, oy + (y + 0.5) * cell) ? 1 : 0;
  }
  const labels = new Int32Array(W * H).fill(EMPTY);
  for (let i = 0; i < W * H; i++) if (water.cells[i]) labels[i] = WATER;
  const length = {};
  // The expressway's planted verge: no one builds there and no block runs on along it, so the side
  // streets that stop short of it still close their blocks.
  for (const l of lines) {
    if (l.tier !== "expressway") continue;
    const r = (ROADS[l.type].total / 2 + LAB.noiseBuffer) / cell, reach = Math.ceil(r);
    for (let n = 0; n < l.pts.length - 1; n++) {
      const ax = (l.pts[n][0] - ox) / cell, ay = (l.pts[n][1] - oy) / cell, bx = (l.pts[n + 1][0] - ox) / cell, by = (l.pts[n + 1][1] - oy) / cell;
      const steps = Math.max(1, Math.ceil(Math.hypot(bx - ax, by - ay)));
      for (let k = 0; k <= steps; k++) {
        const px = ax + (bx - ax) * k / steps, py = ay + (by - ay) * k / steps, cx = Math.floor(px), cy = Math.floor(py);
        for (let y = Math.max(cy - reach, 0); y < Math.min(cy + reach + 1, H); y++)
          for (let x = Math.max(cx - reach, 0); x < Math.min(cx + reach + 1, W); x++) {
            const i = y * W + x;
            if (labels[i] === EMPTY && (px - x - 0.5) ** 2 + (py - y - 0.5) ** 2 <= r * r) labels[i] = VERGE;
          }
      }
    }
  }
  const sorted = lines.slice().sort((a, b) => ROADS[a.type].total - ROADS[b.type].total);
  for (const l of sorted) {
    const road = ROADS[l.type], r = road.total / 2 / cell, reach = Math.ceil(r);
    const kind = l.tier === "street" ? SIDE_ROAD : MAIN_ROAD;
    const pts = l.pts;
    for (let n = 0; n < pts.length - 1; n++) {
      const ax = (pts[n][0] - ox) / cell, ay = (pts[n][1] - oy) / cell, bx = (pts[n + 1][0] - ox) / cell, by = (pts[n + 1][1] - oy) / cell;
      const seg = Math.hypot(pts[n + 1][0] - pts[n][0], pts[n + 1][1] - pts[n][1]);
      length[l.tier] = (length[l.tier] || 0) + seg;
      const steps = Math.max(1, Math.ceil(Math.hypot(bx - ax, by - ay)));
      for (let s = 0; s <= steps; s++) {
        const px = ax + (bx - ax) * s / steps, py = ay + (by - ay) * s / steps, cx = Math.floor(px), cy = Math.floor(py);
        for (let y = Math.max(cy - reach, 0); y < Math.min(cy + reach + 1, H); y++)
          for (let x = Math.max(cx - reach, 0); x < Math.min(cx + reach + 1, W); x++) {
            const i = y * W + x;
            if (labels[i] !== WATER && (px - x - 0.5) ** 2 + (py - y - 0.5) ** 2 <= r * r) labels[i] = kind;
          }
      }
    }
  }
  // Turning circles at dead ends, one and a half times the street's width.
  for (const l of lines) for (const [dead, e] of [[l.deadStart, l.pts[0]], [l.deadEnd, l.pts[l.pts.length - 1]]]) {
    if (!dead) continue;
    const r = ROADS[l.type].total / 2 * LAB.bulb / cell, cx = (e[0] - ox) / cell, cy = (e[1] - oy) / cell;
    for (let y = Math.max(0, Math.floor(cy - r)); y <= Math.min(H - 1, Math.ceil(cy + r)); y++)
      for (let x = Math.max(0, Math.floor(cx - r)); x <= Math.min(W - 1, Math.ceil(cx + r)); x++) {
        const i = y * W + x;
        if (labels[i] === EMPTY && (cx - x - 0.5) ** 2 + (cy - y - 0.5) ** 2 <= r * r) labels[i] = SIDE_ROAD;
      }
  }
  // Roundabouts and their sidewalks.
  for (const d of discs) {
    const r = (d.R + d.walk) / cell, cx = (d.x - ox) / cell, cy = (d.y - oy) / cell;
    for (let y = Math.max(0, Math.floor(cy - r)); y <= Math.min(H - 1, Math.ceil(cy + r)); y++)
      for (let x = Math.max(0, Math.floor(cx - r)); x <= Math.min(W - 1, Math.ceil(cx + r)); x++) {
        const i = y * W + x;
        if (labels[i] !== WATER && (cx - x - 0.5) ** 2 + (cy - y - 0.5) ** 2 <= r * r) labels[i] = MAIN_ROAD;
      }
  }
  const blocks = [], stack = new Int32Array(W * H);
  for (let i = 0; i < labels.length; i++) {
    if (labels[i] !== EMPTY) continue;
    const id = blocks.length, samples = []; let top = 0, cells = 0, sx = 0, sy = 0, main = false, edge = false, shore = false;
    stack[top++] = i; labels[i] = id;
    while (top) {
      const n = stack[--top], x = n % W, y = (n - x) / W;
      cells++; sx += x + 0.5; sy += y + 0.5;
      if (samples.length < 60) samples.push(n); else { const j = Math.floor(rng.f() * cells); if (j < 60) samples[j] = n; }
      if (x === 0 || y === 0 || x === W - 1 || y === H - 1) edge = true;
      for (let k = 0; k < 4; k++) {
        const m = k === 0 ? (x > 0 ? n - 1 : -1) : k === 1 ? (x < W - 1 ? n + 1 : -1) : k === 2 ? (y > 0 ? n - W : -1) : (y < H - 1 ? n + W : -1);
        if (m < 0) continue;
        const l = labels[m];
        if (l === EMPTY) { labels[m] = id; stack[top++] = m; }
        else if (l === MAIN_ROAD) main = true;
        else if (l === WATER) shore = true;
      }
    }
    blocks.push({ area: cells * cell * cell, x: ox + sx / cells * cell, y: oy + sy / cells * cell, main, edge, shore, samples });
  }
  return { W, H, ox, oy, cell, labels, blocks, length };
}

// ---------- Pieces of the town joined up ----------
// Side streets end beside the expressway and a river can go unbridged, so a part of town can be left
// whose only way out runs off the map. Each such piece gets the shortest straight street to the rest
// of the town that keeps off every other road, passing over the expressway if it must; across the
// river only when there is no way round on land, on a bridge square to it.
function roadPieces(lines, graph) {
  const parent = lines.map((_, n) => n), find = n => { while (parent[n] !== n) n = parent[n] = parent[parent[n]]; return n; };
  const atNode = new Map();
  graph.lineNodes.forEach((list, n) => { if (GRADE_SEPARATED.has(lines[n].tier)) return;
    for (const { node } of list) { if (atNode.has(node)) parent[find(n)] = find(atNode.get(node)); else atNode.set(node, n); } });
  const size = new Map();
  lines.forEach((l, n) => { if (!GRADE_SEPARATED.has(l.tier)) size.set(find(n), (size.get(find(n)) || 0) + graph.cums[n].at(-1)); });
  const main = [...size].sort((a, b) => b[1] - a[1])[0];
  return { of: find, main: main ? main[0] : -1, size };
}
function connectPieces(lines, graph, water, sideType, mainType) {
  let added = 0; const failed = new Set();
  for (let round = 0; round < LAB.pieceLinks; round++) {
    const { of, main, size } = roadPieces(lines, graph);
    const loose = [...size].filter(([r, len]) => r !== main && len >= LAB.pieceMin).sort((a, b) => b[1] - a[1]);
    if (!loose.length) break;
    const half = ROADS[sideType].total / 2, hash = segHash(lines, 20);
    // Not just beside a junction on the road it meets, which would stagger the two.
    const skew = (u, v, deg = LAB.pieceMeet) => Math.abs(u[0] * v[0] + u[1] * v[1]) / (Math.hypot(...u) * Math.hypot(...v) || 1) > Math.cos(deg * Math.PI / 180);
    const nearJunction = (n, s) => graph.lineNodes[n].some(v => Math.abs(v.s - s) < LAB.pieceStagger && Math.abs(v.s - s) > 3);
    // A junction itself is a good place to meet: the new street makes a crossing of it.
    const atNodes = n => graph.lineNodes[n].map(v => { const q = pointAt(lines[n], graph.cums[n], v.s), N = graph.nodes[v.node]; return [[N.x, N.y], v.s, [q[2], q[3]]]; });
    const targets = [];
    lines.forEach((l, n) => { if (of(n) === main && !GRADE_SEPARATED.has(l.tier)) targets.push(n); });
    const crossing = (a, b, c, d) => {
      const rx = b[0] - a[0], ry = b[1] - a[1], sx = d[0] - c[0], sy = d[1] - c[1], den = rx * sy - ry * sx;
      if (Math.abs(den) < 1e-9) return null;
      const t = ((c[0] - a[0]) * sy - (c[1] - a[1]) * sx) / den, u = ((c[0] - a[0]) * ry - (c[1] - a[1]) * rx) / den;
      return t > 0 && t < 1 && u >= 0 && u <= 1 ? Math.abs(den) / Math.hypot(rx, ry) / Math.hypot(sx, sy) : null;
    };
    // Clear of water and of every road but the two it joins; the expressway only crossed squarely.
    const clear = (a, b, from, to, bridge) => {
      const len = Math.hypot(b[0] - a[0], b[1] - a[1]), steps = Math.ceil(len / 10);
      let wet = 0, wx = 0, wy = 0;
      for (let i = 0; i <= steps; i++) {
        const x = a[0] + (b[0] - a[0]) * i / steps, y = a[1] + (b[1] - a[1]) * i / steps;
        if (!insideField(x, y) || !water.built(x, y)) return false;
        if (bridge ? water.isSea(x, y) : water.near(x, y, 4)) return false;
        if (water.isRiver(x, y)) { wet += len / steps; wx = x; wy = y; }
      }
      if (bridge) {
        // Straight across: no longer than the river is wide allows, and square to its flow.
        if (!wet || wet > water.riverWidth * LAB.bridgeSpan || len > wet + LAB.bridgeLanding) return false;
        const R = water.river; let k = 0, kd = Infinity;
        R.forEach((q, i) => { const d = (q[0] - wx) ** 2 + (q[1] - wy) ** 2; if (d < kd) { kd = d; k = i; } });
        const u = R[Math.min(R.length - 1, k + 1)], v = R[Math.max(0, k - 1)];
        if (skew([b[0] - a[0], b[1] - a[1]], [u[0] - v[0], u[1] - v[1]]) || !skew([b[0] - a[0], b[1] - a[1]], [-(u[1] - v[1]), u[0] - v[0]], LAB.bridgeAngle)) return false;
      }
      let byFast = 0;
      for (let i = 1; i < steps; i++) {
        const s = i / steps * len, x = a[0] + (b[0] - a[0]) * i / steps, y = a[1] + (b[1] - a[1]) * i / steps; let ok = true, fast = false;
        hash.around(x, y, 2, (m, j) => { if (!ok || m === from || m === to) return;
          if (segDistT(x, y, lines[m].pts[j], lines[m].pts[j + 1])[0] >= half + ROADS[lines[m].type].total / 2 + 2) return;
          if (lines[m].tier === "expressway") fast = true; else if (s >= LAB.pieceEnds && s <= len - LAB.pieceEnds) ok = false; });
        if (!ok) return false;
        if (fast) byFast += len / steps;
      }
      // Over the expressway squarely, and only beside it while passing over.
      let sin = 0;
      for (const l of lines) if (l.tier === "expressway") for (let j = 0; j < l.pts.length - 1; j++) {
        const c = crossing(a, b, l.pts[j], l.pts[j + 1]); if (c !== null) sin = Math.max(sin, c);
      }
      if (byFast && (sin < Math.sin(LAB.bridgeAngle * Math.PI / 180) || byFast > (ROADS.expressway.total + 2 * half + 14) / sin)) return false;
      return true;
    };
    let joined = false;
    for (const [root] of loose) {
      if (failed.has(root)) continue;
      // From the piece's dead ends first, then from anywhere along it.
      const from = [];
      lines.forEach((l, n) => { if (of(n) !== root || GRADE_SEPARATED.has(l.tier)) return;
        if (l.deadStart) from.push([l.pts[0], n, 0, null]); if (l.deadEnd) from.push([l.pts.at(-1), n, 0, null]);
        for (let i = 0; i < l.pts.length; i += 4) if (!nearJunction(n, graph.cums[n][i])) {
          const a = l.pts[Math.max(0, i - 1)], c = l.pts[Math.min(l.pts.length - 1, i + 1)];
          from.push([l.pts[i], n, LAB.pieceMid, [c[0] - a[0], c[1] - a[1]]]);
        }
        for (const [p, , dir] of atNodes(n)) from.push([p, n, LAB.pieceMid, dir]); });
      let best = null;
      for (const bridge of [false, true]) {
        const reach = bridge ? water.riverWidth * LAB.bridgeSpan + LAB.pieceReach : LAB.pieceReach;
        if (bridge && (best || !water.river)) break;
        for (const [q, n, extra, along] of from) for (const m of targets) {
          const o = lines[m];
          // The nearest point on each stretch, its corners and its junctions: a longer way may cross squarely.
          const spots = [];
          for (let j = 0; j < o.pts.length - 1; j++) {
            const [, t] = segDistT(q[0], q[1], o.pts[j], o.pts[j + 1]), a = o.pts[j], c = o.pts[j + 1];
            const at = graph.cums[m][j], seg = graph.cums[m][j + 1] - at, dir = [c[0] - a[0], c[1] - a[1]];
            spots.push([[a[0] + (c[0] - a[0]) * t, a[1] + (c[1] - a[1]) * t], at + seg * t, dir], [a, at, dir]);
          }
          for (const [p, sp, dirM] of spots.concat(atNodes(m))) {
            const d = Math.hypot(p[0] - q[0], p[1] - q[1]);
            if (d < LAB.pieceShort || d > reach || (best && d + extra >= best.cost) || nearJunction(m, sp)) continue;
            // It meets each road it joins squarely enough, never in a shallow merge.
            const dir = [p[0] - q[0], p[1] - q[1]];
            if (skew(dir, dirM) || (along && skew(dir, along))) continue;
            if (clear(q, p, n, m, bridge)) best = { cost: d + extra, a: q.slice(), b: p.slice(), bridge };
          }
        }
      }
      if (!best) continue;
      const len = Math.hypot(best.b[0] - best.a[0], best.b[1] - best.a[1]), steps = Math.max(3, Math.ceil(len / 10)), pts = [];
      for (let i = 0; i <= steps; i++) pts.push([best.a[0] + (best.b[0] - best.a[0]) * i / steps, best.a[1] + (best.b[1] - best.a[1]) * i / steps]);
      // A bridge carries a main road: it is the only way across for this part of town.
      lines.push(best.bridge ? { pts, type: mainType, tier: "avenue", link: true } : { pts, type: sideType, tier: "street", link: true });
      const next = roadGraph(lines);
      // A street the junction finder does not take as meeting the other road joins nothing: undone.
      if (roadPieces(lines, next).size.size >= size.size) { lines.pop(); failed.add(root); continue; }
      graph = next; added++; joined = true;
      break; // the pieces change once one is joined
    }
    if (!joined) break;
  }
  return added;
}
// ---------- Huge blocks split by a new street ----------
// A block far larger than its district's grain is cut across its long side by a straight street,
// from road to road, as a city fills in a superblock. Beside the expressway the new street stops
// short in a turning circle. A few big blocks are kept whole and become parks.
function splitBigBlocks(lines, water, districts, sideType, rng) {
  const keep = [];
  let added = 0, dead = 0, firstCut = true;
  for (let round = 0; round < LAB.splitRounds; round++) {
    const grid = findBlocks(lines, water, [], rng), { W, H, ox, oy, cell, labels } = grid;
    const big = grid.blocks.map((b, i) => {
      const d = districtOfBlock(grid, districts, b), wall = STREET_WALL.has(districts.list[d].archetype.id);
      return b.area > LAB.maxBlock[wall ? 0 : 1];
    });
    const cellsOf = new Map();
    for (let i = 0; i < labels.length; i++) { const b = labels[i]; if (b >= 0 && big[b]) { if (!cellsOf.has(b)) cellsOf.set(b, []); cellsOf.get(b).push(i); } }
    const hash = segHash(lines, 20), cuts = [];
    const labelAt = (x, y) => { const cx = Math.floor((x - ox) / cell), cy = Math.floor((y - oy) / cell);
      return cx < 0 || cy < 0 || cx >= W || cy >= H ? WATER : labels[cy * W + cx]; };
    // From inside the block out to the centreline of the road that bounds it.
    const reach = (x, y, dx, dy, b) => {
      let t = 0;
      while (labelAt(x + dx * t, y + dy * t) === b) if ((t += 1) > 900) return null;
      const px = x + dx * t, py = y + dy * t, l = labelAt(px, py);
      if (l === VERGE) return t > 20 ? { p: [x + dx * (t - 2), y + dy * (t - 2)], cos: 0, dead: true, n: [-dx, -dy] } : null;
      if (l !== SIDE_ROAD && l !== MAIN_ROAD) return null;
      let best = null;
      hash.around(px, py, 2, (m, j) => { const o = lines[m];
        const [d, u] = segDistT(px, py, o.pts[j], o.pts[j + 1]);
        if (d < ROADS[o.type].total / 2 + 2 && (!best || d < best.d)) best = { d, m, j, u }; });
      // A turning circle is no place to join: the street would only lengthen the cul-de-sac.
      if (!best) return null;
      const o0 = lines[best.m], atEnd = (best.j === 0 && best.u < 0.5 && o0.deadStart) || (best.j === o0.pts.length - 2 && best.u > 0.5 && o0.deadEnd);
      if (atEnd) return null;
      if (GRADE_SEPARATED.has(lines[best.m].tier)) {
        const back = t - LAB.noiseBuffer - 10;
        return back > 20 ? { p: [x + dx * back, y + dy * back], cos: 0, dead: true, n: [-dx, -dy] } : null;
      }
      const o = lines[best.m], a = o.pts[best.j], c = o.pts[best.j + 1], len = Math.hypot(c[0] - a[0], c[1] - a[1]) || 1;
      const tx = (c[0] - a[0]) / len, ty = (c[1] - a[1]) / len, den = dx * -ty + dy * tx;
      if (Math.abs(den) < 1e-6) return null;
      const s = ((a[0] - x) * -ty + (a[1] - y) * tx) / den;
      // The road's normal into the block, so the new street can leave it square.
      const sn = -dx * -ty + -dy * tx > 0 ? 1 : -1;
      return { p: [x + dx * s, y + dy * s], cos: Math.abs(dx * tx + dy * ty), dead: false, n: [-ty * sn, tx * sn] };
    };
    // Away from its two ends the new street keeps clear of every other road, so it never runs
    // alongside one.
    const half = ROADS[sideType].total / 2;
    const clearOfRoads = pts => pts.every((q, k) => {
      if (k < 2 || k > pts.length - 3) return true;
      let ok = true;
      hash.around(q[0], q[1], 2, (m, j) => { if (ok && segDistT(q[0], q[1], lines[m].pts[j], lines[m].pts[j + 1])[0] < half + ROADS[lines[m].type].total / 2 + 2) ok = false; });
      return ok;
    });
    // First the dead ends: each runs on to the next road ahead, as a growing city joins up its dead
    // ends. A cul-de-sac laid out on purpose stays one unless it pokes into a huge block; the rest
    // only stopped short of the next road (real city cores have 5 to 14% dead ends, suburbs 20 to 25).
    const joined = new Set();
    lines.forEach(l => {
      if (l.tier !== "street") return;
      for (const atStart of [true, false]) {
        const e = atStart ? l.pts[0] : l.pts.at(-1), q = atStart ? l.pts[1] : l.pts.at(-2), len = Math.hypot(e[0] - q[0], e[1] - q[1]) || 1;
        const dx = (e[0] - q[0]) / len, dy = (e[1] - q[1]) / len;
        let gap = ROADS[l.type].total / 2 * LAB.bulb + 2, s0 = e;
        const across = !(atStart ? l.deadStart : l.deadEnd);
        if (across) {
          // In a grid a street that meets a road carries straight on across it into a huge block,
          // splitting it where the grid already runs (Manhattan and Barcelona: 64 to 82% four-way).
          const d = districts.at(e[0], e[1]);
          if (d < 0 || districts.list[d].style.grid !== 1) continue;
          for (gap = 4; gap < LAB.acrossReach && labelAt(e[0] + dx * gap, e[1] + dy * gap) < 0; gap += 2);
          const ahead = labelAt(e[0] + dx * gap, e[1] + dy * gap);
          if (ahead < 0 || !big[ahead]) continue;
          s0 = [e[0] + dx * gap, e[1] + dy * gap]; // the new street leaves from the far kerb
        }
        const b = labelAt(e[0] + dx * gap, e[1] + dy * gap);
        if (b < 0 || joined.has(b) || (!big[b] && l.chosenDead)) continue;
        const B = reach(e[0] + dx * gap, e[1] + dy * gap, dx, dy, b);
        if (!B || B.dead || B.cos > LAB.splitCos) continue;
        const span = Math.hypot(B.p[0] - s0[0], B.p[1] - s0[1]);
        if (span > (big[b] ? LAB.joinOn : LAB.joinShort)) continue;
        const L = span / 3, P1 = [s0[0] + dx * L, s0[1] + dy * L], P2 = [B.p[0] + B.n[0] * L, B.p[1] + B.n[1] * L], curve = [];
        for (let t = 0; t <= 1.0001; t += 0.05) { const u = 1 - t;
          curve.push([u * u * u * s0[0] + 3 * u * u * t * P1[0] + 3 * u * t * t * P2[0] + t * t * t * B.p[0], u * u * u * s0[1] + 3 * u * u * t * P1[1] + 3 * u * t * t * P2[1] + t * t * t * B.p[1]]); }
        let pts = resample(curve, span / Math.max(2, Math.round(span / FIELD.step)) * 1.0001);
        if (!pts.every((r, k) => k === 0 || [b, SIDE_ROAD, MAIN_ROAD].includes(labelAt(r[0], r[1]))) || tooTight(pts, LAB.radius.street) || !clearOfRoads(pts)) continue;
        if (across) pts = [e, ...pts];
        // The old end and the new street meet end to end; the street runs on.
        if (atStart) { l.pts = pts.slice().reverse().concat(l.pts.slice(1)); l.deadStart = false; }
        else { l.pts = l.pts.slice(0, -1).concat(pts); l.deadEnd = false; }
        joined.add(b); added++;
      }
    });
    if (joined.size) continue; // find the blocks again before cutting any
    grid.blocks.forEach((b, i) => {
      if (!big[i]) return;
      if (firstCut && rng.f() < LAB.keepWhole) { keep.push([b.x, b.y]); return; }
      const list = cellsOf.get(i); let c = 0, mx = 0, my = 0, vxx = 0, vyy = 0, vxy = 0;
      for (const k of list) { const x = k % W, y = (k - x) / W; c++; mx += x; my += y; }
      mx /= c; my /= c;
      for (const k of list) { const x = k % W - mx, y = (k - k % W) / W - my; vxx += x * x; vyy += y * y; vxy += x * y; }
      const long = 0.5 * Math.atan2(2 * vxy, vxx - vyy), lx = Math.cos(long), ly = Math.sin(long);
      const spread = Math.sqrt(Math.max(1e-9, (vxx * lx * lx + 2 * vxy * lx * ly + vyy * ly * ly) / c));
      // Across the middle first, then a little to either side and at a slant, until one fits.
      for (const off of LAB.splitOffsets) for (const turn of LAB.splitTurns) {
        const gx = mx + lx * spread * off, gy = my + ly * spread * off;
        let start = -1, bestD = Infinity;
        for (const k of list) { const x = k % W, y = (k - x) / W, dd = (x - gx) ** 2 + (y - gy) ** 2; if (dd < bestD) { bestD = dd; start = k; } }
        const x0 = ox + (start % W + 0.5) * cell, y0 = oy + (Math.floor(start / W) + 0.5) * cell;
        const ang = long + Math.PI / 2 + turn, dx = Math.cos(ang), dy = Math.sin(ang);
        const A = reach(x0, y0, -dx, -dy, i), B = reach(x0, y0, dx, dy, i);
        if (!A || !B || (A.dead && B.dead) || A.cos > LAB.splitCos || B.cos > LAB.splitCos) continue;
        const len = Math.hypot(B.p[0] - A.p[0], B.p[1] - A.p[1]);
        if (len < LAB.splitMin) continue;
        // A gentle curve that leaves and meets each road square, kept inside the block.
        const L = len / 3, P1 = [A.p[0] + A.n[0] * L, A.p[1] + A.n[1] * L], P2 = [B.p[0] + B.n[0] * L, B.p[1] + B.n[1] * L], curve = [];
        for (let t = 0; t <= 1.0001; t += 0.05) { const u = 1 - t;
          curve.push([u * u * u * A.p[0] + 3 * u * u * t * P1[0] + 3 * u * t * t * P2[0] + t * t * t * B.p[0], u * u * u * A.p[1] + 3 * u * u * t * P1[1] + 3 * u * t * t * P2[1] + t * t * t * B.p[1]]); }
        const pts = resample(curve, len / Math.max(2, Math.round(len / FIELD.step)) * 1.0001);
        if (!pts.every(q => { const l = labelAt(q[0], q[1]); return l === i || l === SIDE_ROAD || l === MAIN_ROAD; })) continue;
        if (tooTight(pts, LAB.radius.street) || !clearOfRoads(pts)) continue;
        cuts.push({ pts, type: sideType, tier: "street" });
        if (A.dead || B.dead) dead++;
        return;
      }
    });
    firstCut = false;
    if (!cuts.length) break;
    lines.push(...cuts); added += cuts.length;
  }
  if (dead) settleDeadEnds(lines, water);
  return { added, keep };
}

// ---------- Land use: archetype mix, bent by how real cities sort themselves ----------
// The district of a block: where one of its own cells lies, as its middle may not be in it.
function districtOfBlock(grid, districts, b) {
  const n = b.samples[0], x = grid.ox + (n % grid.W + 0.5) * grid.cell, y = grid.oy + (Math.floor(n / grid.W) + 0.5) * grid.cell;
  return Math.max(0, districts.at(x, y));
}
function planUses(grid, districts, scales, parkReach, rng) {
  const uses = grid.blocks.map(b => {
    if (b.area < LAB.sliver) return PAVEMENT;
    if (!districts.built(b.x, b.y)) return FARM;
    if (b.area < LAB.square) return SQUARE;
    const w = districts.list[districtOfBlock(grid, districts, b)].mix.map((v, u) => v * scales[u]);
    if (b.main) w[OFFICES] *= LAB.mainOffices;
    const fromCentre = Math.min(1, Math.hypot(b.x / (FIELD.w / 2), b.y / (FIELD.h / 2)) / Math.SQRT2);
    w[PUBLIC] *= LAB.centrePublic + (1 - LAB.centrePublic) * fromCentre;
    if (b.area > LAB.bigBlock) w[PARK] *= b.area > LAB.maxPark ? 0 : LAB.bigParks; // past that, only blocks kept whole
    if (b.shore) w[PARK] *= LAB.waterParks;
    if (b.edge) w[INDUSTRY] *= LAB.edgeIndustry;
    const total = w.reduce((a, v) => a + v, 0);
    if (total <= 0) return HOMES;
    let roll = rng.f() * total;
    for (let u = 0; u < w.length; u++) { roll -= w[u]; if (roll <= 0) return u; }
    return w.length - 1;
  });
  // Every home within a short walk of a park: a homes block too far from one becomes a small park.
  let pocket = 0;
  if (parkReach > 0) {
    const parks = grid.blocks.filter((b, i) => uses[i] === PARK), order = [...grid.blocks.keys()];
    for (let i = order.length - 1; i > 0; i--) { const j = rng.int(0, i); [order[i], order[j]] = [order[j], order[i]]; }
    const covered = b => parks.some(q => (q.x - b.x) ** 2 + (q.y - b.y) ** 2 < parkReach * parkReach);
    for (const i of order) {
      const b = grid.blocks[i];
      if (uses[i] !== HOMES || covered(b)) continue;
      const fits = b.area >= LAB.pocketPark[0] && b.area <= LAB.pocketPark[1];
      if (fits) { uses[i] = PARK; parks.push(b); pocket++; }
    }
  }
  return { uses, pocket };
}

// ---------- Streets that serve nothing ----------
// Real streets are laid to reach lots. A cul-de-sac with hardly a building on it, or a street with
// park on both sides, serves no one: it goes.
function idleStreets(lines, buildings, grid, uses) {
  const fronting = new Array(lines.length).fill(0);
  for (const b of buildings) if (b.line >= 0) fronting[b.line]++;
  const { W, H, ox, oy, cell, labels } = grid, idle = [];
  const labelAt = (x, y) => { const cx = Math.floor((x - ox) / cell), cy = Math.floor((y - oy) / cell);
    return cx < 0 || cy < 0 || cx >= W || cy >= H ? WATER : labels[cy * W + cx]; };
  const green = b => b === WATER || (b >= 0 && (uses[b] === PARK || uses[b] === SQUARE || uses[b] === FARM));
  lines.forEach((l, n) => {
    if (l.tier !== "street" || l.link) return; // a street that joins a piece of town stays
    const len = lineLengths(l).at(-1);
    if ((l.deadStart || l.deadEnd) && fronting[n] === 0 && len < LAB.idleLength) { idle.push({ n, keep: [] }); return; }
    // No road runs inside a park: the stretches with park on both sides go, the rest stays.
    const off = ROADS[l.type].total / 2 + 4, inPark = l.pts.map((q, i) => {
      const a = l.pts[Math.max(0, i - 1)], c = l.pts[Math.min(l.pts.length - 1, i + 1)], t = Math.hypot(c[0] - a[0], c[1] - a[1]) || 1;
      const nx = -(c[1] - a[1]) / t, ny = (c[0] - a[0]) / t;
      return green(labelAt(q[0] + nx * off, q[1] + ny * off)) && green(labelAt(q[0] - nx * off, q[1] - ny * off));
    });
    if (!inPark.some(v => v)) return;
    const keep = [];
    let run = [];
    l.pts.forEach((q, i) => { if (!inPark[i]) run.push(q); else { if (run.length) keep.push(run); run = []; } });
    if (run.length) keep.push(run);
    idle.push({ n, keep: keep.filter(r => r.length > 1 && lineLengths({ pts: r }).at(-1) >= LAB.keepStretch) });
  });
  return idle;
}
// After streets go, each new block takes the use most of its ground had before.
function carryUses(before, uses, grid) {
  return grid.blocks.map(b => {
    if (b.area < LAB.sliver) return PAVEMENT;
    const votes = new Map();
    for (const n of b.samples) { const o = before.labels[n]; if (o >= 0 && uses[o] >= 0) votes.set(uses[o], (votes.get(uses[o]) || 0) + 1); }
    let best = HOMES, most = 0;
    for (const [u, v] of votes) if (v > most) { most = v; best = u; }
    return b.area < LAB.square && best !== PARK ? SQUARE : best;
  });
}
// A university district has its campus, the civic centre its civic block: the biggest blocks there.
function campuses(grid, uses, districts) {
  for (const [arch, count] of [["university", 2], ["civic", 1]]) {
    const list = grid.blocks.map((b, i) => i).filter(i => (uses[i] === HOMES || uses[i] === OFFICES) && grid.blocks[i].area >= LAB.campusMin
      && districts.list[districtOfBlock(grid, districts, grid.blocks[i])].archetype.id === arch);
    list.sort((x, y) => grid.blocks[y].area - grid.blocks[x].area);
    for (const i of list.slice(0, count)) uses[i] = PUBLIC;
  }
}

// ---------- Buildings: footprints along each street, inside its blocks ----------
// Each block is built up in one kind of home or office, as a street is built in one go. Shops
// are spread through the neighbourhoods as real high streets are: shops below flats along the
// main roads of dense districts, corner shops by junctions, and a supermarket or a strip with
// parking within reach of every home. Public buildings are sited by catchment the same way.
function placeBuildings(lines, g, discs, grid, uses, districts, density, rng, passages) {
  const weighted = (names, weights) => {
    const total = weights.reduce((a, v) => a + v, 0); let roll = rng.f() * total;
    for (let i = 0; i < names.length; i++) { roll -= weights[i]; if (roll <= 0) return names[i]; }
    return names[names.length - 1];
  };
  const shift = 0.2 + density; // denser cities lean to the larger kinds
  const hoodOf = block => NEIGHBOURHOOD[districts.list[districtOfBlock(grid, districts, grid.blocks[block])].archetype.id];
  const archOf = block => districts.list[districtOfBlock(grid, districts, grid.blocks[block])].archetype.id;
  const kinds = new Map();
  const kindOf = block => {
    const use = uses[block];
    if (use === INDUSTRY) return "industry";
    if (use === PUBLIC) return archOf(block) === "university" ? "university" : "library";
    if (!kinds.has(block)) {
      const h = hoodOf(block);
      kinds.set(block, [weighted(HOME_KINDS, h.homes.map((v, k) => v * shift ** ((k - 3) / 2))), weighted(OFFICE_KINDS, h.offices.map((v, k) => v * shift ** (k - 0.5)))]);
    }
    return kinds.get(block)[use === HOMES ? 0 : 1];
  };
  const { W, H, ox, oy, cell, labels } = grid, taken = new Uint8Array(W * H), out = [];
  // A footprint keeps one cell clear of every street and shore, so it never touches the sidewalk.
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const l = labels[y * W + x];
    if (l < 0) { taken[y * W + x] = 1; continue; }
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
      const nx = x + dx, ny = y + dy;
      if (nx >= 0 && ny >= 0 && nx < W && ny < H && labels[ny * W + nx] !== l) taken[y * W + x] = 1;
    }
  }
  const labelAt = (x, y) => {
    const cx = Math.floor((x - ox) / cell), cy = Math.floor((y - oy) / cell);
    return cx < 0 || cy < 0 || cx >= W || cy >= H ? WATER : labels[cy * W + cx];
  };
  const fits = (fx, fy, tx, ty, nx, ny, w, d, block) => {
    for (let a = -w / 2; a <= w / 2 + 0.01; a += Math.min(2, w / 2)) for (let b = 0.5; b <= d + 0.01; b += Math.min(2, d / 2)) {
      const x = fx + tx * a + nx * b, y = fy + ty * a + ny * b;
      if (labelAt(x, y) !== block) return false;
      const cx = Math.floor((x - ox) / cell), cy = Math.floor((y - oy) / cell);
      if (taken[cy * W + cx]) return false;
    }
    return true;
  };
  // The grid is only a quick first test: a footprint must also stay clear of every drawn
  // sidewalk and of every footprint already placed, measured exactly.
  const HC = 20, hkey = (x, y) => Math.floor(x / HC) * 100003 + Math.floor(y / HC), segs = new Map(), placed = new Map();
  const put = (map, x, y, v) => { const k = hkey(x, y); if (!map.has(k)) map.set(k, []); map.get(k).push(v); };
  const around = (map, x, y, reach, f) => {
    const cx = Math.floor(x / HC), cy = Math.floor(y / HC);
    for (let dx = -reach; dx <= reach; dx++) for (let dy = -reach; dy <= reach; dy++) {
      const list = map.get((cx + dx) * 100003 + cy + dy); if (list) for (const v of list) if (f(v)) return true;
    }
    return false;
  };
  for (const l of lines) {
    const edge = ROADS[l.type].total / 2 + cell * 1.1 + 0.5 + (l.tier === "expressway" ? LAB.noiseBuffer : 0); // the drawn sidewalk, and a little air
    for (let i = 0; i < l.pts.length - 1; i++) {
      const a = l.pts[i], b = l.pts[i + 1];
      for (let t = 0; t <= 1; t += 0.5) put(segs, a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, [a, b, edge]);
    }
  }
  for (const l of lines) for (const [dead, e] of [[l.deadStart, l.pts[0]], [l.deadEnd, l.pts[l.pts.length - 1]]])
    if (dead) put(segs, e[0], e[1], [e, e, ROADS[l.type].total / 2 * LAB.bulb + cell * 1.1 + 0.5]);
  for (const d of discs) put(segs, d.x, d.y, [[d.x, d.y], [d.x, d.y], d.R + d.walk + cell * 1.1 + 0.5]);
  for (const w of passages) { const [a, b] = w.pts, n = Math.ceil(Math.hypot(b[0] - a[0], b[1] - a[1]) / 10);
    for (let k = 0; k <= n; k++) put(segs, a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n, [a, b, w.width / 2 + 1.5]); }
  // Sight corners: nothing built right on the corner of a junction, except in street-wall districts.
  for (const node of g.nodes) {
    const d = districts.at(node.x, node.y), wall = d >= 0 && STREET_WALL.has(districts.list[d].archetype.id);
    const r = Math.max(...node.legs.map(l => ROADS[lines[l.line].type].total / 2)) + cell * 1.1 + 0.5 + (wall ? 0 : LAB.sightCorner);
    put(segs, node.x, node.y, [[node.x, node.y], [node.x, node.y], r]);
  }
  const segDist = (x, y, a, b) => {
    const vx = b[0] - a[0], vy = b[1] - a[1], l2 = vx * vx + vy * vy || 1;
    const t = Math.max(0, Math.min(1, ((x - a[0]) * vx + (y - a[1]) * vy) / l2));
    return Math.hypot(x - a[0] - vx * t, y - a[1] - vy * t);
  };
  const touchesStreet = poly => {
    const probes = poly.concat(poly.map((q, i) => { const r = poly[(i + 1) % 4]; return [(q[0] + r[0]) / 2, (q[1] + r[1]) / 2]; }));
    return probes.some(q => around(segs, q[0], q[1], 3, sg => segDist(q[0], q[1], sg[0], sg[1]) < sg[2]));
  };
  const span = (poly, ax, ay) => { let lo = Infinity, hi = -Infinity; for (const q of poly) { const v = q[0] * ax + q[1] * ay; if (v < lo) lo = v; if (v > hi) hi = v; } return [lo, hi]; };
  const overlaps = (P, Q) => { // separating axes of two quads, with half a metre between them
    for (const poly of [P, Q]) for (let i = 0; i < 4; i++) {
      const a = poly[i], b = poly[(i + 1) % 4], l = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1, ax = (a[1] - b[1]) / l, ay = (b[0] - a[0]) / l;
      const [p0, p1] = span(P, ax, ay), [q0, q1] = span(Q, ax, ay);
      if (p1 + 0.5 <= q0 || q1 + 0.5 <= p0) return false;
    }
    return true;
  };
  const clear = poly => !touchesStreet(poly) && !around(placed, poly[0][0], poly[0][1], 4, q => overlaps(poly, q));
  const claim = poly => {
    put(placed, poly[0][0], poly[0][1], poly);
    const xs = poly.map(q => q[0]), ys = poly.map(q => q[1]);
    const x0 = Math.floor((Math.min(...xs) - ox) / cell), x1 = Math.floor((Math.max(...xs) - ox) / cell);
    const y0 = Math.floor((Math.min(...ys) - oy) / cell), y1 = Math.floor((Math.max(...ys) - oy) / cell);
    for (let y = Math.max(0, y0); y <= Math.min(H - 1, y1); y++) for (let x = Math.max(0, x0); x <= Math.min(W - 1, x1); x++)
      if (inPoly(ox + (x + 0.5) * cell, oy + (y + 0.5) * cell, poly)) taken[y * W + x] = 1;
  };
  // Frontage sites: every few metres along each street, on each side, with the block behind.
  const sites = new Map(), byLine = lines.map(() => []);
  lines.forEach((l, n) => {
    if (GRADE_SEPARATED.has(l.tier)) return; // nothing fronts an expressway or its ramps
    const pts = l.pts, half = ROADS[l.type].total / 2;
    for (const side of [1, -1]) {
      let i = 0, along = rng.f() * 4;
      while (i < pts.length - 1) {
        const a = pts[i], b = pts[i + 1], seg = Math.hypot(b[0] - a[0], b[1] - a[1]);
        if (along > seg) { along -= seg; i++; continue; }
        const tx = (b[0] - a[0]) / seg, ty = (b[1] - a[1]) / seg, nx = -ty * side, ny = tx * side;
        const px = a[0] + tx * along, py = a[1] + ty * along, block = labelAt(px + nx * (half + 3), py + ny * (half + 3));
        if (block >= 0) {
          const st = { px, py, tx, ty, nx, ny, half, line: n, tier: l.tier };
          if (!sites.has(block)) sites.set(block, []); sites.get(block).push(st); byLine[n].push([block, st]);
        }
        along += LAB.siteStep;
      }
    }
  });
  // Junctions with three roads or more, for corner shops.
  const corners = g.nodes.filter(n => n.legs.length >= 3);
  // A corner shop or two per junction, not a row of them.
  const cornerShops = new Map();
  const nearCorner = (x, y) => corners.find(n => (n.x - x) ** 2 + (n.y - y) ** 2 < LAB.cornerReach ** 2 && (cornerShops.get(n) || 0) < LAB.cornerShops);
  // One building on a frontage site, if it fits: full size first, then smaller.
  const build = (site, block, kind, scales, shallow = false) => {
    const spec = KINDS[kind], w0 = rng.range(...spec.w);
    const wall = STREET_WALL.has(archOf(block));
    const set = wall && spec.tall < 2 && !spec.icon && !spec.reach ? 0 : rng.range(...spec.set) * (wall && !spec.icon ? LAB.wallSetback : 1) + (LAB.arterialSetback[site.tier] || 0);
    const { tx, ty, nx, ny } = site, front = site.half + cell * 1.5 + set;
    for (const f of scales) {
      // The building starts at the site and runs on along the street, so the next one can follow on.
      let d = rng.range(...spec.d) * f, w = w0 * Math.min(1, f + 0.15);
      const fx = site.px + nx * front + tx * w / 2, fy = site.py + ny * front + ty * w / 2;
      const rect = depth => [[fx - tx * w / 2, fy - ty * w / 2], [fx + tx * w / 2, fy + ty * w / 2],
        [fx + tx * w / 2 + nx * depth, fy + ty * w / 2 + ny * depth], [fx - tx * w / 2 + nx * depth, fy - ty * w / 2 + ny * depth]];
      if (!fits(fx, fy, tx, ty, nx, ny, w, d, block)) continue;
      let poly = rect(d);
      if (!clear(poly)) continue;
      // In a dense core the building runs back from the street wall as far as the block allows,
      // round a courtyard: a closed perimeter block (Paris wings 15 to 40 m, Tel Aviv about 20).
      const deep = spec.icon || spec.reach ? 0 : WING[archOf(block)] || 0;
      for (let d2 = d + 2; d2 <= deep; d2 += 2) {
        const p2 = rect(d2); if (!fits(fx, fy, tx, ty, nx, ny, w, d2, block) || !clear(p2)) break;
        d = d2; poly = p2;
      }
      claim(poly); out.push({ poly, kind, use: uses[block], tall: spec.tall, line: site.line, wall: wall && !spec.icon && !spec.reach });
      return w;
    }
    // A block too thin for the kind still gets a shallow one on the pavement line, as on a narrow
    // strip between two parallel roads.
    if (shallow) for (let d = Math.min(spec.d[0], LAB.shallowDepth[1]); d >= LAB.shallowDepth[0]; d -= 2) {
      const w = Math.max(LAB.shallowDepth[0], w0 * 0.6), front0 = site.half + cell * 1.5;
      const fx = site.px + nx * front0 + tx * w / 2, fy = site.py + ny * front0 + ty * w / 2;
      if (!fits(fx, fy, tx, ty, nx, ny, w, d, block)) continue;
      const poly = [[fx - tx * w / 2, fy - ty * w / 2], [fx + tx * w / 2, fy + ty * w / 2],
        [fx + tx * w / 2 + nx * d, fy + ty * w / 2 + ny * d], [fx - tx * w / 2 + nx * d, fy - ty * w / 2 + ny * d]];
      if (!clear(poly)) continue;
      claim(poly); out.push({ poly, kind, use: uses[block], tall: spec.tall, line: site.line, wall: wall && !spec.icon && !spec.reach });
      return w;
    }
    return 0;
  };
  const shuffled = list => { const o = list.slice(); for (let i = o.length - 1; i > 0; i--) { const j = rng.int(0, i); [o[i], o[j]] = [o[j], o[i]]; } return o; };
  const builtOn = (block, kind, pick) => {
    const list = sites.get(block); if (!list) return false;
    const spec = KINDS[kind], tries = shuffled(list.filter(st => !spec.main || st.tier !== "street")).slice(0, LAB.siteTries);
    for (const st of (pick ? tries.sort(pick) : tries)) if (build(st, block, kind, [1, 0.8, 0.65])) return true;
    return false;
  };
  const centre = poly => [(poly[0][0] + poly[2][0]) / 2, (poly[0][1] + poly[2][1]) / 2];
  const homesBlocks = grid.blocks.map((b, i) => i).filter(i => uses[i] === HOMES);
  const hostBlocks = grid.blocks.map((b, i) => i).filter(i => (uses[i] === HOMES || uses[i] === OFFICES) && grid.blocks[i].area >= LAB.serviceBlock);
  // Landmarks: one hospital near the middle of the city, the city hall in the civic centre.
  const byMiddle = hostBlocks.slice().sort((p, q) => Math.hypot(grid.blocks[p].x, grid.blocks[p].y) - Math.hypot(grid.blocks[q].x, grid.blocks[q].y));
  for (const b of byMiddle.slice(0, 12)) if (builtOn(b, "hospital")) break;
  const civicHall = byMiddle.filter(b => archOf(b) === "civic");
  // Only a map with a civic centre has the city hall (the game keeps it for the last stage).
  if (civicHall.length) for (const b of civicHall.slice(0, 12)) if (builtOn(b, "cityhall")) break;
  // Services: wherever a home has none within reach, one goes up on the nearest host block.
  for (const kind of SERVICES) {
    const spec = KINDS[kind], have = out.filter(bd => bd.kind === kind).map(bd => centre(bd.poly));
    for (const h of shuffled(homesBlocks)) {
      const hb = grid.blocks[h], hood = hoodOf(h);
      if ((kind === "strip") !== !!hood.strip && (kind === "strip" || kind === "market")) continue;
      if (have.some(q => Math.hypot(q[0] - hb.x, q[1] - hb.y) < spec.reach)) continue;
      const hosts = hostBlocks.filter(b => Math.hypot(grid.blocks[b].x - hb.x, grid.blocks[b].y - hb.y) < spec.reach * 0.6)
        .sort((p, q) => Math.hypot(grid.blocks[p].x - hb.x, grid.blocks[p].y - hb.y) - Math.hypot(grid.blocks[q].x - hb.x, grid.blocks[q].y - hb.y));
      for (const b of hosts.slice(0, 6)) if (builtOn(b, kind)) { have.push(centre(out[out.length - 1].poly)); break; }
    }
  }
  // Then the frontage: homes, shops below flats, corner shops, offices, works.
  const order = lines.map((l, n) => n).sort((a, b) => ROADS[lines[b].type].total - ROADS[lines[a].type].total);
  for (const n of order) {
    let skip = 0;
    for (const [block, st] of byLine[n]) {
      if (skip > 0) { skip -= LAB.siteStep; continue; }
      const use = uses[block];
      if (use < 0 || use === PARK || use === SQUARE || use === FARM) continue;
      let kind = kindOf(block);
      if (use === HOMES) {
        const h = hoodOf(block), main = st.tier !== "street";
        if (rng.f() < (main ? h.mixedMain : h.mixedSide)) kind = "mixed";
        else {
          const node = nearCorner(st.px, st.py);
          if (node && rng.f() < h.corner) { kind = "corner"; cornerShops.set(node, (cornerShops.get(node) || 0) + 1); }
        }
      }
      const w = build(st, block, kind, [1, 0.75, 0.5], true);
      skip = w ? w + Math.max(0.6, rng.range(...KINDS[kind].gap) * (STREET_WALL.has(archOf(block)) ? LAB.wallGap : 1)) - LAB.siteStep : 0;
    }
  }
  // On a street wall the gaps left between frontage buildings (where a bend fans the lots apart)
  // take narrow infill buildings, as the narrow lots of an old core do.
  for (const n of order) for (const [block, st] of byLine[n]) {
    if (!STREET_WALL.has(archOf(block)) || (uses[block] !== HOMES && uses[block] !== OFFICES)) continue;
    build(st, block, uses[block] === HOMES ? "walkup" : "office", LAB.gapFill, true);
  }
  // Deep blocks filled behind the frontage: courtyard and rear buildings, towers in a park,
  // sheds in a works yard, a campus. Laid out in rows along the block's long side.
  const members = new Map();
  grid.blocks.forEach((b, i) => { if (b.area >= LAB.infillMin && uses[i] >= HOMES && uses[i] <= PUBLIC) members.set(i, []); });
  for (let i = 0; i < labels.length; i++) { const list = members.get(labels[i]); if (list) list.push(i); }
  // Every building is reached from a street: none deeper in a block than infillReach (m).
  const toRoad = new Int32Array(W * H).fill(1 << 30), queue = new Int32Array(W * H);
  let qh = 0, qt = 0;
  for (let i = 0; i < W * H; i++) if (labels[i] === SIDE_ROAD || labels[i] === MAIN_ROAD) { toRoad[i] = 0; queue[qt++] = i; }
  while (qh < qt) {
    const n = queue[qh++], x = n % W, d = toRoad[n] + 1;
    if (x > 0 && toRoad[n - 1] > d) { toRoad[n - 1] = d; queue[qt++] = n - 1; }
    if (x < W - 1 && toRoad[n + 1] > d) { toRoad[n + 1] = d; queue[qt++] = n + 1; }
    if (n >= W && toRoad[n - W] > d) { toRoad[n - W] = d; queue[qt++] = n - W; }
    if (n < W * (H - 1) && toRoad[n + W] > d) { toRoad[n + W] = d; queue[qt++] = n + W; }
  }
  const reached = (x, y) => { const cx = Math.floor((x - ox) / cell), cy = Math.floor((y - oy) / cell); return toRoad[cy * W + cx] * cell <= LAB.infillReach; };
  const near = (x, y, r) => around(placed, x, y, Math.ceil(r / HC) + 2, q => {
    const cx = (q[0][0] + q[2][0]) / 2, cy = (q[0][1] + q[2][1]) / 2; return Math.hypot(cx - x, cy - y) < r; });
  for (const [block, list] of members) {
    const use = uses[block], kind = kindOf(block), spec = KINDS[kind];
    if (spec.lawn === undefined && (kind === "suburban" || kind === "row")) continue; // back gardens
    let c = 0, mx = 0, my = 0, vxx = 0, vyy = 0, vxy = 0;
    for (const k of list) { const x = k % W, y = (k - x) / W; c++; mx += x; my += y; }
    mx /= c; my /= c;
    for (const k of list) { const x = k % W - mx, y = (k - k % W) / W - my; vxx += x * x; vyy += y * y; vxy += x * y; }
    const long = 0.5 * Math.atan2(2 * vxy, vxx - vyy), tx = Math.cos(long), ty = Math.sin(long), nx = -ty, ny = tx;
    const w = (spec.w[0] + spec.w[1]) / 2, d = (spec.d[0] + spec.d[1]) / 2, air = Math.max(LAB.infillAir, spec.gap[1], spec.lawn ? spec.lawn * 2 : 0);
    const stepA = w + air, stepB = d + Math.max(air, LAB.infillYard);
    const x0 = ox + (mx + 0.5) * cell, y0 = oy + (my + 0.5) * cell;
    const ext = Math.sqrt(list.length) * cell * 1.5;
    for (let b = -ext; b <= ext; b += stepB) for (let a = -ext; a <= ext; a += stepA) {
      const cx = x0 + tx * a + nx * b, cy = y0 + ty * a + ny * b;
      if (labelAt(cx, cy) !== block || !reached(cx, cy) || near(cx, cy, Math.max(w, d) / 2 + LAB.infillYard)) continue;
      const fx = cx - nx * d / 2, fy = cy - ny * d / 2;
      if (!fits(fx, fy, tx, ty, nx, ny, w + 2 * air, d, block)) continue;
      const poly = [[fx - tx * w / 2, fy - ty * w / 2], [fx + tx * w / 2, fy + ty * w / 2],
        [fx + tx * w / 2 + nx * d, fy + ty * w / 2 + ny * d], [fx - tx * w / 2 + nx * d, fy - ty * w / 2 + ny * d]];
      if (!clear(poly)) continue;
      claim(poly); out.push({ poly, kind, use, tall: spec.tall, line: -1 });
    }
  }
  return out;
}
function inPoly(x, y, poly) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}
function plantTrees(grid, uses, rng, walkways) {
  const trees = [];
  grid.blocks.forEach((b, i) => {
    const use = uses[i]; if (use !== PARK && use !== SQUARE) return;
    const count = Math.min(b.samples.length, Math.round(b.area / (use === PARK ? 260 : 900)));
    for (let t = 0; t < count; t++) {
      const n = b.samples[t], x = n % grid.W, y = (n - x) / grid.W;
      trees.push([grid.ox + (x + rng.f()) * grid.cell, grid.oy + (y + rng.f()) * grid.cell, rng.range(3, 6)]);
    }
  });
  // Planting kept 2 m back from every path and off the squares in the middle of parks.
  const segs = [];
  for (const w of walkways) if (w.pts) for (let k = 0; k < w.pts.length - 1; k++) segs.push([w.pts[k], w.pts[k + 1], w.width / 2 + 2]);
  const plazas = walkways.filter(w => w.kind === "plaza");
  return trees.filter(([x, y, r]) => !segs.some(([a, b, h]) => segDistT(x, y, a, b)[0] < h + r * 0.6)
    && !plazas.some(p => Math.hypot(p.hub[0] - x, p.hub[1] - y) < p.r + r));
}

// ---------- One map ----------
// The roads are laid out once per set of sliders; the player's roundabouts and block uses are then
// worked in by building the rest again from them, which is quick enough to follow each click.
let roadCache = null;
const NO_EDITS = { roundabouts: [], blocks: [] };
function buildMap(p, edits = NO_EDITS) {
  FIELD.w = p.size * 1000; FIELD.h = Math.round(FIELD.w * LAB.aspect); FIELD.maxLen = FIELD.w * 1.5;
  const key = JSON.stringify({ ...p, pull: 0, spread: 0 }); // the height sliders leave the roads alone
  if (!roadCache || roadCache.key !== key) {
    // Boulevards so far apart that the city is one or two districts: drawn closer until it has a few.
    let q = p, roads = buildRoads(q);
    while (!isSingle(q) && roads.districts.list.length < LAB.minDistricts && q.blvd > 400) { q = { ...q, blvd: q.blvd * 0.8 }; roads = buildRoads(q); }
    roadCache = { key, roads };
  }
  // A metropolis builds closer and taller on the same streets.
  return buildCity(p.context === "metro" ? { ...p, density: Math.min(2, p.density + LAB.metroDensity) } : p, roadCache.roads, edits);
}
function buildRoads(p) {
  const rng = makeRng(p.seed);
  const water = makeWater(p, rng);
  water.built = townShape(p);
  const shore = waterfront(water).map(pts => ({ pts, type: "promenade", tier: "promenade" }));
  // First the roads that bound the districts, then the districts, then each district's streets.
  const single = isSingle(p), blvd = p.blvdType !== "none" && !single;
  const border = blvd ? { name: "boulevard", type: p.blvdType, spacing: p.blvd } : { name: "avenue", type: p.mainType, spacing: p.major };
  const borderTiers = [0, 1].map(dir => ({ ...border, dir, bridges: true }));
  const cityAngle = rng.f() * Math.PI;
  // The expressway first, as the city grew around it; then the district-bounding roads.
  const express = p.expressType !== "none" && !single ? makeExpressway(water, rng) : null, fast = express ? [express] : [];
  const borderField = makeField(cityWide(rng), p.curvy, cityAngle, rng);
  const first = express ? interchangeSeed(express, borderField, water) : [];
  if (first.length && first[0].dir === 1) borderTiers.reverse(); // the interchange's boulevard goes first
  const borderLines = single ? [] : traceStreets(borderField, borderTiers, water, shore.concat(fast), null, rng, first);
  let interchange = express ? makeInterchange(express, borderLines.concat(shore), water) : null, ramps = interchange ? interchange.ramps : [];
  // Joined up first, so no gap at a junction lets one district run into the next.
  const bounding = borderLines.concat(shore, fast, ramps);
  joinEnds(bounding, p.minor * LAB.joinReach, 0, p.sideType, p.mainType, water, rng);
  const districts = findDistricts(bounding.filter(l => l.tier !== "street" && l.pts.length > 1), water, p, rng);
  const tiers = [];
  if (blvd || single) tiers.push({ name: "avenue", type: p.mainType, dir: 0, spacing: p.major });
  tiers.push({ name: "street", type: p.sideType, dir: 1, spacing: p.minor, deadShare: p.dead });
  if (p.style < 0) tiers.push({ name: "street", type: p.sideType, dir: 0, spacing: p.minor, deadShare: p.dead, cross: true });
  const inner = traceStreets(makeField(districts, p.curvy, cityAngle, rng), tiers, water, shore.concat(borderLines, fast, ramps), districts, rng);
  const lines = borderLines.concat(inner, shore, fast, ramps);
  joinEnds(lines, p.minor * LAB.joinReach, p.dead, p.sideType, p.mainType, water, rng, districts);
  // No boulevard crossing would take an interchange: try every main road, side streets give way.
  if (express && !interchange) {
    interchange = makeInterchange(express, lines.filter(l => l.tier !== "street"), water);
    if (interchange) lines.push(...interchange.ramps);
  }
  cutAtExpressway(lines);
  settleDeadEnds(lines, water);
  const split = splitBigBlocks(lines, water, districts, p.sideType, makeRng(p.seed + 7919));
  // The road network as a graph: staggered junctions joined, busy streets upgraded, junctions typed.
  let graph = roadGraph(lines);
  const squared = squareUpEnds(lines, graph, water);
  if (squared.cut) settleDeadEnds(lines, water);
  graph = roadGraph(lines);
  // A row of staggered junctions along one road is worked through in a few passes.
  let staggers = 0;
  for (let pass = 0; pass < 3; pass++) {
    const { joined, cut } = alignStaggers(lines, graph, water);
    if (cut) settleDeadEnds(lines, water);
    graph = roadGraph(lines);
    staggers += joined;
    if (!joined && !cut) break;
  }
  // Joining staggered junctions can leave a slant; square those up once more.
  const again = squareUpEnds(lines, graph, water);
  squared.bent += again.bent; squared.cut += again.cut;
  if (again.cut) settleDeadEnds(lines, water);
  graph = roadGraph(lines);
  snapEnds(lines, graph);
  graph = roadGraph(lines);
  // Squaring and joining cut some streets back; any block that grew huge again is split once more.
  const late = splitBigBlocks(lines, water, districts, p.sideType, makeRng(p.seed + 7927));
  split.added += late.added; split.keep.push(...late.keep);
  if (late.added) {
    graph = roadGraph(lines);
    for (let pass = 0; pass < 3; pass++) {
      const { joined, cut } = alignStaggers(lines, graph, water);
      if (cut) settleDeadEnds(lines, water);
      graph = roadGraph(lines);
      staggers += joined;
      if (!joined && !cut) break;
    }
    const third = squareUpEnds(lines, graph, water);
    squared.bent += third.bent; squared.cut += third.cut;
    if (third.cut) settleDeadEnds(lines, water);
    graph = roadGraph(lines); snapEnds(lines, graph); graph = roadGraph(lines);
  }
  // Tidying the ends can pull a joining street off its road again, so join, tidy and look again.
  let linked = 0;
  for (let pass = 0; pass < LAB.piecePasses; pass++) {
    const added = connectPieces(lines, graph, water, p.sideType, p.mainType); if (!added) break;
    linked += added; settleDeadEnds(lines, water); graph = roadGraph(lines); snapEnds(lines, graph); graph = roadGraph(lines);
  }
  const upgraded = classifyByTraffic(lines, graph, p.mainType, rng);
  return { water, districts, lines, staggers, squared, upgraded, interchange, split, linked };
}
function buildCity(p, roads, edits) {
  const { water, districts, staggers, squared, upgraded, interchange, split } = roads, rng = makeRng(p.seed + 104729);
  const lines = roads.lines.map(l => ({ ...l, pts: l.pts.map(q => q.slice()) }));
  let graph = placeRoundabouts(lines, edits.roundabouts);
  // Built twice if need be: streets that serve nothing go, and the city is built again without them.
  let discs, grid, uses, pocket = 0, buildings, pruned = 0, walkways = [];
  for (let pass = 0; ; pass++) {
    discs = junctionControls(lines, graph, districts, water, rng, edits.roundabouts);
    const before = grid;
    grid = findBlocks(lines, water, discs, rng);
    if (!pass) {
      ({ uses, pocket } = planUses(grid, districts, [p.u0, p.u1, p.u2, 0, p.u4], p.green, rng));
      for (const [x, y] of split.keep) {
        const cx = Math.floor((x - grid.ox) / grid.cell), cy = Math.floor((y - grid.oy) / grid.cell), b = grid.labels[cy * grid.W + cx];
        if (b >= 0 && grid.blocks[b].area > LAB.square) uses[b] = PARK;
      }
      campuses(grid, uses, districts);
    } else uses = carryUses(before, uses, grid);
    for (const [x, y, u] of edits.blocks) { const b = blockAt(grid, x, y); if (b >= 0) uses[b] = u; }
    const passages = midBlockPassages(lines, grid, uses);
    buildings = placeBuildings(lines, graph, discs, grid, uses, districts, p.density, rng, passages);
    walkways = passages;
    if (pass === LAB.prunePasses) break;
    const idle = idleStreets(lines, buildings, grid, uses);
    if (!idle.length) break;
    // Whole streets go, or only their stretches through a park, unless that cuts the town in two.
    const pieces = ls => roadPieces(ls, roadGraph(ls)).size.size;
    for (const { n, keep } of idle.sort((x, y) => y.n - x.n)) {
      const l = lines[n], rest = lines.filter((_, m) => m !== n).concat(keep.map(pts => ({ ...l, pts })));
      if (pieces(rest) > pieces(lines)) continue;
      lines.splice(n, 1);
      for (const pts of keep) lines.push({ ...l, pts, deadStart: false, deadEnd: false });
      if (!keep.length) pruned++;
    }
    settleDeadEnds(lines, water);
    graph = roadGraph(lines);
    snapEnds(lines, graph);
    graph = roadGraph(lines);
  }
  walkways = walkways.concat(parkPaths(lines, graph, grid, uses));
  const trees = plantTrees(grid, uses, rng, walkways), kerbTrees = streetTrees(lines, graph, grid);
  const { crossings, bars } = crossingsAndLines(lines, graph, grid, uses, water);
  orientOneWays(lines, graph);
  return { districts, water, lines, grid, uses, buildings, trees, kerbTrees, pocket, pruned, walkways, graph, discs, crossings, bars, staggers, squared, upgraded, interchange, split };
}
// Buildings rise as plain boxes: floors by kind, taller in the dense districts and with the density slider.
const RISE = { forgotten: 0.7, immigrant: 1, public_housing: 1.1, industrial: 0.8, workers: 0.9, gentrifying: 1, university: 0.9, nightlife: 1, financial: 1.3, luxury: 1.2, civic: 1.1 };
let mode3d = false, three = null, stale3d = true;
// ---------- Density layer ----------
// How built-up each spot is, 0..1. It peaks at the downtown and at the busier district centres and
// falls off unevenly (noise), with small bumps where boulevards cross, as real skylines do.
const PEAKS = { financial: 1, civic: 0.75, luxury: 0.6, nightlife: 0.55, public_housing: 0.45, gentrifying: 0.4, university: 0.35, immigrant: 0.35, workers: 0.25, industrial: 0.1, forgotten: 0.1 };
const DENSITY_CELL = 20, CROSSING_BUMP = 0.3, MAX_FLOORS = 100;
function smoothNoise(x, y, cell, salt) {
  const gx = x / cell, gy = y / cell, i = Math.floor(gx), j = Math.floor(gy), fx = gx - i, fy = gy - j;
  const s = t => t * t * (3 - 2 * t), at = (a, b) => rollAt(a * 1.37 + salt, b * 2.11 - salt) * 2 - 1;
  const top = at(i, j) + (at(i + 1, j) - at(i, j)) * s(fx), bottom = at(i, j + 1) + (at(i + 1, j + 1) - at(i, j + 1)) * s(fx);
  return top + (bottom - top) * s(fy);
}
function densityOf(m, p) {
  if (m.density && m.density.pull === p.pull) return m.density;
  const C = DENSITY_CELL, W = Math.ceil(FIELD.w / C), H = Math.ceil(FIELD.h / C), v = new Float32Array(W * H);
  const peaks = m.districts.list.map(D => ({ x: D.x, y: D.y, a: PEAKS[D.archetype.id] ?? 0.3, L: 220 }));
  peaks.reduce((a, b) => (b.a > a.a ? b : a)).L = 340 * Math.max(1, FIELD.w / 1600); // the downtown spreads furthest, more in a big city
  for (const n of m.graph.nodes) if (n.rank === 2 && n.legs.length >= 4) peaks.push({ x: n.x, y: n.y, a: CROSSING_BUMP, L: 110 });
  let most = 0;
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
    const x = -FIELD.w / 2 + (i + 0.5) * C, y = -FIELD.h / 2 + (j + 0.5) * C;
    let empty = 1; // peaks add up without passing 1
    for (const k of peaks) empty *= 1 - k.a * Math.exp(-((Math.hypot(x - k.x, y - k.y) / k.L) ** 1.3));
    const wobble = 1 + 0.3 * smoothNoise(x, y, 160, p.seed) + 0.15 * smoothNoise(x, y, 60, p.seed + 7);
    v[j * W + i] = Math.max(0, (1 - empty) * wobble); most = Math.max(most, v[j * W + i]);
  }
  // Downtown pull: 0 spreads the city evenly, 2 piles it into the peaks.
  const floor = p.context === "metro" ? LAB.metroFloor : 0;
  for (let n = 0; n < v.length; n++) v[n] = floor + (1 - floor) * Math.min(1, Math.max(0, 0.4 + (v[n] / most - 0.4) * p.pull));
  m.density = { W, H, C, v, pull: p.pull, at: (x, y) => {
    const i = Math.min(W - 1, Math.max(0, Math.floor((x + FIELD.w / 2) / C))), j = Math.min(H - 1, Math.max(0, Math.floor((y + FIELD.h / 2) / C)));
    return v[j * W + i]; } };
  return m.density;
}
// Floors: the kind sets the range, the district lifts it, the density layer sets how far up the range
// a building reaches; Height range spreads neighbours apart and lets a few landmarks stand out.
function floorsOf(b, m, p) {
  const [lo, hi] = KINDS[b.kind].floors, x = (b.poly[0][0] + b.poly[2][0]) / 2, y = (b.poly[0][1] + b.poly[2][1]) / 2;
  const roll = rollAt(x, y);
  if (hi <= 4) return Math.max(1, Math.round(lo + (hi - lo) * roll)); // houses and halls keep their size
  const f = densityOf(m, p).at(x, y), lift = RISE[m.districts.list[Math.max(0, m.districts.at(x, y))].archetype.id] * (p.context === "metro" ? LAB.metroLift : 1);
  const top = lo + (hi * lift - lo) * (0.15 + 1.7 * f * f); // steep near the peak, flat at the edge
  let floors = lo + (top - lo) * roll ** (1 / (0.3 + 0.5 * p.density + 0.8 * f));
  floors *= 1 + p.spread * 0.35 * (rollAt(y, x) * 2 - 1);
  if (rollAt(x + 3.3, y + 1.7) < 0.04 * p.spread * (0.3 + f)) floors *= 1.5 + rollAt(x - 5.1, y); // a landmark
  return Math.max(1, Math.min(MAX_FLOORS, Math.round(floors)));
}
// ---------- Traffic test ----------
// Whether the map works for the people in it: every home and shop reachable by car and on foot,
// no one-way traps, no long detours, and where the busiest streets are. Then cars and people
// drive and walk real trips, keeping to lanes, lights and right of way, so jams and stuck cars show.
const TRAFFIC = {
  carLength: 6.5, accel: 2, brake: 3.5, stopLine: 2, stopWait: 1.2, boxHold: 1.1, cycle: 60, amber: 3,
  turnCost: { left: 8, right: 3, straight: 0, uturn: 25 }, signalCost: 12, stuckAfter: 60, walkSpeed: [1.1, 1.6],
  checkTrips: 160, spawnPerStep: 4, listed: 12, flyZoom: 5, detourFlag: 4, step: 0.2, maxSteps: 40, minDist: 150,
};
const TRAFFIC_SLIDERS = [
  ["cars", "Cars", 0, 1500, 25, 300], ["people", "People walking", 0, 2000, 50, 400], ["simSpeed", "Speed (× real time)", 1, 20, 1, 4],
];
const FAST_ONLY = new Set(["expressway", "ramp"]); // reached only through the interchange, left out of the test


// The street network as directed lanes: a link runs from one junction to the next along one line.
function trafficNet(m) {
  const g = m.graph, nodes = g.nodes.map(n => ({ x: n.x, y: n.y, control: n.control, rank: n.rank, out: [], into: [], end: false, phase: 0, box: 0, major: -1e9 }));
  const links = [], byLine = m.lines.map(() => []);
  // A street that runs off the map goes on into the rest of the city.
  const endNode = p => { nodes.push({ x: p[0], y: p[1], control: "end", rank: 0, out: [], into: [], end: true, box: 0, major: -1e9,
    edge: Math.abs(p[0]) > FIELD.w / 2 - LAB.edgeReach || Math.abs(p[1]) > FIELD.h / 2 - LAB.edgeReach }); return nodes.length - 1; };
  m.lines.forEach((l, n) => {
    if (FAST_ONLY.has(l.tier) || l.pts.length < 2) return;
    const cum = g.cums[n], len = cum[cum.length - 1], list = [...g.lineNodes[n]].sort((a, b) => a.s - b.s), stops = [];
    if (!list.length || list[0].s > 8) stops.push({ s: 0, node: endNode(l.pts[0]) });
    stops.push(...list);
    if (!list.length || list[list.length - 1].s < len - 8) stops.push({ s: len, node: endNode(l.pts[l.pts.length - 1]) });
    const r = ROADS[l.type], oneWay = r.oneWay && !l.twoWay, lanes = oneWay ? r.lanes : Math.max(1, Math.floor(r.lanes / 2)), speed = SPEED[l.tier] / 3.6;
    for (let i = 0; i + 1 < stops.length; i++) {
      const a = stops[i], b = stops[i + 1]; if (b.s - a.s < 1 || a.node === b.node) continue;
      for (const dir of oneWay ? [l.against ? -1 : 1] : [1, -1]) {
        const k = links.length, from = dir > 0 ? a.node : b.node, to = dir > 0 ? b.node : a.node;
        links.push({ k, line: n, s0: a.s, s1: b.s, dir, from, to, len: b.s - a.s, speed, lanes, oneWay, tier: l.tier, rank: RANK[l.tier], cars: [], use: 0, twin: -1 });
        nodes[from].out.push(k); nodes[to].into.push(k); byLine[n].push(k);
      }
      if (!oneWay) { links[links.length - 1].twin = links.length - 2; links[links.length - 2].twin = links.length - 1; }
    }
  });
  for (const L of links) { L.h0 = headingOf(m, L, 0); L.h1 = headingOf(m, L, L.len); }
  // A signal shows green to one axis of roads at a time.
  for (const N of nodes) if (N.control === "signal" && N.into.length) {
    const h = links[N.into[0]].h1; N.axis = Math.atan2(h[1], h[0]); N.offset = rollAt(N.x, N.y) * TRAFFIC.cycle;
  }
  const net = { nodes, links, byLine, m };
  net.turns = links.map(L => nodes[L.to].out.map(o => [o, turnOf(net, L, links[o])]).filter(([, t]) => t !== null));
  return net;
}
function headingOf(m, L, p) {
  const s = L.dir > 0 ? L.s0 + p : L.s1 - p, q = pointAt(m.lines[L.line], m.graph.cums[L.line], s);
  return [q[2] * L.dir, q[3] * L.dir];
}
// The kind of turn from one link into the next, or null where it is not allowed.
function turnOf(net, a, b) {
  const N = net.nodes[a.to];
  // A U-turn only at a dead end, where turning back is the only way on, or through the median
  // opening of a main road where side streets turn right in and out (a "Michigan left").
  if (b.twin === a.k || (b.line === a.line && b.dir !== a.dir))
    return N.end || N.out.every(o => o === b.k) || (N.control === "riro" && a.rank > 0) ? "uturn" : null;
  const cross = a.h1[0] * b.h0[1] - a.h1[1] * b.h0[0], dot = a.h1[0] * b.h0[0] + a.h1[1] * b.h0[1];
  const kind = dot > 0.85 ? "straight" : cross < 0 ? "right" : "left";
  // Right in, right out: a side street at a boulevard turns right only, both ways.
  if (N.control === "riro" && (a.rank === 0 || b.rank === 0) && kind !== "right") return null;
  return kind;
}
// Where a building meets its street: the link it fronts, and how far along.
function accessOf(net, b) {
  if (b.line < 0 || !net.byLine[b.line].length) return null;
  const l = net.m.lines[b.line], cum = net.m.graph.cums[b.line];
  const cx = b.poly.reduce((a, p) => a + p[0], 0) / b.poly.length, cy = b.poly.reduce((a, p) => a + p[1], 0) / b.poly.length;
  let best = 0, bd = Infinity;
  for (let i = 0; i + 1 < l.pts.length; i++) {
    const [d, t] = segDistT(cx, cy, l.pts[i], l.pts[i + 1]);
    if (d < bd) { bd = d; best = cum[i] + t * (cum[i + 1] - cum[i]); }
  }
  const on = net.byLine[b.line].filter(k => { const L = net.links[k]; return best >= L.s0 && best <= L.s1; });
  if (!on.length) return null;
  return { s: best, links: on, x: cx, y: cy };
}
const posOn = (L, s) => (L.dir > 0 ? s - L.s0 : L.s1 - s);
// Fastest drive between two buildings over the lanes, keeping to the turns allowed; null if none.
function driveRoute(net, from, to) {
  const { links } = net, cost = new Float64Array(links.length).fill(Infinity), prev = new Int32Array(links.length).fill(-1), heap = [];
  const push = (k, c) => { heap.push([c, k]); let i = heap.length - 1; while (i) { const p = (i - 1) >> 1; if (heap[p][0] <= heap[i][0]) break; [heap[p], heap[i]] = [heap[i], heap[p]]; i = p; } };
  const pop = () => { const top = heap[0], last = heap.pop(); if (heap.length) { heap[0] = last; let i = 0; for (;;) { const l = 2 * i + 1, r = l + 1; let s = i; if (l < heap.length && heap[l][0] < heap[s][0]) s = l; if (r < heap.length && heap[r][0] < heap[s][0]) s = r; if (s === i) break; [heap[s], heap[i]] = [heap[i], heap[s]]; i = s; } } return top; };
  const goal = new Map(to.links.map(k => [k, posOn(links[k], to.s)]));
  for (const k of from.links) { const L = links[k], p = posOn(L, from.s); cost[k] = (L.len - p) / L.speed; push(k, cost[k]); }
  let found = -1, best = Infinity;
  while (heap.length) {
    const [c, k] = pop(); if (c > cost[k] || c >= best) continue;
    const L = links[k];
    if (goal.has(k)) {
      const pin = from.links.includes(k) ? posOn(L, from.s) : 0, pg = goal.get(k);
      if (pg >= pin) { const total = c - (L.len - pg) / L.speed; if (total < best) { best = total; found = k; } }
    }
    const N = net.nodes[L.to];
    for (const [o, kind] of net.turns[k]) {
      const O = links[o], nc = c + O.len / O.speed + TRAFFIC.turnCost[kind] + (N.control === "signal" ? TRAFFIC.signalCost : 0);
      if (nc < cost[o]) { cost[o] = nc; prev[o] = k; push(o, nc); }
    }
  }
  if (found < 0) return null;
  const route = []; for (let k = found; k >= 0; k = prev[k]) route.push(k);
  route.reverse();
  let length = 0; route.forEach((k, i) => { const L = links[k]; length += (i === route.length - 1 ? posOn(L, to.s) : L.len) - (i === 0 ? posOn(L, from.s) : 0); });
  return { links: route, start: posOn(links[route[0]], from.s), end: posOn(links[found], to.s), length };
}
// Shortest walk between two buildings: sidewalks run both ways along every street.
function walkRoute(net, from, to) {
  const { nodes, links } = net, dist = new Float64Array(nodes.length).fill(Infinity), prev = new Int32Array(nodes.length).fill(-1), via = new Int32Array(nodes.length).fill(-1);
  const heap = [];
  const push = (n, c) => { heap.push([c, n]); heap.sort((a, b) => a[0] - b[0]); };
  for (const k of from.links) { const L = links[k], p = posOn(L, from.s);
    for (const [n, d] of [[L.to, L.len - p], [L.from, p]]) if (d < dist[n]) { dist[n] = d; push(n, d); } }
  const goal = new Map(); for (const k of to.links) { const L = links[k], p = posOn(L, to.s); goal.set(L.from, Math.min(goal.get(L.from) ?? Infinity, p)); goal.set(L.to, Math.min(goal.get(L.to) ?? Infinity, L.len - p)); }
  let best = Infinity, end = -1;
  if (from.links.some(k => to.links.includes(k))) { best = Math.abs(from.s - to.s); }
  while (heap.length) {
    const [c, n] = heap.shift(); if (c > dist[n] || c >= best) continue;
    if (goal.has(n) && c + goal.get(n) < best) { best = c + goal.get(n); end = n; }
    for (const k of nodes[n].out.concat(nodes[n].into)) {
      const L = links[k], o = L.from === n ? L.to : L.from, nc = c + L.len;
      if (nc < dist[o]) { dist[o] = nc; prev[o] = n; via[o] = k; push(o, nc); }
    }
  }
  if (best === Infinity) return null;
  const chain = [end]; for (let n = end; prev[n] >= 0; n = prev[n]) chain.push(prev[n]);
  chain.reverse();
  return { length: best, chain, links: chain.slice(1).map(n => via[n]) };
}
// Reachability over the lanes: the links from which every other main link can be reached and back.
function mainLinks(net) {
  const { links } = net, n = links.length, fwd = new Uint8Array(n), back = new Uint8Array(n);
  const into = links.map(() => []); net.turns.forEach((list, k) => { for (const [o] of list) into[o].push(k); });
  // Start from the most important road of the biggest connected part, not a lone road in the fields.
  const part = new Int32Array(n).fill(-1), length = []; let parts = 0;
  for (let s = 0; s < n; s++) { if (part[s] >= 0) continue; let sum = 0; const q = [s]; part[s] = parts;
    while (q.length) { const k = q.pop(); sum += links[k].len;
      for (const v of [links[k].from, links[k].to]) for (const o of net.nodes[v].out.concat(net.nodes[v].into)) if (part[o] < 0) { part[o] = parts; q.push(o); } }
    length.push(sum); parts++; }
  const big = length.indexOf(Math.max(...length));
  let seed = 0, most = -1; links.forEach((L, k) => { const w = L.rank * 1000 + L.len; if (part[k] === big && w > most) { most = w; seed = k; } });
  const walk = (mark, next) => { const q = [seed]; mark[seed] = 1; while (q.length) { const k = q.pop(); for (const o of next(k)) if (!mark[o]) { mark[o] = 1; q.push(o); } } };
  // The map is the whole world: a way round that runs off its edge does not count.
  walk(fwd, k => net.turns[k].map(t => t[0])); walk(back, k => into[k]);
  return { fwd, back };
}
function trafficChecks() {
  if (!map) return null;
  const t0 = performance.now(), N = trafficNet(map), { links } = N;
  const access = map.buildings.map(b => accessOf(N, b));
  const reach = mainLinks(N), problems = [];
  // Buildings a car cannot get to, or cannot leave: grouped by the street they stand on.
  const byStreet = new Map();
  map.buildings.forEach((b, i) => {
    const a = access[i]; if (!a) return;
    const inOk = a.links.some(k => reach.fwd[k]), outOk = a.links.some(k => reach.back[k]);
    if (inOk && outOk) return;
    const key = b.line + (inOk ? ":out" : outOk ? ":in" : ":none");
    if (!byStreet.has(key)) byStreet.set(key, { n: 0, x: a.x, y: a.y, kind: inOk ? "out" : outOk ? "in" : "none" });
    byStreet.get(key).n++;
  });
  for (const p of byStreet.values()) problems.push({ x: p.x, y: p.y, n: p.n, colour: "#d8473b",
    text: p.kind === "in" ? `${p.n} buildings a car cannot reach (one-way streets lead only away)` : p.kind === "out" ? `${p.n} buildings a car cannot leave (one-way trap)` : `${p.n} buildings cut off from the roads` });
  // Walking: sidewalks on every street, so only a street cut off by water or the expressway fails.
  const comp = new Int32Array(N.nodes.length).fill(-1); let c = 0;
  for (let s = 0; s < N.nodes.length; s++) { if (comp[s] >= 0) continue; const q = [s]; comp[s] = c; while (q.length) { const n = q.pop(); for (const k of N.nodes[n].out.concat(N.nodes[n].into)) { const L = links[k]; for (const o of [L.from, L.to]) if (comp[o] < 0) { comp[o] = c; q.push(o); } } } c++; }
  const edgeComps = new Set(N.nodes.map((n, i) => (n.edge ? comp[i] : -1)).filter(v => v >= 0));
  if (edgeComps.size > 1) { const first = [...edgeComps][0]; for (let i = 0; i < comp.length; i++) if (edgeComps.has(comp[i])) comp[i] = first; }
  const size = new Map(); for (const v of comp) size.set(v, (size.get(v) || 0) + 1);
  const mainWalk = [...size.entries()].sort((a, b) => b[1] - a[1])[0][0];
  const island = new Map();
  map.buildings.forEach((b, i) => { const a = access[i]; if (!a || comp[links[a.links[0]].from] === mainWalk) return;
    const key = comp[links[a.links[0]].from]; if (!island.has(key)) island.set(key, { n: 0, x: a.x, y: a.y }); island.get(key).n++; });
  for (const p of island.values()) problems.push({ x: p.x, y: p.y, n: p.n, colour: "#8b5cc0", text: `${p.n} buildings no one can walk to from the rest of town` });
  // Sample trips from homes to work, shops and services: detours, and how many trips use each street.
  const rng = makeRng(params.seed + 31), homes = [], other = [];
  map.buildings.forEach((b, i) => { if (!access[i]) return; (KINDS[b.kind].group === "Homes" ? homes : other).push(i); });
  const drive = [], walk = [];
  for (const L of links) L.use = 0;
  for (let t = 0; t < TRAFFIC.checkTrips && homes.length && other.length; t++) {
    const i = homes[rng.int(0, homes.length - 1)], j = other[rng.int(0, other.length - 1)], A = access[i], B = access[j];
    const straight = Math.hypot(A.x - B.x, A.y - B.y); if (straight < TRAFFIC.minDist) continue;
    const r = driveRoute(N, A, B);
    if (r) { drive.push(r.length / straight); for (const k of r.links) links[k].use++;
      if (r.length / straight > TRAFFIC.detourFlag) problems.push({ x: A.x, y: A.y, x2: B.x, y2: B.y, colour: "#e8930c", text: `A ${Math.round(straight)} m trip takes ${(r.length / 1000).toFixed(1)} km by car` }); }
    const w = walkRoute(N, A, B); if (w) walk.push(w.length / straight);
  }
  const q = (list, f) => { const s = [...list].sort((a, b) => a - b); return s.length ? s[Math.min(s.length - 1, Math.floor(s.length * f))] : 0; };
  problems.sort((a, b) => (b.n || 0) - (a.n || 0));
  const reached = access.filter((a, i) => a && a.links.some(k => reach.fwd[k]) && a.links.some(k => reach.back[k])).length;
  return { net: N, access, homes, other, problems, ms: performance.now() - t0,
    driveDetour: [q(drive, 0.5), q(drive, 0.9)], walkDetour: [q(walk, 0.5), q(walk, 0.9)], reached, total: access.filter(Boolean).length,
    busiest: q(links.map(L => L.use), 0.95) };
}

// One-way streets: neighbours run opposite ways, as in a real grid, and a dead end or a street a car
// could get into and not out of (or the reverse) carries traffic both ways.
function orientOneWays(lines, graph) {
  const one = [];
  lines.forEach((l, n) => { delete l.twoWay; delete l.against; if (ROADS[l.type] && ROADS[l.type].oneWay && !FAST_ONLY.has(l.tier)) one.push(n); });
  const groups = new Map(), step = Math.PI / 12;
  for (const n of one) {
    const l = lines[n], list = graph.lineNodes[n], len = graph.cums[n][graph.cums[n].length - 1];
    if (!list.length || Math.min(...list.map(v => v.s)) > 8 || Math.max(...list.map(v => v.s)) < len - 8) { l.twoWay = true; continue; }
    const a = l.pts[0], b = l.pts[l.pts.length - 1], axis = ((Math.atan2(b[1] - a[1], b[0] - a[0]) % Math.PI) + Math.PI) % Math.PI;
    const bucket = Math.round(axis / step) % 12, ux = Math.cos(bucket * step), uy = Math.sin(bucket * step);
    if (!groups.has(bucket)) groups.set(bucket, []);
    groups.get(bucket).push({ n, off: -uy * (a[0] + b[0]) / 2 + ux * (a[1] + b[1]) / 2, aligned: (b[0] - a[0]) * ux + (b[1] - a[1]) * uy > 0 });
  }
  for (const list of groups.values()) list.sort((p, q) => p.off - q.off).forEach((g, i) => { lines[g.n].against = g.aligned !== (i % 2 === 0); });
  const pseudo = { lines, graph };
  for (let pass = 0; pass < LAB.oneWayPasses; pass++) {
    const N = trafficNet(pseudo), r = mainLinks(N); let changed = 0;
    for (const n of one) if (!lines[n].twoWay && N.byLine[n].some(k => !r.fwd[k] || !r.back[k])) { lines[n].twoWay = true; changed++; }
    if (!changed) break;
  }
}

const DEFAULTS = { seed: 7, style: -1, kind: "forgotten", context: "city" };
for (const defs of [QUICK_SLIDERS, PATTERN_SLIDERS, WATER_SLIDERS, USE_SLIDERS, HEIGHT_SLIDERS])
  for (const [key, , , , , value] of defs) DEFAULTS[key] = value;
for (const [key, , , value] of ROAD_TIERS) DEFAULTS[key] = value;
module.exports = { DEFAULTS, ROADS, KINDS, USES, ARCHETYPES, FIELD, LAB, STYLES, MIXES, NEIGHBOURHOOD, RISE, PEAKS, buildMap, floorsOf };
