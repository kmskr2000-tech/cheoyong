"""Collect the game's development status for the status board: build/status/*.json

chars.json     every character: role, art kind (3d / sprite / procedural / blender / missing), clip count
chapters.json  chapters 1-6: title, boss, last headless check (build/status/verify_*.json)
work.json      docs/roadmap.json items
commits.json   recent commits on the current branch
Usage: python3 tools/status.py [--verify]   (--verify reruns the Godot headless checks first, ~6 min)
"""
import glob, json, os, re, subprocess, datetime

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "build", "status")
G = os.path.join(ROOT, "godot")


def read(p):
    return open(os.path.join(ROOT, p), encoding="utf-8").read()


def chars():
    man = json.load(open(os.path.join(G, "assets", "manifest.json")))["chars"]
    ent = read("godot/scripts/ent.gd")
    defs = {}
    for m in re.finditer(r'^\s*"([a-z_]+)": \{"name": "([^"]+)"(.*)\},?$', ent, re.M):
        if '"hp"' in m.group(3):
            defs[m.group(1)] = {"name": m.group(2), "boss": '"boss": true' in m.group(3),
                                "alt": (re.search(r'"alt": "([a-z_]+)"', m.group(3)) or [None, None])[1]}
    names = {}
    for f in glob.glob(os.path.join(G, "scripts", "**", "*.gd"), recursive=True):
        for m in re.finditer(r'\["[a-z_0-9]+", "([a-z_]+)", [0-9.]+, [0-9.]+, "([^"]+)"', open(f, encoding="utf-8").read()):
            names.setdefault(m.group(1), m.group(2))
    names["cheoyong"] = "처용"
    bosses = {}
    for f in sorted(glob.glob(os.path.join(G, "scripts", "chapters", "ch*.gd"))):
        n = int(re.search(r"ch(\d)", f).group(1))
        for m in re.finditer(r'"type": "([a-z_]+)"', open(f, encoding="utf-8").read()):
            bosses[m.group(1)] = n
    rows = []
    for cid in sorted(set(man) | set(defs)):
        d = defs.get(cid, {})
        role = "주인공" if cid == "cheoyong" else "보스" if d.get("boss") else "요괴" if d else "사람"
        glb = os.path.join(G, "assets", "models", cid + ".glb")
        meta_p = os.path.join(ROOT, "art", "raw", "chibi", cid, "metadata.json")
        meta = json.load(open(meta_p)) if os.path.exists(meta_p) else None
        src = ""
        if meta:
            st = meta["states"][0]
            src = "procedural" if st.get("procedural") or meta.get("procedural") else st.get("character", {}).get("source", "")
        if os.path.exists(glb):
            art, label = "3d", "툰 3D"
            clips = len([k for k in json.load(open(glb + ".json")) if not k.startswith("_")])
        elif cid in man:
            art, label = ("procedural", "임시 애니(이미지 변형)") if src == "procedural" else \
                         ("blender", "Blender 도트") if src.startswith("blender") else ("sprite", "PixelLab 도트")
            clips = len(man[cid]["anims"])
        else:
            art, label, clips = "missing", "그림 없음 → " + (d.get("alt") or "-") + " 대용", 0
        rows.append({"id": cid, "name": d.get("name") or names.get(cid, cid), "role": role, "chapter": bosses.get(cid, ""),
                     "art": art, "art_label": label, "clips": clips})
    return rows


def chapters():
    rows = [{"n": 1, "title": "제1장 · 서라벌 — 처용가", "boss": "역신", "check": "ending"}]
    ent = read("godot/scripts/ent.gd")
    for f in sorted(glob.glob(os.path.join(G, "scripts", "chapters", "ch*.gd"))):
        s = open(f, encoding="utf-8").read()
        n = int(re.search(r"n = (\d)", s).group(1))
        title = re.search(r'title = "([^"]+)"', s).group(1)
        b = re.search(r'"type": "([a-z_]+)"', s).group(1)
        bn = re.search(r'"%s": \{"name": "([^"]+)"' % b, ent).group(1)
        rows.append({"n": n, "title": title, "boss": bn, "check": "ch%d" % n})
    for r in rows:
        p = os.path.join(OUT, "verify_%s.json" % r["check"])
        v = json.load(open(p)) if os.path.exists(p) else {}
        res = v.get("result", "")
        r["result"] = "통과" if res.startswith(("CHAPTER DONE", "REACHED ENDING")) else ("실패" if res else "미실행")
        r["detail"] = res
        r["checked_at"] = datetime.datetime.fromtimestamp(os.path.getmtime(p)).strftime("%Y-%m-%d %H:%M") if v else ""
        r["minutes"] = round(v.get("secs", 0) / 60, 1) if v else None
    return rows


def commits():
    out = subprocess.run(["git", "-C", ROOT, "log", "-15", "--date=short", "--pretty=format:%h\t%ad\t%s"], capture_output=True, text=True).stdout
    return [dict(zip(("hash", "date", "subject"), l.split("\t", 2))) for l in out.splitlines()]


def verify():
    """chapters 2-6 in parallel, then the full run from the title to the ending (chapter 1 included)"""
    import time
    def start(args):
        return subprocess.Popen(["godot", "--headless", "--path", G, "--"] + args + ["--auto", "--speed=8", "--mute"],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    def finish(name, p, t0):
        out, _ = p.communicate()
        hit = [l for l in out.splitlines() if l.startswith(("CHAPTER DONE", "REACHED ENDING"))]
        json.dump({"check": name, "result": hit[0] if hit else "FAIL", "secs": round(time.time() - t0)},
                  open(os.path.join(OUT, "verify_%s.json" % name), "w"))
        print(name, hit[0] if hit else "FAIL", flush=True)
    t0 = time.time()
    runs = {"ch%d" % n: start(["--chapter=%d" % n]) for n in range(2, 7)}
    for name, p in runs.items():
        finish(name, p, t0)
    t0 = time.time()
    finish("ending", start(["--skipintro"]), t0)


def main():
    os.makedirs(OUT, exist_ok=True)
    if "--verify" in os.sys.argv:
        verify()
    branch = subprocess.run(["git", "-C", ROOT, "branch", "--show-current"], capture_output=True, text=True).stdout.strip()
    work = json.load(open(os.path.join(ROOT, "docs", "roadmap.json")))["items"]
    for name, rows in (("chars", chars()), ("chapters", chapters()), ("work", work), ("commits", [dict(c, branch=branch) for c in commits()])):
        json.dump(rows, open(os.path.join(OUT, name + ".json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print(name, len(rows))


if __name__ == "__main__":
    main()
