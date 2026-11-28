# T's katana blade -> pixel art (slice 16w prep). Usage: python3 -I tools/blade/make_blade.py art/ref/t_pilot_katana_bar.jpg art/blade/blade.png
# Edges fitted from T's drawing; colours sampled from his painting (lavender -> teal / green, purple-grey under);
# hilt hand-placed; the collar is T's HEX PANEL (art/ref/t_hex_panel.jpg).
import sys
import colorsys
import numpy as np
from PIL import Image
src = Image.open(sys.argv[1]).convert('RGB').crop((370, 65, 1095, 145)).convert('RGB')
S = 4
W, H = src.width // S, src.height // S
small = np.asarray(src.resize((W, H), Image.BOX)).astype(float) / 255
def colored(c):
    h, s, v = colorsys.rgb_to_hsv(*c)
    return s > 0.07 or v < 0.86
G0 = int(330 / 2 / S) + 1                 # blade starts after the guard
xs, tops, bots = [], [], []
for x in range(G0 + 1, W):
    rows = [y for y in range(H) if colored(small[y, x])]
    if len(rows) >= 2 and rows[-1] - rows[0] >= 2:
        xs.append(x); tops.append(rows[0]); bots.append(rows[-1])
xs = np.array(xs); tip = xs.max()
ft = np.polyfit(xs, tops, 1); fb = np.polyfit(xs, bots, 3)
P = {"core": (255,255,255), "inner": (226,255,244), "mint": (150,236,196), "cyan": (104,206,214),
     "green": (124,200,106), "purple": (168,140,222), "haze": (110,88,180), "ink": (24,18,30),
     "red": (205,48,44), "red_d": (140,28,32), "grey": (206,206,210), "grey_d": (156,156,166),
     "steel": (150,184,206), "steel_d": (98,124,146), "orange": (230,146,58), "orange_d": (168,96,36)}
PAD = 3
out = Image.new('RGBA', (W + 2, H + PAD * 2), (0, 0, 0, 0))
px = out.load()
def put(x, y, k): 
    if 0 <= x < out.width and 0 <= y < out.height: px[x, y] = P[k] + (255,)
# blade from the fitted curves, in T's sampled pastels, stepped along the length (hard steps)
LAV = (186,175,215); LAV_D = (176,162,220)
TEAL = [(186,175,215), (178,196,214), (169,205,201)]          # back edge: lavender -> teal
TEAL_IN = [(214,208,232), (206,222,224), (196,224,220)]
GRN = [(186,175,215), (176,204,168), (151,203,131)]           # cutting edge: lavender -> green
GRN_IN = [(214,208,232), (214,230,206), (206,232,196)]
UNDER = [(185,182,203), (180,177,184)]                        # purple-grey under the edge
CORE = (238,244,240)
def putc(x, y, c):
    if 0 <= x < out.width and 0 <= y < out.height: px[x, y] = c + (255,)
for x in range(G0, tip + 1):
    t = int(round(np.polyval(ft, x))) + PAD
    b = int(round(np.polyval(fb, x))) + PAD
    u = (x - G0) / max(1, tip - G0)
    if u > 0.86:
        k = (u - 0.86) / 0.14
        b = int(round(b - (b - t) * k))
    if b < t: b = t
    st = 0 if u < 0.12 else (1 if u < 0.3 else 2)              # 3 hard colour steps
    for y in range(t, b + 1):
        dt, db = y - t, b - y
        if b - t <= 1: c = GRN[st]
        elif dt == 0: c = TEAL[st]
        elif db == 0: c = GRN[st]
        elif dt == 1: c = TEAL_IN[st]
        elif db == 1: c = GRN_IN[st]
        else: c = CORE
        putc(x, y, c)
    putc(x, b + 1, UNDER[0] if st < 2 else LAV_D)
    if x % 2 == 0: putc(x, b + 2, UNDER[1])
    if st == 0 and x % 2 == 1: putc(x, t - 1, LAV)              # lavender wash round the base
# hilt, hand placed from T's drawing (pommel cap, wrapped grip, blue collar, orange guard)
yt = int(round(np.polyval(ft, G0))) + PAD; yb = int(round(np.polyval(fb, G0))) + PAD
cy = (yt + yb) // 2 - 1                   # the grip rises a little toward the pommel (T's angle)
def rect(x0, y0, x1, y1, k):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1): put(x, y, k)
gx1 = G0 - 1
rect(gx1 - 3, cy - 5, gx1, cy + 5, "ink"); rect(gx1 - 2, cy - 4, gx1, cy + 4, "orange"); rect(gx1 - 2, cy + 2, gx1, cy + 4, "orange_d")   # guard
# collar = T's HEX PANEL (art/ref/t_hex_panel.jpg): grey frame, light-blue plate, 2 squares
# on the left, a ring of hexes round a centre capsule with a dot
P["plate"] = (143,180,200); P["frame"] = (93,106,114)
cx0, cx1 = gx1 - 13, gx1 - 4
rect(cx0 - 1, cy - 5, cx1 + 1, cy + 5, "ink"); rect(cx0, cy - 4, cx1, cy + 4, "frame"); rect(cx0 + 1, cy - 3, cx1 - 1, cy + 3, "plate")
for sy in (cy - 2, cy + 1):                                   # the 2 squares (hollow 2x2 reads as a dot)
    rect(cx0 + 1, sy, cx0 + 2, sy + 1, "frame")
rect(cx0 + 3, cy - 3, cx0 + 3, cy + 3, "frame")               # the divider line
for hx, hy in [(5, -2), (7, -2), (4, 0), (8, 0), (5, 2), (7, 2)]:   # 6 hexes round the capsule
    put(cx0 + hx, cy + hy, "frame")
rect(cx0 + 6, cy - 1, cx0 + 6, cy + 1, "frame"); put(cx0 + 6, cy, "plate")  # capsule with its dot
gx1 = cx0 - 1                                                 # the grip ends at the collar
for x in range(6, gx1 + 1):               # grip: thick, black-outlined, slopes up 3 px toward the pommel
    s2 = int(round((gx1 - x) * 3 / (gx1 - 6)))
    put(x, cy - 4 - s2, "ink"); put(x, cy + 4 - s2, "ink")
    for y in range(cy - 3 - s2, cy + 4 - s2): put(x, y, "grey" if y < cy + 1 - s2 else "grey_d")
for y in range(cy - 9, cy + 2):           # pommel cap (red, chunky)
    for x in range(0, 7): put(x, y, "ink")
for y in range(cy - 8, cy + 1):
    for x in range(1, 7): put(x, y, "red" if y < cy - 3 else "red_d")
out.save(sys.argv[2]); print(out.size, G0, tip)
