"""Placeholder effect art for the dogfight (T redraws these; same size and frame count).
art/fx/explosion.png: 8 frames of 48x48 in one row, pixel art, hard dark outline.
Frame 0 flash -> 1-3 fireball grows -> 4-5 breaks into smoke with embers -> 6-7 smoke thins.
Run: python3 tools/make_fx_art.py"""
import math, random
from PIL import Image

S, N = 48, 8
OUT = (26, 16, 22, 255)
WHITE = (255, 250, 230, 255)
YEL = (255, 214, 64, 255)
ORA = (255, 128, 32, 255)
RED = (214, 46, 40, 255)
SMK = (74, 58, 70, 255)
SMK_L = (118, 100, 110, 255)
EMB = (255, 170, 60, 255)

def frame(i, rng, P):
    WHITE, YEL, ORA, RED, SMK, SMK_L, EMB = P
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()
    c = S / 2
    t = i / (N - 1)
    # clumps: a few overlapping blobs around the centre make a lumpy fireball
    blobs = [(0, 0, 1.0)] + [(math.cos(a) * 0.45, math.sin(a) * 0.45 - 0.1, rng.uniform(0.5, 0.95))
                             for a in [k * math.tau / 6 + rng.uniform(-0.3, 0.3) for k in range(6)]]
    grow = [0.28, 0.55, 0.78, 0.92, 1.0, 1.04, 1.06, 1.08][i]
    R = 21 * grow
    holes = i >= 5
    for y in range(S):
        for x in range(S):
            best = 9.0
            for bx, by, br in blobs:
                d = math.hypot(x + 0.5 - c - bx * R * 0.6, y + 0.5 - c - (by - t * 0.25) * R * 0.6) / (R * br * 0.62)
                best = min(best, d)
            if best > 1.0:
                continue
            # smoke breaks up late: deterministic pixel holes
            if holes:   # the smoke tears in 3x3 clumps, from the edge inward
                cell = random.Random((x // 3) * 131 + (y // 3) * 7919 + 17).random()
                if cell < (0.18 if i == 5 else (0.38 if i == 6 else 0.58)) + best * 0.25:
                    continue
            if i == 0:
                col = WHITE if best < 0.6 else YEL
            elif i <= 3:
                col = WHITE if best < 0.25 * (4 - i) / 3 else (YEL if best < 0.55 else (ORA if best < 0.8 else RED))
            elif i == 4:
                col = ORA if best < 0.3 else (RED if best < 0.55 else SMK_L if best < 0.8 else SMK)
            else:
                col = SMK_L if best < 0.45 else SMK
                if random.Random(x * 53 + y * 97 + i).random() < (0.06 if i < 7 else 0.02):
                    col = EMB
            px[x, y] = col
    # one hard outline (the game's sprites all have one)
    out = img.copy()
    op = out.load()
    for y in range(S):
        for x in range(S):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < S and 0 <= yy < S and px[xx, yy][3] > 0:
                        op[x, y] = OUT
                        break
    # flash frame: 4 short rays
    if i == 0:
        for k in range(4):
            a = k * math.tau / 4 + math.pi / 4
            for r in range(int(R) + 1, int(R) + 7):
                op[int(c + math.cos(a) * r), int(c + math.sin(a) * r)] = YEL
    return out

FIRE = (WHITE, YEL, ORA, RED, SMK, SMK_L, EMB)
# laser kill: the beam's crimsons (white-pink core, hot red, crimson, maroon smoke, red embers)
LASER = ((255, 236, 240, 255), (255, 92, 120, 255), (255, 31, 75, 255), (150, 8, 40, 255),
         (60, 18, 34, 255), (104, 40, 62, 255), (255, 60, 90, 255))
# gunship beam kill (T: "the explosion is red" -> a BLUE beam kills in blue): white-cyan core,
# cyan, electric blue, deep blue, navy smoke, steel-blue smoke, cyan embers
BEAM = ((236, 252, 255, 255), (120, 230, 255, 255), (47, 168, 255, 255), (20, 70, 200, 255),
        (18, 26, 60, 255), (44, 62, 110, 255), (130, 240, 255, 255))
for name, pal, seed in (("explosion", FIRE, 7), ("explosion_laser", LASER, 11), ("explosion_beam", BEAM, 13)):
    rng = random.Random(seed)
    sheet = Image.new("RGBA", (S * N, S), (0, 0, 0, 0))
    for i in range(N):
        sheet.paste(frame(i, rng, pal), (i * S, 0))
    sheet.save("art/fx/%s.png" % name)
    sheet.resize((S * N * 4, S * 4), Image.NEAREST).save("art/fx/%s_preview_x4.png" % name)
    print("wrote art/fx/%s.png" % name)
