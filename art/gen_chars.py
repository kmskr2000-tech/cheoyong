"""Create PixelLab characters and their animations, then download each as a zip.

Usage: python3 art/gen_chars.py <name> [...]   (specs in CHARS below)
Results: art/raw/chars/<name>/ (unzipped export) and art/raw/chars/<name>.json (ids).
"""
import io, json, os, sys, time, zipfile
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
import pl

RAW = os.path.join(os.path.dirname(__file__), "raw", "chars")
DIRS8 = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
DIRS4 = ["south", "east", "north", "west"]

STYLE = "Korean Silla dynasty folklore, dark fantasy night, "

# name: (description, size, template, animations)
# animation: (key, spec, directions)  spec = "tpl:<template id>" or "v3:<frames>:<action text>"
DIRS5 = ["south", "south-east", "east", "north-east", "north"]  # west side is mirrored in game
DIRS3 = ["south", "east", "north"]
IDLE = [("idle_anim", "tpl:breathing-idle", ["south"])]
WALK5 = ("walk", "tpl:walking-6-frames", DIRS5)

CHARS = {
    "cheoyong": (None, 96, "mannequin", [
        ("walk", "tpl:walking-6-frames", DIRS8),
        ("attack", "v3:6:swinging long robe sleeve in a fast horizontal slash, dance-like strike", DIRS8),
        ("cast", "v3:8:playing a bamboo flute and dancing a slow mask dance, sleeves raised", ["south"]),
    ]),
    # --- people ---
    "yongwang": ("Dragon King of the East Sea, regal old man with long white beard, golden dragon crown with small horns, flowing sea-green and gold royal robes with wave patterns, holding a pearl staff", 96, "mannequin", IDLE),
    "king": ("full body standing figure, King Heongang of Silla, middle-aged king with neat black beard, ornate golden Silla crown with jade pendants, crimson royal robe with golden embroidery, long robe down to the shoes", 96, "mannequin", IDLE),
    "wife": ("beautiful young Silla noblewoman, black hair in an elegant bun with a gold hairpin, pale pink jeogori and long white skirt hanbok", 96, "mannequin", IDLE),
    "halmi": ("old Korean grandmother shaman, bent back, white hair bun, plain grey hanbok, wooden walking cane, prayer beads", 96, "mannequin", IDLE),
    "merchant": ("cheerful plump Korean market merchant, cloth headband, brown vest over beige hanbok, carrying a wooden A-frame backpack", 96, "mannequin", IDLE),
    "hwarang": ("young Silla hwarang warrior, black hat with a feather, blue and white tunic, leather belt, sword at the hip, standing guard", 96, "mannequin", IDLE),
    "dosa": ("Taoist sage hermit, tall thin old man with long white beard, wide black gat hat, white flowing robe, holding a white feather fan", 96, "mannequin", IDLE),
    "child": ("small Korean village child with a topknot, short beige hanbok, cheerful", 64, "mannequin", IDLE),
    "sick": ("sick weak Korean villager man, pale greenish face, ragged grey clothes, cloth bandage around the head, hunched over", 96, "mannequin", IDLE),
    "monk": ("Korean Buddhist monk, shaved head, grey robe with a brown kasaya sash, holding wooden prayer beads", 96, "mannequin", IDLE),
    "sansin": ("Korean mountain spirit Sansin, ancient old man with very long white beard and eyebrows, white robe, gnarled wooden staff, faint blue glow", 96, "mannequin", IDLE),
    "villager": ("Korean village woman with a water jar on her head, dark blue skirt and white jeogori", 96, "mannequin", IDLE),
    "dog": ("small yellow Korean jindo dog, curled tail", 48, "dog", []),
    # --- yokai ---
    "imp": ("small mischievous Korean dokkaebi goblin, red skin, one stubby horn, wild black hair, tiger-skin loincloth, tiny wooden club", 64, "mannequin", [
        WALK5, ("attack", "v3:6:jumping forward and smacking down with a wooden club", DIRS3)]),
    "dokkaebi": ("Korean dokkaebi ogre, burly blue skin, two horns, wild hair, tiger-skin clothes, big spiked wooden club", 96, "mannequin", [
        WALK5, ("attack", "v3:6:raising a heavy spiked club overhead and slamming it down", DIRS3)]),
    "ghoul": ("dueoksini, hulking shadowy Korean ghoul demon, dark grey skin, hunched back, long clawed arms, glowing purple eyes, tattered rags", 96, "mannequin", [
        WALK5, ("attack", "v3:6:raising both clawed arms high and slamming the ground", DIRS3)]),
    "ghost": ("Korean wonhon ghost, pale woman in a white hanbok, long black hair hiding the face, floating, ghostly", 96, "mannequin", [
        ("walk", "v3:6:floating forward slowly, hair and sleeves drifting", DIRS5), ("attack", "v3:6:thrusting both hands forward casting a ghost orb", DIRS3)]),
    "snake": ("giant dark green Korean serpent gureongi with purple cursed glow, coiled body, head raised", 96, "cat", [
        ("walk", "v3:6:slithering forward", DIRS5), ("attack", "v3:6:lunging forward with a fast bite", DIRS3)]),
    # --- bosses ---
    "dokchief": ("dokkaebi chieftain, giant muscular red-skinned Korean goblin king with three horns, golden earrings, tiger pelt cape, huge iron-studded club", 144, "mannequin", [
        ("walk", "v3:6:stomping forward heavily", DIRS5), ("attack", "v3:6:swinging a huge club in a wide arc", DIRS3),
        ("kneel", "v3:6:dropping to one knee in defeat, head bowed", ["south"])]),
    "gumiho": ("one single large white fox with one head and nine fluffy tails fanned out behind it, gumiho fox spirit, glowing blue fox fire at the tail tips, full body", 144, "dog", [
        ("walk", "v3:6:running forward gracefully", DIRS5), ("attack", "v3:6:pouncing and slashing with claws", DIRS3),
        ("kneel", "v3:6:lying down and bowing head in defeat", ["south"])]),
    "imugi": ("imugi, giant serpent dragon without horns, dark teal scales, glowing yellow eyes, coiled body rising from water", 144, "cat", [
        ("walk", "v3:6:slithering and swaying", DIRS5), ("attack", "v3:6:striking forward with open jaws", DIRS3),
        ("kneel", "v3:6:lowering its head to the ground in defeat", ["south"])]),
    "yeoksin": ("Yeoksin the plague spirit, tall gaunt demon in tattered dark purple robes, pale grey skin, long black hair, glowing red eyes, green miasma", 144, "mannequin", [
        ("walk", "v3:6:gliding forward menacingly, robes flowing", DIRS5), ("attack", "v3:6:casting a dark spell with both hands", DIRS3),
        ("kneel", "v3:6:kneeling on both knees with head bowed in surrender", ["south"])]),
}


