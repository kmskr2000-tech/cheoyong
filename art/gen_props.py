"""Generate map objects (props) with PixelLab /map-objects -> art/raw/props/<name>.png"""
import base64, json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
import pl

OUT = os.path.join(os.path.dirname(__file__), "raw", "props")
K = "Korean Silla dynasty, "
PROPS = {
    "pine": ("tall Korean red pine tree with dark green needle clusters and twisted reddish trunk", 80, 112),
    "pine2": ("round bushy dark green Korean pine tree, short thick trunk", 80, 96),
    "deadtree": ("dead leafless gnarled black tree, twisted branches, cursed", 80, 112),
    "bush": ("small round dark green shrub", 40, 32),
    "rock": ("mossy grey boulder", 48, 40),
    "reeds": ("clump of tall river reeds and cattails", 40, 48),
    "giwa": (K + "traditional hanok house with curved black clay tile roof (giwa), white plaster walls, wooden pillars, paper doors, stone base", 192, 160),
    "choga": (K + "traditional thatched straw roof cottage (choga), mud walls, small wooden door", 160, 128),
    "stall": (K + "market stall with cloth awning, wooden table with pottery and baskets of goods", 112, 96),
    "well": (K + "round stone water well with wooden roof frame and bucket", 72, 80),
    "brokenwell": (K + "ruined collapsed stone well, cracked stones, purple cursed mist", 80, 72),
    "pagoda": (K + "three-story grey granite stone pagoda (seokgatap) on a stone platform", 72, 144),
    "pavilion": (K + "small open wooden pavilion (jeongja) with curved tile roof and red pillars", 160, 144),
    "lantern": (K + "stone lantern (seokdeung) with glowing warm light inside", 40, 72),
    "jangseung": ("pair of Korean wooden jangseung village guardian totem poles with carved fierce faces", 64, 96),
    "wall": (K + "earthen wall segment with small black tile roof cap, straight horizontal", 128, 64),
    "ruinwall": (K + "broken crumbling stone wall segment, ruined", 112, 64),
    "gate": (K + "town south gate, wooden double doors under a black tile roof, stone pillars", 160, 160),
    "boat": ("small wooden Korean fishing boat pulled onto sand", 112, 64),
    "lamppost": ("tall wooden pole with a hanging glowing red paper lantern", 40, 96),
    "jars": ("cluster of Korean brown onggi earthenware jars (jangdok)", 64, 56),
    "shrine": ("small Korean mountain spirit shrine (sansingak) with tile roof and offering table", 112, 112),
    "cheoyonghouse": (K + "large elegant hanok mansion with curved black tile roof, wooden veranda (maru), red pillars, lanterns", 256, 192),
    "palanquin": (K + "royal palanquin with red silk canopy and golden phoenix ornaments, carried on poles", 112, 96),
    "altar": ("small stone altar with offering bowls and incense, glowing faintly blue", 64, 56),
    "lotus": ("floating lotus pads with pink lotus flowers on dark water", 64, 40),
    "cart": (K + "wooden ox cart with two big wheels, loaded with sacks", 96, 80),
    "bones": ("scattered animal bones and broken pottery on the ground, eerie", 56, 40),
}


def main(names):
    os.makedirs(OUT, exist_ok=True)
    for n in names:
        path = os.path.join(OUT, n + ".png")
        if os.path.exists(path):
            continue
        desc, w, h = PROPS[n]
        r = pl.post("/map-objects", {"description": desc, "image_size": {"width": w, "height": h},
                                     "view": "low top-down", "outline": "single color outline",
                                     "shading": "medium shading", "detail": "medium detail", "seed": 3})
        jid = r.get("background_job_id")
        oid = r.get("object_id") or r.get("id")
        j = pl.wait_job(jid) if jid else None
        res = pl.get(f"/map-objects/{oid}")
        lr = (j or {}).get("last_response") or {}
        img = None
        for src in (lr, res):
            for k in ("image", "images"):
                v = src.get(k) if isinstance(src, dict) else None
                if isinstance(v, list):
                    v = v[0] if v else None
                if isinstance(v, dict) and v.get("base64"):
                    img = base64.b64decode(v["base64"])
                elif isinstance(v, str) and len(v) > 100:
                    img = base64.b64decode(v)
        if img is None and res.get("download_url", "").startswith(pl.BASE):
            img = pl.fetch(res["download_url"])
        if img is None:
            print(n, "NO IMAGE", json.dumps(res)[:400], json.dumps(lr)[:400], flush=True)
            json.dump({"res": res, "job": j}, open(path + ".json", "w"))
            continue
        open(path, "wb").write(img)
        print(n, "ok", flush=True)


if __name__ == "__main__":
    main(sys.argv[1:] or list(PROPS))
