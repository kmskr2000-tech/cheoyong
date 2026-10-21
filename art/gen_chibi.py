"""Chibi '3D render' cast in the style of the reference (도깨비의 세계): big heads, cel shading, no outline.

Reuses the job/animation logic of gen_chars.py with new specs.
Usage: python3 art/gen_chibi.py [--parallel] <name> ...   -> art/raw/chibi/<name>/
"""
import json, os, sys, threading, time
sys.path.insert(0, os.path.dirname(__file__))
import gen_chars as G
import pl

G.RAW = os.path.join(os.path.dirname(__file__), "raw", "chibi")
STYLE = ("chibi 3D rendered mobile MMORPG character, big head small body, smooth cel shading, soft warm lighting, "
         "no outline, Korean Silla folklore, ")
D8, D5, D3 = G.DIRS8, G.DIRS5, G.DIRS3
WALK = ("walk", "tpl:walking-6-frames", D5)
NPC = []  # people only need the 8 rotations

G.CHARS = {
    "cheoyong": ("Korean Silla hero Cheoyong wearing a black gat hat with a pink peony flower, white and navy hanbok robe with red sash, holding a bamboo flute", 128, "mannequin", [
        ("walk", "tpl:walking-6-frames", D8),
        ("attack", "v3:6:swinging a long robe sleeve in a fast horizontal slash", D8),
        ("cast", "v3:8:playing a bamboo flute and dancing, sleeves raised", ["south"]),
    ]),
    "yongwang": ("Dragon King of the East Sea, old man with long white beard, golden dragon crown, sea-green and gold royal robes, pearl staff", 128, "mannequin", NPC),
    "king": ("King Heongang of Silla, black beard, golden Silla crown with jade pendants, crimson royal robe with gold embroidery, full body", 128, "mannequin", NPC),
    "wife": ("young Silla noblewoman, hair in an elegant bun with a gold hairpin, pale pink jeogori and long white skirt", 128, "mannequin", NPC),
    "halmi": ("old grandmother shaman, bent back, white hair bun, grey hanbok, wooden cane", 128, "mannequin", NPC),
    "merchant": ("cheerful plump market merchant, cloth headband, brown vest, wooden A-frame backpack", 128, "mannequin", NPC),
    "hwarang": ("young hwarang warrior, black hat with a feather, blue and white tunic, sword at the hip", 128, "mannequin", NPC),
    "dosa": ("Taoist sage, tall old man with long white beard, wide black gat hat, white robe, white feather fan", 128, "mannequin", NPC),
    "child": ("small village child with a topknot, short beige hanbok", 96, "mannequin", NPC),
    "sick": ("sick pale villager man, ragged grey clothes, bandage around the head, hunched", 128, "mannequin", NPC),
    "monk": ("Buddhist monk, shaved head, grey robe with brown sash, wooden prayer beads", 128, "mannequin", NPC),
    "sansin": ("mountain spirit Sansin, ancient old man with very long white beard, white robe, gnarled staff, faint blue glow", 128, "mannequin", NPC),
    "villager": ("village woman with a water jar on her head, dark blue skirt and white jeogori", 128, "mannequin", NPC),
    "dog": ("small yellow jindo dog, curled tail, cute", 96, "dog", []),
    "imp": ("small mischievous red dokkaebi goblin, one stubby horn, wild hair, tiger-skin loincloth, tiny club", 96, "mannequin", [
        WALK, ("attack", "v3:6:jumping forward and smacking down with a wooden club", D3)]),
    "dokkaebi": ("burly blue dokkaebi ogre, two horns, wild hair, tiger-skin clothes, big spiked club", 128, "mannequin", [
        WALK, ("attack", "v3:6:raising a heavy spiked club overhead and slamming it down", D3)]),
    "ghoul": ("dueoksini, hulking grey ghoul demon, hunched back, long clawed arms, glowing purple eyes, tattered rags", 128, "mannequin", [
        WALK, ("attack", "v3:6:raising both clawed arms high and slamming the ground", D3)]),
    "ghost": ("wonhon ghost, pale woman in a white hanbok with long black hair, floating, ghostly glow", 128, "mannequin", [
        ("walk", "v3:6:floating forward, hair and sleeves drifting", D5), ("attack", "v3:6:thrusting both hands forward casting a ghost orb", D3)]),
    "snake": ("giant dark green serpent gureongi with purple cursed glow, coiled, head raised", 128, "cat", [
        ("walk", "v3:6:slithering forward", D5), ("attack", "v3:6:lunging forward with a fast bite", D3)]),
    "dokchief": ("dokkaebi chieftain, giant muscular red goblin king with three horns, golden earrings, tiger pelt cape, huge iron club", 192, "mannequin", [
        ("walk", "tpl:walking-6-frames", D5), ("attack", "v3:6:swinging a huge club in a wide arc", D3),
        ("kneel", "v3:6:dropping to one knee in defeat, head bowed", ["south"])]),
    "gumiho": ("one single large white fox with one head and nine fluffy tails fanned out, glowing blue fox fire at the tail tips", 192, "dog", [
        ("walk", "v3:6:running forward gracefully", D5), ("attack", "v3:6:pouncing and slashing with claws", D3),
        ("kneel", "v3:6:lying down and bowing its head in defeat", ["south"])]),
    "imugi": ("imugi, giant serpent dragon without horns, dark teal scales, glowing yellow eyes, coiled body rising", 192, "cat", [
        ("walk", "v3:6:slithering and swaying", D5), ("attack", "v3:6:striking forward with open jaws", D3),
        ("kneel", "v3:6:lowering its head to the ground in defeat", ["south"])]),
    "yeoksin": ("Yeoksin the plague spirit, tall gaunt demon in tattered dark purple robes, pale grey skin, long black hair, glowing red eyes, green miasma", 192, "mannequin", [
        ("walk", "tpl:walking-6-frames", D5), ("attack", "v3:6:casting a dark spell with both hands", D3),
        ("kneel", "v3:6:kneeling on both knees with head bowed in surrender", ["south"])]),
    # --- chapters 2-6 (경주 순례) ---
    "chungdam": ("Buddhist monk-poet Chungdam, middle-aged, shaved head, brown robe, carrying a tea set wrapped in cloth on his back", 128, "mannequin", NPC),
    "wolmyeong": ("Buddhist monk Wolmyeong, young monk with a shaved head, grey robe, holding a long bamboo flute", 128, "mannequin", NPC),
    "suro": ("Lady Suro, beautiful Silla noblewoman, elaborate hair with flowers, flowing jade-green silk hanbok, gold ornaments", 128, "mannequin", NPC),
    "noin": ("old farmer with a white beard, straw hat, plain hemp clothes, holding a red azalea flower bouquet", 128, "mannequin", NPC),
    "heemyeong": ("village mother Heemyeong, plain white hanbok, hair in a low bun, kind tired face, praying hands", 128, "mannequin", NPC),
    "mabu": ("Silla post station horse keeper, sturdy man with a cloth headband, brown tunic, leather boots, holding a horse whip", 128, "mannequin", NPC),
    "jangsanbeom": ("jangsanbeom, white long-haired four-legged mountain beast like a shaggy tiger with hidden face, glowing eyes", 128, "dog", [
        ("walk", "v3:6:prowling forward quickly", D5), ("attack", "v3:6:pouncing forward with claws", D3)]),
    "mulgwisin": ("mulgwisin water ghost, drowned pale man with seaweed hair dripping water, tattered blue rags, floating", 128, "mannequin", [
        ("walk", "v3:6:floating forward, dripping water", D5), ("attack", "v3:6:throwing a ball of dark water with both hands", D3)]),
    "seokjang": ("corrupted stone guardian statue warrior, grey granite body with cracks, glowing purple eyes, stone sword", 128, "mannequin", [
        WALK, ("attack", "v3:6:swinging a heavy stone sword downward", D3)]),
    "kkoktu": ("kkokdu wooden puppet demon, jointed wooden doll in faded red and blue hanbok, painted mask face, strings hanging", 128, "mannequin", [
        WALK, ("attack", "v3:6:spinning and slashing with wooden arms", D3)]),
    "hwagwi": ("hwagwi fire spirit, small floating demon made of orange flames with a black ember face", 128, "mannequin", [
        ("walk", "v3:6:floating forward, flames flickering", D5), ("attack", "v3:6:spitting a fireball forward", D3)]),
    "bulgasari": ("bulgasari, huge iron-eating beast with a bear body, elephant trunk, rhinoceros eyes, metal spikes on its back, dark iron skin", 192, "dog", [
        ("walk", "v3:6:stomping forward heavily", D5), ("attack", "v3:6:rearing up and slamming down with front paws", D3),
        ("kneel", "v3:6:lying down and lowering its head in defeat", ["south"])]),
    "eoduksini": ("eoduksini, towering giant made of black smoke and darkness, long arms, two glowing white eyes, wisps of shadow", 192, "mannequin", [
        ("walk", "v3:6:looming forward, shadow wisps trailing", D5), ("attack", "v3:6:sweeping a giant shadow arm across", D3),
        ("kneel", "v3:6:shrinking down to its knees, head bowed", ["south"])]),
    "haeryong": ("haeryong sea dragon, long blue-green Korean dragon with a pearl, horns and whiskers, coiled, water splashing", 192, "cat", [
        ("walk", "v3:6:slithering and swaying through water", D5), ("attack", "v3:6:lunging forward breathing a jet of water", D3),
        ("kneel", "v3:6:lowering its head to the ground in defeat", ["south"])]),
    "geuseundae": ("geuseundae, very tall thin shadow giant in a black hooded robe, long thin arms, a pale mask face, purple flames around it", 192, "mannequin", [
        ("walk", "tpl:walking-6-frames", D5), ("attack", "v3:6:stretching a long arm and slamming the ground", D3),
        ("kneel", "v3:6:kneeling on both knees with head bowed in surrender", ["south"])]),
    "samjogo": ("samjogo, giant three-legged black crow with golden sun disc behind it, fiery red eyes, burning feathers", 192, "cat", [
        ("walk", "v3:6:hopping forward, wings half open", D5), ("attack", "v3:6:flapping wings and shooting a fire blast", D3),
        ("kneel", "v3:6:folding its wings and bowing its head to the ground", ["south"])]),
}


def ensure_character(name, meta):
    desc, size, template, _ = G.CHARS[name]
    if meta.get("id"):
        return meta
    body = {"description": STYLE + desc, "name": "chibi_" + name, "view": "high top-down", "template_id": template,
            "image_size": {"width": size, "height": size}, "outline": "lineless", "detail": "highly detailed", "seed": 21}
    r = pl.post("/create-character-v3", body)
    c = pl.wait_character(r["character_id"])
    print(name, "character", c["status"], flush=True)
    meta["id"] = c["id"]
    return meta


G.ensure_character = ensure_character

if __name__ == "__main__":
    args = sys.argv[1:]
    os.makedirs(G.RAW, exist_ok=True)
    if args and args[0] == "--parallel":
        def worker(n):
            for attempt in range(3):
                try:
                    G.main([n]); return
                except Exception as e:
                    print(n, "retry", attempt, e, flush=True); time.sleep(20)
            print(n, "FAILED", flush=True)
        ts = [threading.Thread(target=worker, args=(n,)) for n in args[1:]]
        for t in ts:
            t.start(); time.sleep(3)
        for t in ts:
            t.join()
    else:
        G.main(args)
