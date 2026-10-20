"""Generate Wang tilesets with PixelLab and save them under art/raw/tiles/<name>.json."""
import json, os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
import pl

OUT = os.path.join(os.path.dirname(__file__), "raw", "tiles64")
P = "hand-painted stylized 3D mobile game ground texture, soft warm light, "
SETS = {
    "sea_sand": (P + "clear turquoise sea water with gentle ripples", P + "warm golden sandy beach", "wet dark sand shoreline with foam"),
    "sand_grass": (P + "pale sandy ground", P + "lush green grass with small tufts", ""),
    "grass_path": (P + "lush green grass", P + "worn brown dirt path with pebbles", ""),
    "grass_plaza": (P + "lush green grass", P + "packed light brown earth town square with scattered stones", ""),
    "grass_forest": (P + "lush green grass", P + "dark forest floor with fallen leaves, roots and moss", ""),
    "grass_pond": (P + "dark green pond water with lily pads", P + "lush green grass", "muddy reed bank"),
    "grass_ruin": (P + "lush green grass", P + "dry cracked dark earth with dead grass and rubble", ""),
    "grass_yard": (P + "lush green grass", P + "clean raked beige earth courtyard", ""),
}

# reuse base tiles so sand and grass look identical in every set they appear in
BASES = {
    "sand_grass": {"lower": ("sea_sand", "upper")},
    "grass_path": {"lower": ("sand_grass", "upper")},
    "grass_plaza": {"lower": ("sand_grass", "upper")},
    "grass_forest": {"lower": ("sand_grass", "upper")},
    "grass_pond": {"upper": ("sand_grass", "upper")},
    "grass_ruin": {"lower": ("sand_grass", "upper")},
    "grass_yard": {"lower": ("sand_grass", "upper")},
}


def main(names):
    os.makedirs(OUT, exist_ok=True)
    for n in names:
        path = os.path.join(OUT, n + ".json")
        if os.path.exists(path):
            continue
        lo, up, tr = SETS[n]
        extra = {}
        for side, (src, which) in BASES.get(n, {}).items():
            meta = json.load(open(os.path.join(OUT, src + ".json")))["metadata"]
            extra[side + "_base_tile_id"] = meta["terrain_ids"][which]
        r = pl.post("/create-tileset", {**extra,
            "lower_description": lo, "upper_description": up, "transition_description": tr,
            "tile_size": {"width": 64, "height": 64}, "view": "high top-down", "mode": "pro",
            "transition_size": 0.25 if tr else 0.0, "raggedness": 0.5, "seed": 7,
        })
        tid = r.get("tileset_id") or r.get("id")
        print(n, "->", tid, flush=True)
        j = pl.wait_job(r["background_job_id"])
        st = j["status"]
        t = pl.get(f"/tilesets/{tid}") if st == "completed" else j
        json.dump(t, open(path, "w"))
        print(n, st, flush=True)

if __name__ == "__main__":
    main(sys.argv[1:] or list(SETS))
