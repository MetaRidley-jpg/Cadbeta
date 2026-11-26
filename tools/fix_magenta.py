"""Carved stacks can leak the sheet's magenta background into hidden interior voxels.
Replace every magenta-ish pixel in a strip with the nearest opaque non-magenta neighbour
in the same slice (or a dark fallback). Usage: python3 tools/fix_magenta.py palm spire"""
import sys
from PIL import Image

def is_mag(p):
    # pure magenta, or magenta the carver shaded darker (e.g. 197, 2, 197)
    return p[3] > 0 and p[0] > 120 and p[2] > 120 and p[1] < 70 and abs(p[0] - p[2]) < 40

for name in sys.argv[1:]:
    path = "art/stacks/%s.png" % name
    im = Image.open(path).convert("RGBA")
    px = im.load()
    w, h = im.size
    n = 0
    for _ in range(4):                       # a few passes fill clusters from their edges
        fixes = []
        for y in range(h):
            for x in range(w):
                if not is_mag(px[x, y]):
                    continue
                best = None
                for r in (1, 2, 3):
                    for dx, dy in ((r, 0), (-r, 0), (0, r), (0, -r)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < w and 0 <= yy < h:
                            q = px[xx, yy]
                            if q[3] > 0 and not is_mag(q):
                                best = q
                                break
                    if best:
                        break
                fixes.append((x, y, best or (31, 88, 39, 255)))
        for x, y, c in fixes:
            px[x, y] = c
        n += len(fixes)
        if not fixes:
            break
    im.save(path)
    print("%s: fixed %d magenta px" % (name, n))
