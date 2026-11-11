"""Groups the cities in tools/city_stats.csv into street styles.

Prints each group's average numbers and its cities, to copy into the
StreetStyle entries of data/mapgen.tres. Run it again whenever the CSV is
replaced with newer measurements: python3 tools/cluster_city_styles.py [groups]
"""
import csv
import random
import sys

FEATURES = ["orientation_order", "avg_circuity", "median_segment_m",
            "prop_four_way", "prop_dead_end"]


def main() -> None:
    groups = int(sys.argv[1]) if len(sys.argv) > 1 else 4
    rows = list(csv.DictReader(open("tools/city_stats.csv")))
    raw = [[float(r[f]) for f in FEATURES] for r in rows]
    means = [sum(c) / len(c) for c in zip(*raw)]
    spreads = [(sum((v - m) ** 2 for v in c) / len(c)) ** 0.5 for c, m in zip(zip(*raw), means)]
    points = [[(v - m) / s for v, m, s in zip(x, means, spreads)] for x in raw]
    labels = best_clustering(points, groups)
    for g in range(groups):
        members = [i for i, l in enumerate(labels) if l == g]
        avg = [round(sum(raw[i][d] for i in members) / len(members), 3) for d in range(len(FEATURES))]
        print(g, len(members), dict(zip(FEATURES, avg)))
        print("   ", ", ".join(rows[i]["city"] for i in members))


def best_clustering(points: list, groups: int) -> list:
    random.seed(1)
    best = (float("inf"), [])
    for _ in range(30):
        centres = random.sample(points, groups)
        for _ in range(40):
            labels = [min(range(groups), key=lambda k: dist(p, centres[k])) for p in points]
            for k in range(groups):
                mine = [p for p, l in zip(points, labels) if l == k]
                if mine:
                    centres[k] = [sum(c) / len(mine) for c in zip(*mine)]
        spread = sum(dist(p, centres[l]) for p, l in zip(points, labels))
        if spread < best[0]:
            best = (spread, labels)
    return best[1]


def dist(a: list, b: list) -> float:
    return sum((x - y) ** 2 for x, y in zip(a, b))


main()
