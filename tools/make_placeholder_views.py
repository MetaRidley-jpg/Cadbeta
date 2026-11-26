#!/usr/bin/env python3
"""Placeholder 4-view pixel-art sheets for the dogfight sprite stacks.

Row order: TOP (front pointing DOWN), SIDE (front pointing LEFT), FRONT, BACK.
Same scale in all four views, 3-tone hue-shifted shading, upscaled 8x on flat
MAGENTA with wide gaps (flat background; white erased the bone highlights). NO outline on the
views: the slicer would fold each 1px outline into thin parts (a 1px wing became
3 slices thick). The game outlines the finished stack once.

T: replace any of these sheets with your own art (same layout) and run
tools/carve_all.sh. Sheets live in tools/art_src/<name>_views.png.
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = (26, 15, 46, 255)          # outline: dark plum, luminance < 70 so the slicer strips it
SRC = Path(__file__).resolve().parent / "art_src"


def C(hexs):
    hexs = hexs.lstrip("#")
    return (int(hexs[0:2], 16), int(hexs[2:4], 16), int(hexs[4:6], 16), 255)


# 3-tone hue-shifted ramps: (highlight warm, mid saturated, shadow cool)
BONE = (C("fff6e4"), C("f0d6b0"), C("a88aa0"))
ORANGE = (C("ffb35c"), C("ff6a00"), C("b8302a"))
CYAN = (C("c8ffff"), C("00e5ff"), C("0a78b8"))
PURP = (C("e0b0ff"), C("a050f0"), C("5a2a8a"))
METAL = (C("8a8aa8"), C("5a5878"), C("3a3458"))
FIRE = (C("fff27a"), C("ffb000"), C("ff3c00"))
BLUE = (C("8fdcff"), C("00a6fb"), C("1d4fa0"))
RED = (C("ff8fa0"), C("ff1f4b"), C("8a0a3a"))
DARK = (C("56607a"), C("2e3450"), C("1e2440"))
GREY = (C("e6ecf4"), C("a8b2c4"), C("5e6884"))
LEAF = (C("9dff6a"), C("1fd760"), C("0a8a5a"))
TRUNK = (C("e0a060"), C("b8682a"), C("6e3a3a"))
ROCK = (C("e4dcf0"), C("b0a6cc"), C("6e6490"))
GRASS = (C("b6ff6a"), C("2edf71"), C("12905a"))
VOLC = (C("9a6aa0"), C("5c3a63"), C("2e1e40"))
LAVA = (C("fff27a"), C("ff7a00"), C("d02000"))
# T's jet (tools/art_src/tlc_jet_concept.png)
WHITE = (C("ffffff"), C("e8eef6"), C("b4bccc"))
VISOR = (C("ff8aa6"), C("ff1f5a"), C("b0103c"))    # visor crimsons (hue ~345): the game shimmers these (DfSprites.VISOR_*)
HELM = (C("e8eef6"), C("a8b2c4"), C("6e7890"))     # grey helmet shell
TRED = (C("ff6a6a"), C("ee2222"), C("a01010"))
TYEL = (C("fff27a"), C("ffd800"), C("c09000"))
CANOPY = (C("babee6"), C("5c64b4"), C("3c4080"))   # violet-navy glass: NOT a visor blue, so it does not scroll
WOOD = (C("d08a4a"), C("8a4a22"), C("4e2412"))     # card table rim / chair
FELTKEY = (C("4fbf7a"), C("2f8f55"), C("1f6a3c"))  # felt top: covered in game by art/table/felt.png
BRASS = (C("ffe08a"), C("d8a640"), C("8a6420"))


class V:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.im.putpixel((int(x), int(y)), c)

    def rect(self, x0, y0, x1, y1, c):
        self.d.rectangle([x0, y0, x1, y1], fill=c)

    def poly(self, pts, c):
        self.d.polygon(pts, fill=c)

    def ellipse(self, x0, y0, x1, y1, c):
        self.d.ellipse([x0, y0, x1, y1], fill=c)

    def vshade(self, ramp, y_hi, y_lo):
        """Re-tone existing pixels by row: top rows highlight, bottom rows shadow."""
        for y in range(self.h):
            for x in range(self.w):
                p = self.im.getpixel((x, y))
                if p[3] == 0:
                    continue
                for k, base in enumerate(ramp):
                    if p == ramp[1]:
                        self.im.putpixel((x, y), ramp[0] if y <= y_hi else (ramp[2] if y >= y_lo else ramp[1]))
                        break

    def outlined(self):
        out = Image.new("RGBA", (self.w + 2, self.h + 2), (0, 0, 0, 0))
        out.paste(self.im, (1, 1))
        a = out.split()[3].load()
        px = out.load()
        for y in range(self.h + 2):
            for x in range(self.w + 2):
                if a[x, y] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w + 2 and 0 <= ny < self.h + 2 and a[nx, ny] > 0:
                            px[x, y] = OUT
                            break
        return out


def sheet(name, views, scale=8, gap=48):
    # No outline on the views: thin parts (wings, fins) must stay 1 slice thick.
    # The game draws ONE outline around the finished stack instead.
    ims = [v.im for v in views]
    W = sum(i.width * scale for i in ims) + gap * (len(ims) + 1)
    H = max(i.height for i in ims) * scale + gap * 2
    s = Image.new("RGBA", (W, H), (255, 0, 255, 255))   # magenta: no art color is near it
    x = gap
    for i in ims:
        big = i.resize((i.width * scale, i.height * scale), Image.NEAREST)
        s.paste(big, (x, (H - big.height) // 2), big)   # CENTERED: the slicer sorts views into rows by their middle, so all middles must match
        x += big.width + gap
    SRC.mkdir(exist_ok=True)
    s.save(SRC / f"{name}_views.png")
    return ims[1].height   # SIDE native height incl. outline = slice count


# ---------------------------------------------------------------- card table
def card_table(name="card_table"):
    """Blackjack table for the card room, seen from the player's seat.
    Rounded tabletop (wood rim, felt inside), one pedestal, round foot.
    The felt pixels sit on the top slice; the game draws art/table/felt.png over
    them (FELT_INSET px in from the edge, see blackjack_page.gd), so the felt is a
    flat texture you can replace."""
    W, L, H = 74, 62, 10
    top, side, front, back = V(W, L), V(L, H), V(W, H), V(W, H)
    top.ellipse(0, 0, 25, 25, WOOD[1]); top.ellipse(W - 26, 0, W - 1, 25, WOOD[1])
    top.ellipse(0, L - 26, 25, L - 1, WOOD[1]); top.ellipse(W - 26, L - 26, W - 1, L - 1, WOOD[1])
    top.rect(12, 0, W - 13, L - 1, WOOD[1]); top.rect(0, 12, W - 1, L - 13, WOOD[1])
    top.ellipse(5, 5, 27, 27, FELTKEY[1]); top.ellipse(W - 28, 5, W - 6, 27, FELTKEY[1])
    top.ellipse(5, L - 28, 27, L - 6, FELTKEY[1]); top.ellipse(W - 28, L - 28, W - 6, L - 6, FELTKEY[1])
    top.rect(16, 5, W - 17, L - 6, FELTKEY[1]); top.rect(5, 16, W - 6, L - 17, FELTKEY[1])
    for x in range(14, W - 14, 6):                                  # brass studs on the rim
        top.px(x, 2, BRASS[1]); top.px(x, L - 3, BRASS[1])
    for v, n in ((side, L), (front, W), (back, W)):
        v.rect(0, 0, n - 1, 2, WOOD[1]); v.rect(0, 0, n - 1, 0, WOOD[0]); v.rect(0, 2, n - 1, 2, WOOD[2])
        c = n // 2
        v.rect(c - 4, 3, c + 3, 8, WOOD[2])                         # pedestal
        v.rect(c - 2, 3, c + 1, 8, WOOD[1])
        v.rect(c - 12, 9, c + 11, 9, WOOD[2])                       # foot
    return sheet(name, [top, side, front, back])

def chair(name="chair"):
    """Card-room chair: round-cornered seat, tall back (at the BACK edge), 4 legs.
    Front = the side that faces the table."""
    W, L, H = 16, 16, 18
    top, side, front, back = V(W, L), V(L, H), V(W, H), V(W, H)
    # TOP, nose UP (front at y = 0), then turned for the sheet
    top.rect(1, 1, W - 2, L - 2, RED[2]); top.rect(2, 2, W - 3, L - 5, RED[1])   # cushion
    top.rect(0, L - 3, W - 1, L - 1, WOOD[1])                                     # backrest (back edge)
    top.im = top.im.rotate(180); top.d = ImageDraw.Draw(top.im)
    # SIDE, front LEFT
    side.rect(L - 3, 0, L - 1, 11, WOOD[1]); side.rect(L - 3, 0, L - 1, 0, WOOD[0])
    side.rect(0, 10, L - 1, 11, RED[1]); side.rect(0, 10, L - 1, 10, RED[0])
    side.rect(1, 12, 2, H - 1, WOOD[2]); side.rect(L - 3, 12, L - 2, H - 1, WOOD[2])
    # FRONT
    front.rect(0, 0, W - 1, 9, WOOD[1]); front.rect(2, 2, W - 3, 8, RED[2])     # backrest seen over the seat
    front.rect(0, 10, W - 1, 11, RED[1])
    front.rect(1, 12, 2, H - 1, WOOD[2]); front.rect(W - 3, 12, W - 2, H - 1, WOOD[2])
    # BACK
    back.rect(0, 0, W - 1, 11, WOOD[1]); back.rect(0, 0, W - 1, 0, WOOD[0])
    back.rect(1, 12, 2, H - 1, WOOD[2]); back.rect(W - 3, 12, W - 2, H - 1, WOOD[2])
    return sheet(name, [top, side, front, back])


# ---------------------------------------------------------------- T's jet
def tlc_jet(name="jet_player"):
    """T's design (concept sheet: tools/art_src/tlc_jet_concept.png).
    Helmet nose with a CYCLOPS visor (one RED shimmering band across the front,
    yellow hinges at its ends, grey helmet shell), white delta, big canopy with a light stripe, 4-square emblem on the right wing,
    swept tail fin with a red tip, metal nozzle. Drawn nose-UP, then turned for the sheet."""
    L, W, H = 34, 31, 12
    top, side, front, back = V(W, L), V(L, H), V(W, H), V(W, H)
    # TOP, nose UP (y = 0 is the nose)
    top.poly([(10, 11), (0, 26), (0, 27), (10, 27)], WHITE[1])          # left wing
    top.poly([(20, 11), (30, 26), (30, 27), (20, 27)], WHITE[1])        # right wing
    for x in (0, 1, 29, 30):
        top.rect(x, 26, x, 27, WHITE[2])                                # wingtip shade
    top.rect(10, 9, 20, 27, WHITE[0])                                   # body
    top.ellipse(9, -1, 21, 10, VISOR[1])                                # cyclops band (front arc)
    top.ellipse(10, 2, 20, 11, HELM[1])                                 # grey helmet shell behind it
    top.rect(13, 4, 14, 5, HELM[0])                                     # shell highlight
    top.px(11, 1, VISOR[0])                                             # visor glint
    top.rect(8, 4, 9, 6, TYEL[1]); top.rect(21, 4, 22, 6, TYEL[1])      # yellow visor hinges
    top.rect(11, 10, 19, 11, WHITE[1])                                  # neck
    top.ellipse(11, 12, 19, 25, CANOPY[1])                              # canopy
    top.ellipse(13, 13, 16, 23, CANOPY[0])                              # canopy light stripe
    top.px(12, 20, CANOPY[2]); top.px(18, 15, CANOPY[2])                # canopy scratches
    top.px(23, 18, C("1e90ff")); top.px(25, 18, TRED[1])                # emblem (right wing)
    top.px(23, 20, C("22c050")); top.px(25, 20, TYEL[1])
    top.rect(15, 25, 16, 30, WHITE[1])                                  # fin root
    top.poly([(12, 27), (19, 27), (18, 31), (13, 31)], METAL[1])        # nozzle
    top.rect(14, 29, 17, 31, METAL[2])
    top.im = top.im.rotate(180)                                         # sheet wants nose DOWN
    top.d = ImageDraw.Draw(top.im)
    # SIDE, nose LEFT
    side.rect(4, 7, 30, 10, WHITE[1]); side.rect(4, 7, 30, 7, WHITE[0]); side.rect(4, 10, 30, 10, WHITE[2])
    side.rect(10, 9, 27, 9, WHITE[2])                                   # wing edge
    side.poly([(22, 7), (28, 0), (32, 0), (31, 7)], WHITE[1])          # swept fin
    side.rect(28, 0, 32, 1, TRED[1])                                    # red fin tip
    side.ellipse(-1, 4, 10, 11, HELM[1])                                # grey helmet nose
    side.rect(3, 5, 5, 5, HELM[0])
    side.rect(-1, 6, 5, 8, VISOR[1]); side.px(0, 6, VISOR[0])           # cyclops band, front
    side.rect(6, 6, 7, 8, TYEL[1])                                      # yellow hinge
    side.rect(9, 7, 10, 10, WHITE[1])
    side.ellipse(11, 3, 24, 11, CANOPY[1]); side.rect(13, 3, 21, 3, CANOPY[0])  # canopy hump
    side.rect(10, 7, 25, 10, WHITE[1]); side.rect(10, 7, 25, 7, WHITE[0])        # fuselage stays white under it
    side.rect(10, 10, 25, 10, WHITE[2]); side.rect(10, 9, 25, 9, WHITE[2])
    side.rect(30, 7, 33, 10, METAL[1]); side.rect(33, 8, 33, 9, METAL[2])        # nozzle
    # FRONT
    front.rect(0, 9, 30, 10, WHITE[1]); front.rect(0, 10, 30, 10, WHITE[2])
    front.rect(10, 6, 20, 11, WHITE[1])
    front.rect(15, 0, 16, 6, WHITE[1]); front.rect(15, 0, 16, 1, TRED[1])
    front.ellipse(11, 3, 19, 8, CANOPY[1])                              # canopy behind
    front.rect(10, 7, 20, 11, WHITE[1])
    front.ellipse(10, 4, 20, 11, HELM[1])                               # grey helmet
    front.rect(10, 6, 20, 8, VISOR[1]); front.rect(12, 6, 13, 6, VISOR[0])   # the cyclops bar
    front.rect(8, 6, 9, 8, TYEL[1]); front.rect(21, 6, 22, 8, TYEL[1])  # hinges
    # BACK
    back.rect(0, 9, 30, 10, WHITE[1]); back.rect(0, 10, 30, 10, WHITE[2])
    back.rect(10, 6, 20, 11, WHITE[1])
    back.rect(15, 0, 16, 6, WHITE[1]); back.rect(15, 0, 16, 1, TRED[1])
    back.ellipse(11, 3, 19, 8, CANOPY[1])
    back.rect(10, 7, 20, 11, WHITE[1])
    back.rect(8, 6, 9, 8, TYEL[1]); back.rect(21, 6, 22, 8, TYEL[1])
    back.ellipse(12, 6, 18, 11, METAL[1]); back.ellipse(14, 7, 16, 10, FIRE[1])
    return sheet(name, [top, side, front, back])


# ---------------------------------------------------------------- jets
def jet(name, body, trim, glass, pilot, wing="delta", tails=2, L=30, W=27, H=11):
    hw = W // 2
    top, side, front, back = V(W, L), V(L, H), V(W, H), V(W, H)

    def fus_half(z):            # z: 0 = tail, L-1 = nose
        if z >= L - 4: return 0
        if z >= L - 8: return 1
        if z < 3: return 2
        return 2

    def fus_top(z):
        if z >= L - 4: return 4
        if L - 13 <= z <= L - 7: return 7      # canopy bubble
        return 5

    # TOP (front = nose pointing DOWN: row = z)
    for z in range(L):
        h = fus_half(z)
        for x in range(-h, h + 1):
            c = body[0] if x == 0 else body[1]
            if z >= L - 3: c = trim[1]
            top.px(hw + x, z, c)
    if wing == "delta":
        for z in range(5, L - 11):
            span = hw if z < 8 else max(3, hw - (z - 8))
            for x in range(3, span + 1):
                c = trim[1] if x >= span - 1 or z == L - 12 - (x - 3) else (body[0] if z < 8 else body[1])
                top.px(hw + x, z, c); top.px(hw - x, z, c)
    else:   # swept
        for z in range(4, L - 12):
            span = min(hw, 3 + (z - 4))
            for x in range(3, span + 1):
                c = trim[1] if x >= span - 1 else body[1]
                top.px(hw + x, z, c); top.px(hw - x, z, c)
    for x in range(3, 6):                                  # canards / tailplane
        top.px(hw + x, L - 7, trim[1]); top.px(hw - x, L - 7, trim[1])
    fin_x = [4, 5] if tails == 2 else [0, 1]
    for z in range(1, 9):
        for fx in fin_x:
            for sgn in ((1, -1) if tails == 2 else (1,)):
                top.px(hw + sgn * fx - (1 if tails == 1 else 0), z, trim[2] if z < 3 else trim[1])
    for z in range(L - 13, L - 6):                          # canopy glass
        for x in (-1, 0, 1):
            top.px(hw + x, z, glass[0] if x == -1 else glass[1])
    top.px(hw, L - 11, pilot[1]); top.px(hw, L - 12, pilot[2])
    for x in (-2, -1, 1, 2):                                 # nozzles at the tail
        top.px(hw + x, 0, METAL[2])

    # SIDE (nose LEFT: col = L-1-z, row = H-1-y)
    def sp(z, y, c): side.px(L - 1 - z, H - 1 - y, c)
    for z in range(L):
        t = fus_top(z) if z < L - 13 or z > L - 7 else 5
        for y in range(2, t + 1):
            c = body[0] if y == t else (body[2] if y == 2 else body[1])
            if z >= L - 3: c = trim[1] if y > 2 else trim[2]
            sp(z, y, c)
    for z in range(L - 13, L - 6):                           # canopy
        for y in range(6, 8):
            sp(z, y, glass[0] if y == 7 else glass[1])
    sp(L - 11, 6, pilot[1]); sp(L - 11, 7, pilot[0]); sp(L - 10, 7, pilot[2])
    for z in range(5, L - 11):                               # wing edge seen from the side
        sp(z, 3, body[2])
    for z in range(1, 9):                                    # fins, raked
        for y in range(5, 11):
            if z <= 8 - (y - 5) // 2 + 0 and z >= 1 + (y - 5) // 2:
                sp(z, y, trim[0] if y == 10 else (trim[1] if y >= 9 else body[1]))
    for y in range(2, 5):                                    # exhaust
        sp(0, y, FIRE[1] if y == 3 else METAL[2])

    # FRONT (looking at the nose)
    for y in range(2, 6):
        for x in range(-2, 3):
            c = body[0] if y == 5 else (body[2] if y == 2 else body[1])
            front.px(hw + x, H - 1 - y, c)
    for x in range(-1, 2):
        front.px(hw + x, H - 1 - 6, glass[0]); front.px(hw + x, H - 1 - 7, glass[1])
    front.px(hw, H - 1 - 6, pilot[1])
    for x in range(3, hw + 1):
        c = trim[1] if x >= hw - 1 else body[1]
        front.px(hw + x, H - 1 - 3, c); front.px(hw - x, H - 1 - 3, c)
    for fx in fin_x:
        for sgn in ((1, -1) if tails == 2 else (1,)):
            for y in range(5, 11):
                front.px(hw + sgn * fx - (1 if tails == 1 else 0), H - 1 - y, trim[1] if y >= 9 else body[1])
    front.px(hw - 1, H - 1 - 2, METAL[2]); front.px(hw + 1, H - 1 - 2, METAL[2])   # intakes

    # BACK (exhaust glow)
    back.im = front.im.copy(); back.d = ImageDraw.Draw(back.im)
    for x in (-1, 0, 1):
        back.px(hw + x, H - 1 - 3, FIRE[0] if x == 0 else FIRE[1])
        back.px(hw + x, H - 1 - 2, FIRE[2])
    for x in range(-1, 2):
        back.px(hw + x, H - 1 - 6, body[1]); back.px(hw + x, H - 1 - 7, body[0])
    return sheet(name, [top, side, front, back])


def kamikaze():
    L, W, H = 26, 13, 9
    hw = W // 2
    top, side, front, back = V(W, L), V(L, H), V(W, H), V(W, H)
    for z in range(L):
        h = 2 if z < L - 3 else 1
        for x in range(-h, h + 1):
            c = BONE[1] if z >= L - 6 else (RED[0] if x == 0 else RED[1])
            top.px(hw + x, z, c)
    for z in range(0, 6):                    # rear cross fins
        for x in range(3, hw + 1 if z < 4 else 4):
            top.px(hw + x, z, DARK[1]); top.px(hw - x, z, DARK[1])
    for z in range(L):
        for y in range(2, 7):
            if z >= L - 3 and (y < 3 or y > 5): continue
            c = BONE[0] if (z >= L - 6 and y >= 5) else (BONE[1] if z >= L - 6 else (RED[0] if y == 6 else (RED[2] if y == 2 else RED[1])))
            side.px(L - 1 - z, H - 1 - y, c)
    side.px(L - 4, H - 1 - 5, DARK[2]); side.px(L - 5, H - 1 - 5, DARK[2])   # eye socket
    for z in range(0, 6):
        for y in (0, 1, 7, 8):
            side.px(L - 1 - z, H - 1 - y, DARK[1])
    for y in range(2, 7):
        for x in range(-2, 3):
            front.px(hw + x, H - 1 - y, BONE[0] if y >= 5 else BONE[1])
    for x in (-1, 1):
        front.px(hw + x, H - 1 - 5, DARK[2])                                # skull eyes
    front.px(hw, H - 1 - 3, DARK[2])
    for x in range(3, hw + 1):
        front.px(hw + x, H - 1 - 4, DARK[1]); front.px(hw - x, H - 1 - 4, DARK[1])
    for y in (0, 1, 7, 8):
        front.px(hw, H - 1 - y, DARK[1])
    back.im = front.im.copy(); back.d = ImageDraw.Draw(back.im)
    for y in range(2, 7):
        for x in range(-2, 3):
            back.px(hw + x, H - 1 - y, RED[1])
    back.px(hw, H - 1 - 4, FIRE[0]); back.px(hw - 1, H - 1 - 4, FIRE[1]); back.px(hw + 1, H - 1 - 4, FIRE[1])
    return sheet("kamikaze", [top, side, front, back])


def ship():
    L, W, H = 44, 14, 13
    hw = W // 2
    top, side, front, back = V(W, L), V(L, H), V(W, H), V(W, H)

    def half(z):  # z: 0 stern, L-1 bow
        if z > L - 6: return max(1, hw - 2 - (z - (L - 6)))
        if z < 3: return hw - 2
        return hw - 1
    for z in range(L):
        h = half(z)
        for x in range(-h, h + 1):
            c = GREY[2] if abs(x) == h else GREY[0] if abs(x) < 2 else GREY[1]
            top.px(hw + x, z, c)
    for z in range(16, 26):                       # superstructure
        for x in range(-3, 4):
            top.px(hw + x, z, DARK[0] if z > 22 else DARK[1])
    for z in range(26, 36):                       # flak barrel pointing forward
        top.px(hw, z, DARK[2]); top.px(hw - 1, z, DARK[1])
    for z in range(8, 12):
        for x in range(-1, 1):
            top.px(hw + x, z, C("ff1f4b"))        # deck marking
    for z in range(L):
        for y in range(0, 4):
            c = GREY[2] if y == 0 else (GREY[1] if y < 3 else GREY[0])
            if y == 1: c = C("ff1f4b")            # red waterline stripe
            side.px(L - 1 - z, H - 1 - y, c)
    for z in range(16, 26):
        for y in range(4, 8):
            side.px(L - 1 - z, H - 1 - y, DARK[0] if y == 7 else DARK[1])
    for z in range(26, 36):
        side.px(L - 1 - z, H - 1 - 6, DARK[2])
    for y in range(8, 13):
        side.px(L - 1 - 20, H - 1 - y, GREY[1])  # mast
    side.px(L - 1 - 19, H - 1 - 12, C("ff1f4b")); side.px(L - 1 - 18, H - 1 - 12, C("ff1f4b"))
    for y in range(0, 4):
        for x in range(-(hw - 1), hw):
            front.px(hw + x, H - 1 - y, GREY[0] if y == 3 else (C("ff1f4b") if y == 1 else GREY[1]))
    for y in range(4, 8):
        for x in range(-3, 4):
            front.px(hw + x, H - 1 - y, DARK[0] if y == 7 else DARK[1])
    front.px(hw, H - 1 - 6, DARK[2]); front.px(hw - 1, H - 1 - 6, DARK[2])
    for y in range(8, 13):
        front.px(hw, H - 1 - y, GREY[1])
    back.im = front.im.copy(); back.d = ImageDraw.Draw(back.im)
    return sheet("ship", [top, side, front, back])


def project_views(name, vox, W, L, H):
    """Voxel dict {(x, y, z): color} -> the 4 sheet views (TOP nose down, SIDE nose left,
    FRONT, BACK), outermost voxel wins. y = up, high z = front."""
    top, side, front, back = V(W, L), V(L, H), V(W, H), V(W, H)
    cols = {}
    for (x, y, z) in vox:
        if (x, z) not in cols or y > cols[(x, z)]:
            cols[(x, z)] = y
    for (x, z), y in cols.items():
        top.px(x, z, vox[(x, y, z)])
    sx = {}
    for (x, y, z) in vox:
        if (z, y) not in sx or x < sx[(z, y)]:
            sx[(z, y)] = x
    for (z, y), x in sx.items():
        side.px(L - 1 - z, H - 1 - y, vox[(x, y, z)])
    zf, zb = {}, {}
    for (x, y, z) in vox:
        if (x, y) not in zf or z > zf[(x, y)]:
            zf[(x, y)] = z
        if (x, y) not in zb or z < zb[(x, y)]:
            zb[(x, y)] = z
    for (x, y), z in zf.items():
        front.px(x, H - 1 - y, vox[(x, y, z)])
    for (x, y), z in zb.items():
        back.px(W - 1 - x, H - 1 - y, vox[(x, y, z)])
    return sheet(name, [top, side, front, back])


# Beach set v2 (T 2026-11-26, two reference shots of a tropical cove: emerald shallows,
# white sand, tall mossy stone stacks with hanging moss, slender curved leaning palms).
PALM_TRUNK = (C("cdb08a"), C("9e7d5a"), C("6d553d"))
PALM_LEAF = (C("b4f27a"), C("6cc94f"), C("3f9a3a"), C("26652c"))
STONE = (C("75846f"), C("4f5c50"), C("323b34"))
MOSS = (C("a6ea78"), C("5cbc4c"), C("33893a"), C("1f5827"))


def palm():
    """A tall slender palm whose trunk curves out to +x (the game turns +x toward the sea)."""
    import math, random
    rnd = random.Random(5)
    W = L = 31
    H = 40
    cx = 8
    cz = L // 2
    vox = {}
    def put(x, y, z, c):
        if 0 <= x < W and 0 <= y < H and 0 <= z < L:
            vox[(x, y, z)] = c
    top_y = 31
    lean = 11.0
    tx = ty = 0
    for y in range(0, top_y + 1):
        u = y / top_y
        ox = cx + lean * (u ** 1.7)
        ring = (y % 3 == 0)
        for dx in (0, 1):
            for dz in (0, 1):
                c = PALM_TRUNK[2] if ring else (PALM_TRUNK[0] if dx == 1 else PALM_TRUNK[1])
                put(int(round(ox)) + dx, y, cz + dz - 1, c)
        tx = int(round(ox))
    hx, hy, hz = tx, top_y + 1, cz - 1
    for dx in (-1, 0, 1, 2):                    # crown knot + coconuts
        for dz in (-1, 0, 1):
            put(hx + dx, hy, hz + dz, PALM_LEAF[2])
    for (dx, dz) in ((0, -1), (1, 1), (-1, 0)):
        put(hx + dx, hy - 1, hz + dz, C("5a3d22"))
    n = 9
    for f in range(n):                          # fronds: rise a little, then droop hard
        a = f * math.tau / n + rnd.uniform(-0.2, 0.2)
        ln = rnd.randint(11, 14)
        for k in range(1, ln + 1):
            u = k / ln
            r = k
            y = hy + 2.2 * math.sin(u * math.pi * 0.6) - 9.0 * (u ** 2.2)
            x = hx + math.cos(a) * r
            z = hz + math.sin(a) * r
            c = PALM_LEAF[0] if u < 0.3 else (PALM_LEAF[1] if u < 0.65 else PALM_LEAF[2])
            put(int(round(x)), int(round(y)), int(round(z)), c)
            # leaflets: one voxel each side, hanging lower toward the tip
            px, pz = -math.sin(a), math.cos(a)
            for side in (1, -1):
                put(int(round(x + px * side)), int(round(y - (1 if u > 0.4 else 0))), int(round(z + pz * side)),
                    PALM_LEAF[2] if u < 0.7 else PALM_LEAF[3])
    return project_views("palm", vox, W, L, H)


def spire():
    """Mossy sea stack: a dark stone column with bulging moss tiers and moss curtains
    hanging off each tier, a mossy crown on top and a wide rock foot."""
    import math, random
    rnd = random.Random(11)
    W = L = 30
    H = 50
    c = W // 2
    vox = {}
    def put(x, y, z, col):
        if 0 <= x < W and 0 <= y < H and 0 <= z < L:
            vox[(x, y, z)] = col
    # (centre y, radius, half height, offset x, offset z): offset bulbs = an irregular stack
    tiers = [(14, 8.6, 3.4, 1.5, -1.0), (28, 7.8, 3.2, -1.6, 1.2), (42, 7.0, 3.8, 0.8, 0.3)]
    def neck_off(y):                                                 # the stone column wanders with the bulbs
        for k in range(len(tiers) - 1):
            y0, y1 = tiers[k][0], tiers[k + 1][0]
            if y0 <= y <= y1:
                u = (y - y0) / (y1 - y0)
                return (tiers[k][3] * (1 - u) + tiers[k + 1][3] * u, tiers[k][4] * (1 - u) + tiers[k + 1][4] * u)
        return (tiers[0][3], tiers[0][4]) if y < tiers[0][0] else (tiers[-1][3], tiers[-1][4])
    for y in range(0, 46):
        r = 3.9 + 0.8 * math.sin(y * 0.41) + 0.5 * math.sin(y * 0.17 + 1.3)
        if y < 6:
            r = 7.5 - y * 0.55                                       # wide foot
        nox, noz = neck_off(y)
        for x in range(-10, 11):
            for z in range(-10, 11):
                d = math.hypot(x - nox, z - noz)
                if d <= r and d > r - 1.6:
                    lit = x + z * 0.4 > 1.5                          # light from +x
                    crack = (y * 7 + int(math.atan2(z, x) * 6)) % 11 == 0
                    col = STONE[2] if crack else (STONE[0] if lit else STONE[1])
                    if y < 3:
                        col = MOSS[3] if (x + z + y) % 3 == 0 else STONE[2]
                    put(c + x, y, c + z, col)
    for (ty, tr, th, ox, oz) in tiers:
        for y in range(int(ty - th), int(ty + th) + 1):
            for x in range(-12, 13):
                for z in range(-12, 13):
                    d = math.hypot(x - ox, z - oz) / tr + ((y - ty) / th) ** 2 * 0.9
                    if d <= 1.0 and d > 0.62:
                        hgt = (y - (ty - th)) / (2 * th)
                        col = MOSS[0] if hgt > 0.75 else (MOSS[1] if hgt > 0.4 else MOSS[2])
                        put(c + x, y, c + z, col)
        # moss curtains hanging off the tier's rim
        for k in range(22):
            a = k * math.tau / 22 + rnd.uniform(-0.08, 0.08)
            ln = rnd.randint(5, 14)
            rr = tr - 0.4
            for s in range(ln):
                y = int(ty - th) - s
                x = int(round(ox + math.cos(a) * (rr - s * 0.12)))
                z = int(round(oz + math.sin(a) * (rr - s * 0.12)))
                put(c + x, y, c + z, MOSS[2] if s < ln * 0.5 else MOSS[3])
    for x in range(-4, 5):                                           # tufts on the crown
        for z in range(-4, 5):
            if math.hypot(x, z) < 4.2 and (x * 3 + z * 5) % 4 == 0:
                put(c + x, 47, c + z, MOSS[0])
    return project_views("spire", vox, W, L, H)


def volcano():
    W = L = 64
    H = 36
    top, side, front, back = V(W, L), V(L, H), V(W, H), V(W, H)
    top.ellipse(0, 0, W - 1, L - 1, VOLC[1])
    top.ellipse(10, 10, W - 11, L - 11, VOLC[0])
    top.ellipse(20, 20, W - 21, L - 21, VOLC[2])
    top.ellipse(24, 24, W - 25, L - 25, LAVA[1])
    top.ellipse(27, 27, W - 28, L - 28, LAVA[0])
    for v in (side, front, back):
        for y in range(H):
            half = 31.5 * (1.0 - y / (H + 6))
            x0 = int(round(W / 2 - half)); x1 = int(round(W / 2 + half)) - 1
            for x in range(x0, x1 + 1):
                ledge = (y % 6) == 0
                c = VOLC[2] if (x <= x0 + 2 or ledge) else (VOLC[0] if x >= x1 - 4 else VOLC[1])
                v.px(x, H - 1 - y, c)
        for k, sx in enumerate((-9, 4, 13)):       # lava streams down the slopes
            for y in range(H - 1, H - 22 - k * 4, -1):
                x = W // 2 + sx + (H - y) // 5 * (1 if sx > 0 else -1)
                v.px(x, H - 1 - y, LAVA[1] if y % 3 else LAVA[0])
        for x in range(W // 2 - 5, W // 2 + 5):
            v.px(x, 0, LAVA[0])
    return sheet("volcano", [top, side, front, back])


def hoop():
    W, L, H = 22, 4, 22
    top, side, front, back = V(W, L), V(L, H), V(W, H), V(W, H)
    for x in range(W):
        for z in range(L):
            top.px(x, z, ORANGE[0] if z < 2 else ORANGE[1])
    for y in range(H):
        for z in range(L):
            side.px(z, y, ORANGE[0] if y < H // 2 else ORANGE[2])
    for v in (front, back):
        for y in range(H):
            for x in range(W):
                d = ((x - 10.5) ** 2 + (y - 10.5) ** 2) ** 0.5
                if y >= H - 4 and x in (10, 11):
                    continue      # 2px slit: the hole must reach the outside or it carves solid
                if 7.6 <= d <= 10.6:
                    v.px(x, y, C("ffe600") if y < 6 else (ORANGE[0] if y < 12 else ORANGE[1]))
    return sheet("hoop", [top, side, front, back])


def asteroid():
    S = 24
    views = [V(S, S) for _ in range(4)]
    import random
    rnd = random.Random(4)
    for v in views:
        v.ellipse(0, 0, S - 1, S - 1, ROCK[2])
        v.ellipse(2, 2, S - 5, S - 5, VOLC[1])
        v.ellipse(4, 3, S - 9, S - 10, VOLC[0])
        for k in range(5):
            cx, cy, r = rnd.randint(4, 18), rnd.randint(4, 18), rnd.randint(1, 3)
            v.ellipse(cx - r, cy - r, cx + r, cy + r, VOLC[2])
        for k in range(14):                               # glowing cracks
            v.px(rnd.randint(3, 20), rnd.randint(3, 20), LAVA[0] if k % 2 else LAVA[1])
    return sheet("asteroid", views)



def gunship(name="gunship"):
    """Boss: QUAD GUNSHIP (T, 2026-11-26: "Quad helicopter boss ... shoots a blue laser out of a
    bottom mounted cannon bigger than yours"). Built as voxels, then projected to the 4 views.
    In game: 70 m across (DfPlane.BOSS_SPAN; ~1.52 m per px). The spinning rotor blades are drawn live by
    DfRender (only the ducts and hubs are in the stack). Belly cannon with a cyan muzzle."""
    W, L, H = 46, 46, 26
    vox = {}
    cx, cz = W // 2, L // 2
    import math
    def put(x, y, z, c):
        if 0 <= x < W and 0 <= y < H and 0 <= z < L:
            vox[(x, y, z)] = c
    # v2 (T saw a flat sliver from the side): a deep armoured hull, 13 px tall, so it reads as
    # "a building that flies" at level flight. Bow = high z. Hazard stripe (red/dark) on the sides.
    for z in range(9, 38):
        hw = 6 if 13 <= z <= 32 else (5 if z > 32 else 4)
        top_y = 18 if z < 35 else 17
        for x in range(-hw, hw + 1):
            for y in range(6, top_y + 1):
                if abs(x) == hw and (y == 6 or y == top_y):
                    continue
                c = DARK[1]
                if y == top_y: c = DARK[0]
                if y <= 7: c = DARK[2]
                if abs(x) == hw and y == 12: c = RED[1] if (z // 2) % 2 == 0 else DARK[2]
                if abs(x) == hw and y in (14, 15) and z % 5 == 0: c = DARK[2]       # vents
                if x == 0 and y == top_y: c = RED[1]
                put(cx + x, y, z, c)
    for z in range(33, 38):                      # cockpit glass wrapping the bow
        for x in range(-4, 5):
            for y in range(12, 17):
                put(cx + x, y, z, BLUE[1] if y < 15 else BLUE[0])
    for z in range(16, 29):                      # twin engine humps on the roof
        for x in (-3, -2, 2, 3):
            for y in (19, 20):
                put(cx + x, y, z, METAL[1] if y == 19 else METAL[0])
        if z % 4 == 0:
            put(cx - 3, 21, z, GREY[1]); put(cx + 3, 21, z, GREY[1])
    for z in range(3, 10):                       # tail boom + tall red fin
        for y in (13, 14):
            put(cx, y, z, DARK[1]); put(cx - 1, y, z, DARK[1]); put(cx + 1, y, z, DARK[0])
    for z in range(3, 7):
        for y in range(14, 24):
            put(cx, y, z, RED[1] if z > 3 else RED[2])
    # 4 arms out to the rotor ducts at the corners (thick girders)
    hubs = [(-15, 9), (15, 9), (-15, 37), (15, 37)]
    for hx, hz in hubs:
        n = 18
        for k in range(n + 1):
            u = k / n
            x = round(hx * u); z = round(cz + (hz - cz) * u)
            for y in (14, 15):
                put(cx + x, y, z, METAL[1] if y == 14 else METAL[0])
        # duct ring r=7, 5 px tall, grey with a red top edge; filled rotor disc; hub cap
        for a in range(0, 360, 4):
            rx = round(hx + math.cos(math.radians(a)) * 7.0)
            rz = round(hz + math.sin(math.radians(a)) * 7.0)
            for y in range(12, 17):
                put(cx + rx, y, rz, GREY[1] if y < 16 else RED[1])
        for dx in range(-6, 7):
            for dz in range(-6, 7):
                if dx * dx + dz * dz <= 36:
                    put(cx + hx + dx, 14, hz + dz, DARK[2] if (dx * dx + dz * dz) > 9 else METAL[2])
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                put(cx + hx + dx, 15, hz + dz, METAL[0]); put(cx + hx + dx, 16, hz + dz, METAL[1])
    # belly cannon: a big pod hanging under the hull, a thick barrel to the bow, cyan muzzle
    for z in range(16, 31):
        for x in range(-4, 5):
            for y in range(1, 6):
                r = (x / 4.5) ** 2 + ((y - 3.5) / 3.0) ** 2
                if r <= 1.0:
                    put(cx + x, y, z, METAL[1] if y >= 3 else METAL[2])
    for z in range(29, 43):
        for x in (-1, 0, 1):
            for y in (2, 3, 4):
                put(cx + x, y, z, DARK[1] if y == 4 else DARK[2])
        if z % 4 == 1:
            for x in (-2, 2):
                put(cx + x, 3, z, GREY[1])
    for z in range(42, 46):
        for x in range(-2, 3):
            for y in range(1, 7):
                core = abs(x) <= 1 and 2 <= y <= 5
                put(cx + x, y, z, CYAN[1] if core else CYAN[2])
    # project: TOP (look down, nose down), SIDE (nose left), FRONT (bow), BACK (stern)
    top, side, front, back = V(W, L), V(L, H), V(W, H), V(W, H)
    for (x, z) in {(x, z) for (x, y, z) in vox}:
        y = max(yy for (xx, yy, zz) in vox if xx == x and zz == z)
        top.px(x, z, vox[(x, y, z)])
    for (z, y) in {(z, y) for (x, y, z) in vox}:
        x = min(xx for (xx, yy, zz) in vox if zz == z and yy == y)
        side.px(L - 1 - z, H - 1 - y, vox[(x, y, z)])
    for (x, y) in {(x, y) for (x, y, z) in vox}:
        zf = max(zz for (xx, yy, zz) in vox if xx == x and yy == y)
        zb = min(zz for (xx, yy, zz) in vox if xx == x and yy == y)
        front.px(x, H - 1 - y, vox[(x, y, zf)])
        back.px(W - 1 - x, H - 1 - y, vox[(x, y, zb)])
    return sheet(name, [top, side, front, back])

if __name__ == "__main__":
    counts = {
        "jet_player": tlc_jet("jet_player"),
        "jet_fighter": jet("jet_fighter", BLUE, RED, DARK, DARK, "swept", 1, L=28, W=25),
        # Alt player jets (Challenges rewards). Cosmetic only.
        "jet_crimson": jet("jet_crimson", RED, DARK, CYAN, BONE, "swept", 2),
        "jet_ghost": jet("jet_ghost", GREY, CYAN, PURP, BONE, "delta", 1),
        "kamikaze": kamikaze(),
        "ship": ship(),
        "gunship": gunship(),
        "palm": palm(),
        "spire": spire(),
        "volcano": volcano(),
        "hoop": hoop(),
        "asteroid": asteroid(),
        "card_table": card_table(),
        "chair": chair(),
    }
    for k, v in counts.items():
        print(k, v)
