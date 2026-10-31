// One map, built and driven: the planning checks (checks-in-page.js) and the traffic test, plus
// the measures that targets.json has for real cities. Runs inside the Map Lab page.
function probeMap(seed, context, size) {
  const t0 = performance.now();
  params.seed = seed; params.context = context; params.size = size; syncControls(); rebuild();
  const r = checkMap(map, seed);
  r.context = context; r.size = size;
  const C = trafficChecks(), N = C.net;
  r.cutOff = C.total - C.reached;
  r.walkIslands = C.problems.filter(p => p.colour === "#8b5cc0").reduce((a, p) => a + p.n, 0);
  r.longDetours = C.problems.filter(p => p.x2 !== undefined).length;
  // Random trips between buildings: how many find no way by car.
  const acc = C.access.filter(Boolean), rng = makeRng(seed + 7);
  let failed = 0;
  for (let i = 0; i < 100 && acc.length > 1; i++) if (!driveRoute(N, acc[rng.int(0, acc.length - 1)], acc[rng.int(0, acc.length - 1)])) failed++;
  r.failedTrips = failed / 100;
  r.m_driveDetourMedian = C.driveDetour[0]; r.m_driveDetourP90 = C.driveDetour[1];
  r.m_walkDetourMedian = C.walkDetour[0]; r.m_walkDetourP90 = C.walkDetour[1];
  // Bottlenecks: the share of car trip-km on the busiest 5% of streets.
  const byUse = N.links.map(L => [L.use, L.use * L.len]).sort((a, b) => b[0] - a[0]);
  const top = Math.max(1, Math.round(byUse.length * 0.05)), km = byUse.reduce((a, u) => a + u[1], 0);
  r.m_driveTop5TripKmShare = km ? byUse.slice(0, top).reduce((a, u) => a + u[1], 0) / km : 0;
  // Land: inside the map, dry and (for a town) inside the town.
  let land = 0; const S = 40;
  for (let x = -FIELD.w / 2 + S / 2; x < FIELD.w / 2; x += S) for (let y = -FIELD.h / 2 + S / 2; y < FIELD.h / 2; y += S)
    if (!map.water.isWater(x, y) && map.water.built(x, y)) land++;
  const km2 = land * S * S / 1e6;
  r.m_landKm2 = km2;
  r.m_junctionsPerKm2 = km2 ? map.graph.nodes.filter(n => n.legs.length >= 3).length / km2 : 0;
  const floors = map.buildings.map(b => floorsOf(b, map, params)).sort((a, b) => a - b);
  r.m_floorsMedian = floors.length ? floors[Math.floor(floors.length / 2)] : 0;
  r.m_floorsP90 = floors.length ? floors[Math.floor(floors.length * 0.9)] : 0;
  r.m_joins = (roadCache.roads.linked || 0);
  r.ms = Math.round(performance.now() - t0);
  return r;
}
