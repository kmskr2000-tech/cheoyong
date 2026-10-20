"""Generate Wang tilesets with PixelLab and save them under art/raw/tiles/<name>.json."""
import json, os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
import pl

OUT = os.path.join(os.path.dirname(__file__), "raw", "tiles")
SETS = {
    "sea_sand": ("deep dark blue sea water at night with soft moonlit ripples", "pale sandy beach, fine sand with small shells", "wet dark sand shoreline with foam"),
    "sand_grass": ("pale sandy ground", "short dark green grass with tiny clovers", ""),
    "grass_path": ("short dark green grass", "packed brown dirt road", ""),
    "grass_plaza": ("short dark green grass", "grey square stone paving slabs of an old Korean town plaza", ""),
    "grass_forest": ("short dark green grass", "dark forest floor with pine needles, roots and moss", ""),
    "grass_pond": ("murky green swamp pond water with lily pads", "short dark green grass", "muddy reed bank"),
    "grass_ruin": ("short dark green grass", "dry cracked grey earth with scattered rubble, cursed wasteland", ""),
    "grass_yard": ("short dark green grass", "clean raked light brown earth courtyard", ""),
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
            "tile_size": {"width": 32, "height": 32}, "view": "high top-down",
            "outline": "lineless", "shading": "medium shading", "detail": "medium detail",
            "transition_size": 0.25 if tr else 0.0, "seed": 7,
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
