"""Steam store capsules from in-game key shots: build/steam/*.png

Key shots are 1920x1080 captures without HUD, e.g.
  xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 --path godot --resolution 1920x1080 \
      -- --quest=4 --at=24,62 --enemies=ghoul,imp --nohud --capture=build/steam/shots/forest.png --frames=170
Usage: python3 tools/steam_art.py <key shot for wide capsules> [<key shot for tall capsules>]
"""
import os, sys
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "build", "steam")
TITLE = os.path.join(ROOT, "godot", "fonts", "SongMyung-Regular.ttf")
SERIF = os.path.join(ROOT, "godot", "fonts", "GowunBatang-Bold.ttf")
SIZES = {"header_capsule": (460, 215), "small_capsule": (231, 87), "main_capsule": (616, 353),
         "vertical_capsule": (374, 448), "library_capsule": (600, 900), "library_hero": (3840, 1240)}


def cover(im, w, h, focus=(0.5, 0.5)):
    k = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    x = int((im.width - w) * focus[0]); y = int((im.height - h) * focus[1])
    return im.crop((x, y, x + w, y + h))


def grade(im):
    im = ImageEnhance.Color(im).enhance(0.85)
    im = ImageEnhance.Contrast(im).enhance(1.08)
    w, h = im.size
    vig = Image.radial_gradient("L").resize((w, h)).point(lambda v: int(min(255, v * 1.1)))
    dark = Image.new("RGB", (w, h), (10, 8, 14))
    return Image.composite(dark, im, vig.point(lambda v: int(v * 0.75)))


def title(im, scale=1.0, where="center", sub=True):
    d = ImageDraw.Draw(im, "RGBA")
    w, h = im.size
    fs = max(14, int(min(w * 0.16, h * 0.42) * scale))
    f = ImageFont.truetype(TITLE, fs)
    text = "신 처용가"
    tb = d.textbbox((0, 0), text, font=f)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    x = (w - tw) // 2 - tb[0]
    y = int(h * (0.42 if where == "center" else 0.74)) - th // 2 - tb[1]
    band = Image.new("RGBA", im.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(band)
    bd.rectangle((0, y + tb[1] - th * 0.5, w, y + tb[3] + th * (1.1 if sub else 0.6)), fill=(6, 5, 9, 120))
    im.alpha_composite(band.filter(ImageFilter.GaussianBlur(max(2, th // 3)))) if im.mode == "RGBA" else None
    d = ImageDraw.Draw(im, "RGBA")
    for o in (3, 2):
        d.text((x + o, y + o), text, font=f, fill=(0, 0, 0, 120))
    d.text((x, y), text, font=f, fill=(238, 222, 186, 255))
    if sub and fs >= 40:
        sf = ImageFont.truetype(SERIF, max(12, fs // 4))
        st = "탈과 노래"
        sb = d.textbbox((0, 0), st, font=sf)
        d.text(((w - (sb[2] - sb[0])) // 2, y + tb[3] + fs // 6), st, font=sf, fill=(201, 164, 92, 255))
        lw = int(tw * 0.5)
        d.line(((w - lw) // 2, y + tb[3] + fs // 9, (w + lw) // 2, y + tb[3] + fs // 9), fill=(201, 164, 92, 200), width=max(1, fs // 40))
    return im


def main():
    a = sys.argv[1:]
    wide = Image.open(a[0]).convert("RGB")
    tall = Image.open(a[1] if len(a) > 1 else a[0]).convert("RGB")
    os.makedirs(OUT, exist_ok=True)
    for name, (w, h) in SIZES.items():
        src = tall if h > w else wide
        im = grade(cover(src, w, h)).convert("RGBA")
        if name != "library_hero":  # the hero carries no text; Steam lays the logo over it
            im = title(im, 1.0 if w >= 300 else 1.25, "low" if h > w else "center", sub=h >= 200)
        im.convert("RGB").save(os.path.join(OUT, name + ".png"))
        print(name, w, h)
    # logo on transparency for the library (1280x720)
    logo = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    d = ImageDraw.Draw(logo)
    f = ImageFont.truetype(TITLE, 230)
    tb = d.textbbox((0, 0), "신 처용가", font=f)
    x = (1280 - (tb[2] - tb[0])) // 2 - tb[0]; y = (720 - (tb[3] - tb[1])) // 2 - tb[1] - 40
    d.text((x + 6, y + 6), "신 처용가", font=f, fill=(0, 0, 0, 140))
    d.text((x, y), "신 처용가", font=f, fill=(238, 222, 186, 255))
    sf = ImageFont.truetype(SERIF, 64)
    sb = d.textbbox((0, 0), "탈과 노래", font=sf)
    d.text(((1280 - (sb[2] - sb[0])) // 2, y + tb[3] + 40), "탈과 노래", font=sf, fill=(201, 164, 92, 255))
    logo.save(os.path.join(OUT, "logo.png"))
    print("logo 1280 720")


if __name__ == "__main__":
    main()
