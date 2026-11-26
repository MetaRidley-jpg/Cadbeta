"""Placeholder gallery art for the Challenges wall (art/gallery/placeholder_0N.png).
1440x2560 so zoom and pan can be tested. T replaces these with real pieces
(any size works; keep the file names or edit data/challenges.json)."""
import json, math, random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/gallery"
W, H = 1440, 2560

def font(sz):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
        try: return ImageFont.truetype(p, sz)
        except OSError: pass
    return ImageFont.load_default()

def stack(name, angle, scale, spacing):
    """Render a carved strip the sprite-stacking way: slices bottom-up, each rotated, lifted."""
    strip = Image.open(ROOT / f"art/stacks/{name}.png").convert("RGBA")
    n = json.load(open(ROOT / f"art/stacks/{name}.json"))["slices"]
    w, h = strip.width // n, strip.height
    size = int((w + h) * scale * 1.2 + n * spacing * scale)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for k in range(n):
        sl = strip.crop((k * w, 0, (k + 1) * w, h)).resize((w * scale, h * scale), Image.NEAREST)
        sl = sl.rotate(angle, resample=Image.NEAREST, expand=True)
        sl = sl.resize((sl.width, int(sl.height * 0.62)), Image.NEAREST)
        out.alpha_composite(sl, (size // 2 - sl.width // 2, size // 2 - sl.height // 2 - int(k * spacing * scale)))
    # one outline around the finished stack
    a = out.getchannel("A").point(lambda v: 255 if v else 0)
    ring = Image.new("RGBA", out.size, (26, 15, 46, 0))
    for dx, dy in [(-scale, 0), (scale, 0), (0, -scale), (0, scale)]:
        ring.paste((26, 15, 46, 255), (dx, dy), a)
    ring.alpha_composite(out)
    return ring

def bands(d, top, bot, n, y0, y1):
    for i in range(n):
        t = i / (n - 1)
        c = tuple(int(top[j] + (bot[j] - top[j]) * t) for j in range(3))
        d.rectangle([0, y0 + (y1 - y0) * i // n, W, y0 + (y1 - y0) * (i + 1) // n], fill=c)

def piece(idx, title, sky_top, sky_bot, sun, sea, objs, seed):
    rnd = random.Random(seed)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(im)
    bands(d, sky_top, sky_bot, 14, 0, 1500)
    for r in range(380, 0, -38):                              # banded sun
        d.ellipse([W // 2 - r, 1100 - r, W // 2 + r, 1100 + r], fill=sun[(r // 38) % 2])
    bands(d, sea[0], sea[1], 10, 1500, H)
    for k in range(70):                                       # crest dashes
        x, y = rnd.randint(0, W), rnd.randint(1520, H)
        d.rectangle([x, y, x + rnd.randint(30, 120), y + 8], fill=sea[2])
    for name, ang, sc, sp, x, y in objs:
        s = stack(name, ang, sc, sp)
        im.alpha_composite(s, (x - s.width // 2, y - s.height // 2))
    # zoom test detail: a fine 8 px checker block with tiny labels
    for gy in range(0, 160, 8):
        for gx in range(0, 160, 8):
            if (gx + gy) // 8 % 2:
                d.rectangle([60 + gx, H - 260 + gy, 67 + gx, H - 253 + gy], fill=(255, 246, 228))
    d.text((240, H - 250), "zoom test: 8 px checker", font=font(28), fill=(255, 246, 228))
    d.rectangle([0, 0, W, 200], fill=(21, 18, 26))
    d.text((60, 40), f"PLACEHOLDER ART {idx:02d}", font=font(64), fill=(242, 106, 27))
    d.text((60, 120), f"{title}  ·  {W}x{H}  ·  redraw me", font=font(36), fill=(239, 230, 210))
    im.convert("RGB").save(OUT / f"placeholder_{idx:02d}.png")

OUT.mkdir(parents=True, exist_ok=True)
piece(1, "The Bone Yard", (255, 160, 80), (255, 230, 170), [(255, 210, 90), (255, 140, 60)],
      [(30, 120, 160), (10, 50, 110), (120, 220, 255)],
      [("palm", 20, 12, 1, 300, 1750), ("palm", -40, 9, 1, 1150, 1850), ("spire", 10, 12, 1, 760, 1600)], 1)
piece(2, "Pilot Pin-up", (40, 30, 90), (255, 90, 140), [(255, 120, 200), (255, 60, 120)],
      [(60, 20, 70), (20, 10, 40), (255, 120, 200)],
      [("jet_player", 35, 22, 1, 720, 1500), ("jet_ghost", -20, 9, 1, 300, 600), ("jet_crimson", 200, 9, 1, 1160, 820)], 2)
piece(3, "Ash Over the Islands", (60, 30, 60), (240, 110, 60), [(255, 220, 90), (255, 80, 0)],
      [(60, 20, 40), (30, 10, 30), (255, 120, 0)],
      [("volcano", 0, 14, 1, 720, 1650), ("asteroid", 30, 10, 1, 1150, 450)], 3)
print("ok")