def anim_body(cid, spec, dirs):
    kind, rest = spec.split(":", 1)
    if kind == "tpl":
        return {"character_id": cid, "mode": "template", "template_animation_id": rest, "directions": dirs}
    frames, text = rest.split(":", 1)
    return {"character_id": cid, "mode": "v3", "action_description": text,
            "frame_count": int(frames), "directions": dirs}


def run_jobs(jobs):
    for j in jobs:
        r = pl.wait_job(j)
        if r["status"] != "completed":
            print("   job failed", j, str(r.get("last_response"))[:300], flush=True)


def ensure_character(name, meta):
    desc, size, template, _ = CHARS[name]
    if meta.get("id"):
        return meta
    if desc is None:
        # rebuild from the rotations saved earlier (no new drawing)
        rot = os.path.join(RAW, name, "Idle", "rotations")
        body = {"description": name, "name": name, "view": "low top-down", "template_id": template,
                "reference_image": pl.b64png(os.path.join(rot, "south.png")),
                "direction_images": {d: pl.b64png(os.path.join(rot, d + ".png")) for d in DIRS8 if d != "south"}}
    else:
        body = {"description": STYLE + desc, "name": name, "view": "low top-down", "template_id": template,
                "image_size": {"width": size, "height": size}, "outline": "single color black outline",
                "detail": "medium detail", "seed": 11}
    r = pl.post("/create-character-v3", body)
    c = pl.wait_character(r["character_id"])
    print(name, "character", c["status"], flush=True)
    meta["id"] = c["id"]
    return meta


