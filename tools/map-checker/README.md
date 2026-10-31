# Map checker (local, no tokens)

Builds hundreds of Map Lab maps in a hidden Edge or Chrome window, runs the planning checks and
the traffic test on each, and compares the city with real ones (`targets.json`, measured from
OpenStreetMap; data © OpenStreetMap contributors, ODbL).

- Double-click `run_map_check.cmd`. The first run installs the browser driver (`playwright-core`)
  with npm; it uses the Edge already on Windows, no browser download.
- Options: `run_map_check.cmd [seeds per setting] [pages at once]`, default 100 seeds and up to 2
  pages. Nine settings (town, part of a city, metropolis; 0.9 to 3.2 km), so 100 seeds is 900 maps.
- It runs at low priority. Close the window to stop; the next run goes on where it stopped
  (`results.jsonl` keeps every finished map). Delete `results.jsonl` to start again from scratch.
- At the end: `SUMMARY_map_check.md` (tables per setting: defects that should be 0, things worth
  watching, measures against real cities) and `summary.json` (the same, for Claude).
  Progress is in `map_check_log.txt`.

Files: `map-lab.html` is a copy of the Map Lab page; `checks-in-page.js` (planning checks) and
`probe-in-page.js` (traffic and real-city measures) run inside it; `run-check.js` drives it.
Refresh `map-lab.html` when Map Lab changes.
