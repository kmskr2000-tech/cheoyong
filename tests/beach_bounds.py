#!/usr/bin/env python3
"""B02 regression: from the beach spawn, the walkable region must not reach the plateau north of the cliff line
(collision rects from assets/levels/beach.json + Levels 'walls' seals + world edge). 4px grid, hero ~ 6px box."""
import json, re, sys, os
here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src")
m = json.load(open(os.path.join(here, "assets/levels/beach.json")))
lv = open(os.path.join(here, "scripts/levels.gd")).read()
beach = lv[lv.index('"beach": {'):lv.index('"gyeongju": {')]
walls = [[float(x) for x in w] for w in re.findall(r'Rect2\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)\)', beach.split('"walls"')[1].split("\n")[0])] if '"walls"' in beach else []
rects = m["collision"] + walls
W, off = m["size"][0], m["offset"]
H = m["size"][1] - m["tier"]
R = 3
def free(x, y):
    if x < R or x > W - R or y < -off + R or y > H - R: return False
    for rx, ry, rw, rh in rects:
        if rx - R < x < rx + rw + R and ry - R < y < ry + rh + R: return False
    return True
start = (100, round(262 * 0.75 - 0))  # lifted spawn approx; verified below by free()
sx, sy = 100, None
for y in range(120, 240, 4):
    if free(100, y): sy = y
assert sy, "no free start"
seen, st = {(100, sy)}, [(100, sy)]
while st:
    x, y = st.pop()
    for dx, dy in ((4, 0), (-4, 0), (0, 4), (0, -4)):
        n = (x + dx, y + dy)
        if n not in seen and free(*n):
            seen.add(n); st.append(n)
top = min(y for _, y in seen)
print("walkable cells", len(seen), "min y", top)
if top < 30:
    print("FAIL beach north bound escaped: min y", top); sys.exit(1)
print("PASS beach north bound (min y %d)" % top)
