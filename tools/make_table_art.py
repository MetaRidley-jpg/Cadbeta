"""Placeholder art for the card room (T replaces these):
  art/table/felt.png           (blackjack) and art/table/felt_holdem.png (Hold'em): flat felt texture laid over the table top. Paint it in LIGHT
                               GREYS: the game multiplies it by the table skin's felt color.
                               Size: 256x208 (= the 64x52 felt area x4). Keep the rounded-corner alpha.
  art/table/chars/<id>.png     one image per manager, seated, facing you (any size; shown ~170 px tall).
  art/table/chars/cadavire_dealer.png   Cadavire in a dealer's suit, behind the table.
"""
from pathlib import Path
import random
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/table"
C = lambda h: tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

def font(sz):
    try:
        return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", sz)
    except OSError:
        return ImageFont.load_default()

def felt(lines=("BLACKJACK PAYS 3 TO 2", "DEALER STANDS ON 17"), out="felt.png"):
    W, H, S = 64, 52, 4
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, W - 1, H - 1], radius=11, fill=C("d8d8d8"))
    rnd = random.Random(3)
    for k in range(260):                       # felt speckle
        x, y = rnd.randrange(W), rnd.randrange(H)
        if im.getpixel((x, y))[3]:
            im.putpixel((x, y), C("cacaca") if k % 2 else C("e2e2e2"))
    d.rounded_rectangle([3, 3, W - 4, H - 4], radius=8, outline=C("f4f4f4"))   # printed inner line
    d.arc([10, -20, W - 11, 34], 20, 160, fill=C("f4f4f4"))                    # dealer arc
    big = im.resize((W * S, H * S), Image.NEAREST)
    bd = ImageDraw.Draw(big)
    t = lines[0]
    f = font(13)
    w = bd.textlength(t, font=f)
    bd.text(((W * S - w) / 2, 128), t, font=f, fill=C("f6f6f6"))
    t2 = lines[1]
    w2 = bd.textlength(t2, font=font(10))
    bd.text(((W * S - w2) / 2, 146), t2, font=font(10), fill=C("eeeeee"))
    # bone emblem, center
    bx, by = W * S // 2, 100
    bd.rectangle([bx - 26, by - 4, bx + 26, by + 4], fill=C("e8e8e8"))
    for ex in (-26, 26):
        for ey in (-6, 6):
            bd.ellipse([bx + ex - 7, by + ey - 7, bx + ex + 7, by + ey + 7], fill=C("e8e8e8"))
    big.save(OUT / out)

# ---------------------------------------------------------------- seated busts (32x40 native, x4)
MGR = {   # id: (body, head, eyes, accent, initials)
    "broth": ("c8743a", "e6d6b0", "1a0f2e", "fff2c0", "SG"),
    "xylo": ("5a2a8a", "b8f0c8", "ff1f4b", "ffd800", "TL"),
    "crusher": ("e0a020", "c8a080", "1a0f2e", "3a3458", "HH"),
    "dogpark": ("2e5aa0", "c89060", "1a0f2e", "ff8fa0", "CPA"),
    "foundry": ("8a4a22", "e8dcc0", "ff6a00", "ffb000", "FM"),
    "carwash": ("1fb0d0", "d8c8e0", "1a0f2e", "ffffff", "BM"),
    "merch": ("ff3d8b", "e0e8ff", "00e5ff", "fff27a", "IW"),
    "refinery": ("e6ecf4", "a8e0a0", "1a0f2e", "43c6b8", "DP"),
    "bank": ("2e3450", "d8d0c0", "1a0f2e", "c8a040", "TA"),
    "reactor": ("3a8a3a", "b0ff6a", "ff1f4b", "fff27a", "CG"),
}

def bust(body, head, eyes, accent, initials, dealer=False):
    W, H = 32, 40
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    out = C("1a0f2e")
    # shoulders / torso
    d.polygon([(4, 39), (6, 24), (26, 24), (28, 39)], fill=out)
    d.polygon([(5, 39), (7, 25), (25, 25), (27, 39)], fill=C(body))
    if dealer:   # white shirt, black vest, red bow tie, arm garters
        d.polygon([(12, 25), (20, 25), (18, 39), (14, 39)], fill=C("f6f2ea"))
        d.rectangle([13, 25, 18, 27], fill=C("d81e3c")); d.point([(15, 26), (16, 26)], fill=C("8a0a2a"))
        d.rectangle([5, 31, 8, 32], fill=C("d81e3c")); d.rectangle([23, 31, 26, 32], fill=C("d81e3c"))
    else:
        d.rectangle([13, 25, 18, 39], fill=C(accent))
    # neck + head
    d.rectangle([13, 20, 18, 25], fill=out); d.rectangle([14, 20, 17, 25], fill=C(head))
    d.ellipse([7, 3, 24, 22], fill=out); d.ellipse([8, 4, 23, 21], fill=C(head))
    if dealer:   # purple bob hair, green dealer visor, orange stitched smile
        d.chord([7, 2, 24, 18], 180, 360, fill=C("7b3aa0"))
        d.rectangle([7, 8, 9, 17], fill=C("7b3aa0")); d.rectangle([22, 8, 24, 17], fill=C("7b3aa0"))
        d.polygon([(6, 9), (25, 9), (28, 12), (3, 12)], fill=C("1fd760")); d.line([(4, 12), (27, 12)], fill=C("0a8a5a"))
        d.rectangle([11, 14, 13, 16], fill=C("ff6a00")); d.rectangle([18, 14, 20, 16], fill=C("ff6a00"))
        d.line([(12, 19), (19, 19)], fill=C("ff6a00"))
        for x in (13, 15, 17):
            d.point((x, 18), fill=C("ff6a00")); d.point((x, 20), fill=C("ff6a00"))
    else:
        d.rectangle([11, 11, 13, 13], fill=C(eyes)); d.rectangle([18, 11, 20, 13], fill=C(eyes))
        d.line([(13, 17), (18, 17)], fill=out)
    big = im.resize((W * 4, H * 4), Image.NEAREST)
    if not dealer:
        bd = ImageDraw.Draw(big)
        f = font(15 if len(initials) < 3 else 12)
        w = bd.textlength(initials, font=f)
        bd.text((64 - w / 2, 120), initials, font=f, fill=C("1a0f2e"))
    return big

OUT.mkdir(parents=True, exist_ok=True)
(OUT / "chars").mkdir(exist_ok=True)
felt()
felt(("TEXAS HOLD'EM", "FIXED LIMIT · 2 / 4"), "felt_holdem.png")
for k, v in MGR.items():
    bust(*v).save(OUT / "chars" / f"{k}.png")
bust("1a1a24", "9a8aa8", "ff6a00", "ffffff", "", dealer=True).save(OUT / "chars" / "cadavire_dealer.png")
print("ok")
