// Planning checks for one built map. Every count is a defect, unless named as a measure (m_).
function checkMap(m, seed) {
  const r = { seed };
  const g = m.grid, lines = m.lines, G = m.graph;
  const CELL = 20, segs = new Map(), key = (x, y) => Math.floor(x / CELL) * 100003 + Math.floor(y / CELL);
  lines.forEach((l, n) => { const half = ROADS[l.type].total / 2; for (let i = 0; i < l.pts.length - 1; i++) {
    const a = l.pts[i], c = l.pts[i + 1];
    const k = key((a[0] + c[0]) / 2, (a[1] + c[1]) / 2); if (!segs.has(k)) segs.set(k, []); segs.get(k).push([a, c, half, n, i]); } });
  const near = (x, y, f, reach = 3) => { const cx = Math.floor(x / CELL), cy = Math.floor(y / CELL);
    for (let dx = -reach; dx <= reach; dx++) for (let dy = -reach; dy <= reach; dy++) { const list = segs.get((cx + dx) * 100003 + cy + dy); if (list) for (const s of list) f(s); } };
  const segDist = (x, y, a, c) => { const vx = c[0] - a[0], vy = c[1] - a[1], l2 = vx * vx + vy * vy || 1;
    const t = Math.max(0, Math.min(1, ((x - a[0]) * vx + (y - a[1]) * vy) / l2)); return Math.hypot(x - a[0] - vx * t, y - a[1] - vy * t); };
  const fast = l => l.tier === 'expressway' || l.tier === 'ramp';
  // 1. Buildings touching a drawn street, sidewalk or roundabout; in the water.
  let onRoad = 0, inWater = 0;
  for (const bd of m.buildings) {
    const pts = [...bd.poly]; for (let i = 0; i < 4; i++) { const a = bd.poly[i], c = bd.poly[(i + 1) % 4]; pts.push([(a[0] + c[0]) / 2, (a[1] + c[1]) / 2]); }
    const cx = pts.reduce((s, q) => s + q[0], 0) / pts.length, cy = pts.reduce((s, q) => s + q[1], 0) / pts.length; pts.push([cx, cy]);
    let hit = false;
    for (const q of pts) near(q[0], q[1], s => { if (!hit && segDist(q[0], q[1], s[0], s[1]) < s[2] + LAB.cell * 1.1) hit = true; });
    for (const d of m.discs) for (const q of pts) if (Math.hypot(q[0] - d.x, q[1] - d.y) < d.R + d.walk + LAB.cell) hit = true;
    if (hit) onRoad++;
    if (pts.some(q => m.water.isWater(q[0], q[1]))) inWater++;
  }
  r.bldOnRoad = onRoad; r.bldInWater = inWater;
  // 2. Buildings overlapping each other.
  const bh = new Map(); m.buildings.forEach((bd, i) => { const c = bd.poly[0]; const k = key(c[0], c[1]); if (!bh.has(k)) bh.set(k, []); bh.get(k).push(i); });
  const proj = (poly, ax, ay) => { let lo = Infinity, hi = -Infinity; for (const q of poly) { const v = q[0] * ax + q[1] * ay; lo = Math.min(lo, v); hi = Math.max(hi, v); } return [lo, hi]; };
  const overlap = (P, Q) => { for (const poly of [P, Q]) for (let i = 0; i < 4; i++) { const a = poly[i], c = poly[(i + 1) % 4]; let ax = -(c[1] - a[1]), ay = c[0] - a[0]; const l = Math.hypot(ax, ay) || 1; ax /= l; ay /= l;
    const [p0, p1] = proj(P, ax, ay), [q0, q1] = proj(Q, ax, ay); if (p1 < q0 + 0.3 || q1 < p0 + 0.3) return false; } return true; };
  let bb = 0;
  m.buildings.forEach((bd, i) => { const c = bd.poly[0], cx = Math.floor(c[0] / CELL), cy = Math.floor(c[1] / CELL);
    for (let dx = -4; dx <= 4; dx++) for (let dy = -4; dy <= 4; dy++) { const list = bh.get((cx + dx) * 100003 + cy + dy); if (list) for (const j of list) if (j > i && overlap(bd.poly, m.buildings[j].poly)) bb++; } });
  r.bldOverlap = bb;
  // 3. Roads on water off a bridge, tight bends, shallow merges, long bridges.
  let wet = 0, tight = 0, shallow = 0;
  const bridges = { n: 0, long: 0 };
  lines.forEach((l, n) => {
    const pts = l.pts, R = LAB.radius[l.tier] || 300;
    let run = 0;
    for (let i = 0; i < pts.length; i++) {
      const q = pts[i], w = m.water.isWater(q[0], q[1]);
      if (w && l.tier !== 'boulevard' && l.tier !== 'expressway' && !l.link) wet++; // a joining bridge is checked by bridgesTooLong
      if (w) run++; else { if (run) { bridges.n++; if (run * FIELD.step > m.water.riverWidth * LAB.bridgeRun + 30) bridges.long++; } run = 0; }
      if (i > 0 && i < pts.length - 1) {
        const a = pts[i - 1], c = pts[i + 1];
        const t1 = Math.atan2(q[1] - a[1], q[0] - a[0]), t2 = Math.atan2(c[1] - q[1], c[0] - q[0]);
        let d = Math.abs(t2 - t1); if (d > Math.PI) d = 2 * Math.PI - d;
        const segLen = (Math.hypot(q[0] - a[0], q[1] - a[1]) + Math.hypot(c[0] - q[0], c[1] - q[1])) / 2;
        if (d > segLen / R * 1.6 + 0.05) tight++;
      }
    }
  });
  const seen = new Set();
  lines.forEach((l, n) => { const pts = l.pts, half = ROADS[l.type].total / 2;
    for (let i = 2; i < pts.length - 2; i++) { const q = pts[i], a = pts[i - 1], c = pts[i + 1], tl = Math.hypot(c[0] - a[0], c[1] - a[1]) || 1, tx = (c[0] - a[0]) / tl, ty = (c[1] - a[1]) / tl;
      near(q[0], q[1], s => { if (s[3] === n) return; const o = lines[s[3]]; if (s[4] < 1 || s[4] > o.pts.length - 3) return;
        if (fast(l) && fast(o)) return; // a ramp runs along its expressway by design
        if (segDist(q[0], q[1], s[0], s[1]) > half + s[2] - 1) return;
        const sx = s[1][0] - s[0][0], sy = s[1][1] - s[0][1], sl = Math.hypot(sx, sy) || 1;
        if (Math.abs(tx * sx + ty * sy) / sl > 0.69) { const k = Math.min(n, s[3]) + ':' + Math.max(n, s[3]); if (!seen.has(k)) { seen.add(k); shallow++; } } }); } });
  r.roadOnWater = wet; r.tightBends = tight; r.shallowMerges = shallow; r.bridgesTooLong = bridges.long;
  // 4. Dead ends.
  let deadMain = 0, deadAll = 0, ends = 0, nearMiss = 0;
  lines.forEach((l, n) => { for (const e of [l.pts[0], l.pts[l.pts.length - 1]]) {
    if (Math.abs(e[0]) > FIELD.w / 2 - 25 || Math.abs(e[1]) > FIELD.h / 2 - 25 || m.water.near(e[0], e[1], DRIVE() + 10)) continue;
    ends++;
    let touch = false; near(e[0], e[1], s => { if (s[3] !== n && segDist(e[0], e[1], s[0], s[1]) < s[2] + 3) touch = true; });
    let hug = false; near(e[0], e[1], s => { if (s[3] !== n && segDist(e[0], e[1], s[0], s[1]) < s[2] + 15) hug = true; });
    if (!touch) { deadAll++; if (l.tier !== 'street') deadMain++; if (hug) nearMiss++; } } });
  r.deadEndHugsStreet = nearMiss; r.deadEndMain = deadMain;
  r.m_deadEndShare = ends ? deadAll / ends : 0;
  // 5. The road hierarchy (Sustainable Safety): no side street touches the expressway or a ramp;
  //    no side street crosses a boulevard at grade; ramps meet main roads only.
  let streetTouchesFast = 0, classSkip = 0;
  lines.forEach((l, n) => { if (l.tier !== 'street' || l.link) return; let hit = false; // a joining street passes over it
    for (const q of l.pts) near(q[0], q[1], s => { if (!hit && fast(lines[s[3]]) && segDist(q[0], q[1], s[0], s[1]) < s[2] + ROADS[l.type].total / 2) hit = true; });
    if (hit) streetTouchesFast++; });
  for (const node of G.nodes) {
    const tiers = new Set(node.legs.map(lg => lines[lg.line].tier));
    if (tiers.has('boulevard') && tiers.has('street') && !['riro', 'signal', 'bend'].includes(node.control)) classSkip++;
    if (tiers.has('ramp') && tiers.has('street')) classSkip++;
  }
  r.streetTouchesFast = streetTouchesFast; r.classSkip = classSkip;
  // 6. Junction geometry: legs meeting at under 45 degrees; staggered T junctions under 40 m apart.
  let sharp = 0, under70 = 0, stagger = 0;
  for (const node of G.nodes) { const a = tightestAngle(node); if (a < 45 && node.control !== 'roundabout') sharp++; if (a < 70) under70++; }
  G.lineNodes.forEach((list, road) => { for (let i = 0; i + 1 < list.length; i++) {
    const A = G.nodes[list[i].node], B = G.nodes[list[i + 1].node], gap = list[i + 1].s - list[i].s;
    if (gap < 2 || gap >= 40 || A.legs.length !== 3 || B.legs.length !== 3) continue;
    const endOf = N => N.legs.find(lg => lg.line !== road && !N.legs.some(o => o !== lg && o.line === lg.line));
    const ea = endOf(A), eb = endOf(B); if (!ea || !eb || ea.line === eb.line) continue;
    const h = pointAt(lines[road], G.cums[road], list[i].s), side = lg => Math.sign(h[2] * lg.dir[1] - h[3] * lg.dir[0]);
    if (side(ea) !== side(eb)) stagger++;
  } });
  r.sharpJunctions = sharp; r.staggeredT = stagger; r.m_junctionsUnder70 = G.nodes.length ? under70 / G.nodes.length : 0;
  // 7. Roundabouts: clear of buildings (checked above), water, the expressway and each other.
  let badRound = 0;
  m.discs.forEach((d, i) => {
    let bad = m.discs.some((o, j) => j !== i && Math.hypot(o.x - d.x, o.y - d.y) < o.R + d.R);
    for (let a = 0; a < 16 && !bad; a++) if (m.water.isWater(d.x + Math.cos(a * Math.PI / 8) * d.R, d.y + Math.sin(a * Math.PI / 8) * d.R)) bad = true;
    near(d.x, d.y, s => { if (lines[s[3]].tier === 'expressway' && segDist(d.x, d.y, s[0], s[1]) < d.R + s[2]) bad = true; });
    if (bad) badRound++; });
  r.roundaboutBlocked = badRound;
  // 8. Crossings: two on one road closer than 60 m (but for the legs of one junction).
  let close = 0;
  const byLine = new Map(); m.crossings.forEach(c => { if (!byLine.has(c.line)) byLine.set(c.line, []); byLine.get(c.line).push(c); });
  for (const list of byLine.values()) for (let i = 0; i < list.length; i++) for (let j = i + 1; j < list.length; j++) {
    const a = list[i], b = list[j]; if (a.kind !== 'mid' && b.kind !== 'mid') continue; // junction legs: one each

    if (Math.hypot(a.x - b.x, a.y - b.y) < LAB.crossingGap - 1) close++; }
  r.crossingsTooClose = close;
  // Longest stretch of a main road with no crossing (measure).
  let longest = 0;
  lines.forEach((l, n) => { if (l.tier === 'street' || fast(l)) return; const len = G.cums[n].at(-1);
    const at = (byLine.get(n) || []).map(c => { let best = 0, bd = Infinity; for (let s = 0; s <= len; s += 5) { const p = pointAt(l, G.cums[n], s), d = Math.hypot(p[0] - c.x, p[1] - c.y); if (d < bd) { bd = d; best = s; } } return best; }).sort((a, b) => a - b);
    let prev = 0; for (const s of at.concat([len])) { const gap = s - prev; prev = s;
      const mid = pointAt(l, G.cums[n], s - gap / 2); if (!m.water.isWater(mid[0], mid[1])) longest = Math.max(longest, gap); } });
  r.m_longestNoCrossing = longest;
  // 9. Measures of the network.
  const count = c => G.nodes.filter(n => n.control === c).length;
  r.m_signals = count('signal'); r.m_roundabouts = count('roundabout'); r.m_riro = count('riro');
  r.m_upgraded = m.upgraded; r.m_staggersJoined = m.staggers;
  r.m_expressway = lines.some(l => l.tier === 'expressway') ? 1 : 0; r.m_interchange = m.interchange ? 1 : 0;
  // 10. Walking distance and city measures.
  const homes = m.buildings.filter(bd => KINDS[bd.kind].group === 'Homes');
  const ctr = bd => [(bd.poly[0][0] + bd.poly[2][0]) / 2, (bd.poly[0][1] + bd.poly[2][1]) / 2];
  const share = (pick, reach) => { const sites = m.buildings.filter(pick).map(ctr); return homes.length ? homes.filter(bd => { const c = ctr(bd); return !sites.some(q => Math.hypot(q[0] - c[0], q[1] - c[1]) < reach); }).length / homes.length : 0; };
  r.m_homesNoSchool = share(bd => bd.kind === 'school', KINDS.school.reach);
  r.m_homesNoShop400 = share(bd => KINDS[bd.kind].group === 'Shops', 400);
  r.m_homesNoClinic = share(bd => bd.kind === 'clinic' || bd.kind === 'hospital', KINDS.clinic.reach);
  const parks = g.blocks.filter((bl, i) => m.uses[i] === PARK), pr = params.green;
  r.m_homesNoPark = homes.length ? homes.filter(bd => !parks.some(c => Math.hypot(c.x - bd.poly[0][0], c.y - bd.poly[0][1]) < pr + Math.sqrt(c.area) / 2)).length / homes.length : 0;
  r.m_publicBuildings = m.buildings.filter(bd => KINDS[bd.kind].group === 'Public').length;
  r.m_shops = m.buildings.filter(bd => KINDS[bd.kind].group === 'Shops').length;
  r.m_streetsRemoved = m.pruned;
  // Streets left that serve nothing (should be 0 after pruning, a few after the last pass).
  r.idleStreetsLeft = idleStreets(lines, m.buildings, g, m.uses).length;
  const built = g.blocks.filter((bl, i) => m.uses[i] >= 0 && m.uses[i] !== SQUARE && m.uses[i] !== FARM);
  r.m_meanBlockM2 = built.reduce((a, bl) => a + bl.area, 0) / Math.max(1, built.length);
  r.m_kmStreetsPerKm2 = Object.values(g.length).reduce((a, v) => a + v, 0) / 1000 / (FIELD.w * FIELD.h / 1e6);
  r.m_buildings = m.buildings.length;
  // 11. Empty land: built blocks (homes, offices, industry, public) over 3 ha, and the share of
  // built land more than 40 m from any building.
  r.hugeBuiltBlocks = g.blocks.filter((bl, i) => m.uses[i] >= HOMES && m.uses[i] <= PUBLIC && bl.area > 30000).length;
  { const { W, H, cell } = g, dist = new Int32Array(W * H).fill(1e9), q = new Int32Array(W * H); let h = 0, t = 0;
    for (const bd of m.buildings) { const xs = bd.poly.map(v => v[0]), ys = bd.poly.map(v => v[1]);
      for (let y = Math.floor((Math.min(...ys) - g.oy) / cell); y <= Math.floor((Math.max(...ys) - g.oy) / cell); y++)
        for (let x = Math.floor((Math.min(...xs) - g.ox) / cell); x <= Math.floor((Math.max(...xs) - g.ox) / cell); x++)
          if (x >= 0 && y >= 0 && x < W && y < H && dist[y * W + x] && inPoly(g.ox + (x + .5) * cell, g.oy + (y + .5) * cell, bd.poly)) { dist[y * W + x] = 0; q[t++] = y * W + x; } }
    while (h < t) { const n = q[h++], x = n % W; for (const k of [x > 0 ? n - 1 : -1, x < W - 1 ? n + 1 : -1, n - W, n + W]) if (k >= 0 && k < W * H && dist[k] > dist[n] + 1) { dist[k] = dist[n] + 1; q[t++] = k; } }
    let builtCells = 0, empty = 0;
    for (let i = 0; i < W * H; i++) { const l = g.labels[i]; if (l < 0 || m.uses[l] < HOMES || m.uses[l] > PUBLIC) continue; builtCells++; if (dist[i] * cell > 40) empty++; }
    r.m_emptyBuiltLand = empty / Math.max(1, builtCells); }
  return r;
}
function runChecks(start, n) { const out = []; for (let s = start; s < start + n; s++) { params.seed = s; const m = buildMap(params); out.push(checkMap(m, s)); } return out; }