def existing_dirs(cid):
    """directions that already have frames on the server, per animation name"""
    out = {}
    try:
        c = pl.get(f"/characters/{cid}")
    except Exception:
        return out
    for a in c.get("animations", []):
        name = a.get("display_name") or a.get("animation_type") or ""
        dirs = [d["direction"] for d in a.get("directions", []) if d.get("frames")]
        out.setdefault(name, {"group": a.get("animation_group_id"), "dirs": []})["dirs"] += dirs
    return out


def tpl_name(spec):
    return spec.split(":", 1)[1] if spec.startswith("tpl:") else None


def main(names):
    os.makedirs(RAW, exist_ok=True)
    for name in names:
        mp = os.path.join(RAW, name + ".json")
        meta = json.load(open(mp)) if os.path.exists(mp) else {}
        meta = ensure_character(name, meta)
        json.dump(meta, open(mp, "w"), indent=1)
        done = meta.setdefault("anims", {})
        server = existing_dirs(meta["id"])
        for key, spec, dirs in CHARS[name][3]:
            have = server.get(key) or server.get(tpl_name(spec) or "-")
            if have and done.get(key) is not True:
                st = done.get(key) if isinstance(done.get(key), dict) else {"group": have["group"], "dirs": []}
                st["dirs"] = sorted(set(st["dirs"]) | set(have["dirs"]))
                st["group"] = st.get("group") or have["group"]
                done[key] = True if set(dirs) <= set(st["dirs"]) else st
        pending = []
        for key, spec, dirs in CHARS[name][3]:
            st = done.get(key)
            if st is True:
                continue
            st = st if isinstance(st, dict) else {"group": None, "dirs": []}
            todo = [d for d in dirs if d not in st["dirs"]]
            if not todo:
                continue
            if spec.startswith("tpl:"):
                r = pl.post("/characters/animations", dict(anim_body(meta["id"], spec, todo), animation_name=key))
                pending.append((key, st, todo, r["background_job_ids"]))
                print(name, key, "queued", len(todo), flush=True)
                continue
            # v3 makes one direction per request; later directions join the first one's group
            for d in todo:
                body = dict(anim_body(meta["id"], spec, [d]), animation_name=key)
                if st["group"]:
                    body["animation_group_id"] = st["group"]
                r = pl.post("/characters/animations", body)
                if not st["group"]:
                    st["group"] = r.get("animation_group_id")
                    run_jobs(r["background_job_ids"])  # group must exist before adding to it
                    st["dirs"].append(d)
                    done[key] = st
                    json.dump(meta, open(mp, "w"), indent=1)
                else:
                    pending.append((key, st, [d], r["background_job_ids"]))
                print(name, key, d, "queued", flush=True)
        for key, st, dirs, jobs in pending:
            run_jobs(jobs)
            st["dirs"] = sorted(set(st["dirs"]) | set(dirs))
            done[key] = st
            json.dump(meta, open(mp, "w"), indent=1)
        z = pl.req("GET", f"/characters/{meta['id']}/zip", raw=True)
        out = os.path.join(RAW, name)
        os.makedirs(out, exist_ok=True)
        zipfile.ZipFile(io.BytesIO(z)).extractall(out)
        print(name, "downloaded", pl.get("/balance")["subscription"]["generations"], flush=True)


if __name__ == "__main__":
    import threading
    args = sys.argv[1:]
    if args and args[0] == "--parallel":
        def worker(n):
            try:
                main([n])
            except Exception as e:
                print(n, "FAILED", e, flush=True)
        ts = [threading.Thread(target=worker, args=(n,)) for n in args[1:]]
        for t in ts:
            t.start()
            time.sleep(2)
        for t in ts:
            t.join()
    else:
        main(args)
