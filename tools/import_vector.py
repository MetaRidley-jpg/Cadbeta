#!/usr/bin/env python3
"""Import T's vector redraw into the game as pixel art (+ a pixel stack).

Usage (from the project folder):
  python3 tools/import_vector.py jet_player ~/Downloads/jet_player.svg
  python3 tools/import_vector.py broth broth.svg            # flat sprite (table character)
  python3 tools/import_vector.py jet_player art.svg --no-carve   # only write the view sheet

Steps:
 1. Drop the template's helper layers (REFERENCE, GUIDES, LABELS, BACKGROUND; Illustrator
    may suffix the ids, e.g. REFERENCE_1_, so ids are matched by prefix).
 2. Render the art area (the template artboard minus the label band) at 8x with rsvg-convert.
 3. Pixelate: every 8 x 8 block becomes one game pixel. Opaque if >= 50% covered; color =
    the most common color in the block (5-bit buckets merge anti-aliasing), so edges stay
    crisp and only T's own colors are used.
 4. Stacks: a 4-view sheet (magenta background, 8x) -> tools/art_src/<name>_views.png, then
    tools/carve_all.sh for that one asset. An empty BACK view is filled with the FRONT
    mirrored. Flats: written over the game PNG.
 The replaced file is copied to tools/redraw/backup/ first.
After the automatic pass Claude cleans up by hand (palette, outlines, readability).
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SCALE = 8
HELPER = re.compile(r"^(reference|guides|labels|background)", re.I)
MAGENTA = np.array([255, 0, 255, 255], dtype=np.uint8)


def strip_helpers(svg_text: str) -> ET.ElementTree:
    ET.register_namespace("", "http://www.w3.org/2000/svg")
    ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")
    root = ET.fromstring(svg_text)

    def walk(node):
        for child in list(node):
            cid = child.get("id", "") or child.get("{http://www.inkscape.org/namespaces/inkscape}label", "")
            if HELPER.match(cid):
                node.remove(child)
            else:
                walk(child)
    walk(root)
    return root


def render(root, w: int, h: int, tmp: Path) -> np.ndarray:
    """Render the art area (0,0)-(w,h) in template units at 1 unit = 1 px."""
    root.set("viewBox", f"0 0 {w} {h}")
    root.set("width", str(w))
    root.set("height", str(h))
    svg = tmp.with_suffix(".svg")
    svg.write_bytes(ET.tostring(root))
    png = tmp.with_suffix(".png")
    subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), "-b", "rgba(0,0,0,0)", "-o", str(png), str(svg)], check=True)
    return np.array(Image.open(png).convert("RGBA"))


def pixelate(big: np.ndarray) -> np.ndarray:
    """8 x 8 blocks -> one pixel each (coverage >= 50%, dominant color)."""
    H, W = big.shape[0] // SCALE, big.shape[1] // SCALE
    out = np.zeros((H, W, 4), dtype=np.uint8)
    for y in range(H):
        for x in range(W):
            blk = big[y * SCALE:(y + 1) * SCALE, x * SCALE:(x + 1) * SCALE].reshape(-1, 4)
            opaque = blk[blk[:, 3] >= 128]
            if len(opaque) < SCALE * SCALE // 2:
                continue
            keys = (opaque[:, 0] >> 3).astype(np.int32) << 10 | (opaque[:, 1] >> 3).astype(np.int32) << 5 | (opaque[:, 2] >> 3).astype(np.int32)
            vals, counts = np.unique(keys, return_counts=True)
            k = vals[np.argmax(counts)]
            pick = opaque[keys == k][:, :3].mean(axis=0)
            out[y, x, :3] = pick.astype(np.uint8)
            out[y, x, 3] = 255
    return out


def backup(path: Path) -> None:
    if path.exists():
        bdir = ROOT / "tools" / "redraw" / "backup"
        bdir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, bdir / f"{path.stem}_{time.strftime('%Y%m%d_%H%M%S')}{path.suffix}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("svg", type=Path)
    ap.add_argument("--no-carve", action="store_true")
    a = ap.parse_args()
    manifest = json.loads((ROOT / "tools" / "redraw" / "manifest.json").read_text())
    tmp = Path("/tmp") / f"cadavire_import_{a.name}"
    root = strip_helpers(a.svg.read_text())
    if a.name in manifest["stacks"]:
        info = manifest["stacks"][a.name]
        W, H = info["sheet_size"]
        art = pixelate(render(root, W, H, tmp))
        boxes = info["boxes_sheet"]
        # empty BACK -> mirrored FRONT
        fx0, fy0, fx1, fy1 = [v // SCALE for v in boxes[2]]
        bx0, by0, bx1, by1 = [v // SCALE for v in boxes[3]]
        back = art[by0:by1, bx0:bx1]
        if (back[..., 3] > 0).mean() < 0.02:
            front = art[fy0:fy1, fx0:fx1][:, ::-1]
            hh, ww = min(front.shape[0], by1 - by0), min(front.shape[1], bx1 - bx0)
            art[by0:by0 + hh, bx0:bx0 + ww] = front[:hh, :ww]
            print("BACK view was empty: used the FRONT, mirrored")
        for i, nm in enumerate(["TOP", "SIDE", "FRONT", "BACK"]):
            x0, y0, x1, y1 = [v // SCALE for v in boxes[i]]
            cov = (art[y0:y1, x0:x1, 3] > 0).mean()
            print(f"{nm:5s} {x1 - x0}x{y1 - y0} px, {cov * 100:.0f}% filled" + ("   <-- EMPTY?" if cov < 0.02 else ""))
        sheet = np.where(art[..., 3:4] > 0, art, MAGENTA)
        big = Image.fromarray(sheet.astype(np.uint8)).resize((W, H), Image.NEAREST)
        dst = ROOT / "tools" / "art_src" / f"{a.name}_views.png"
        backup(dst)
        backup(ROOT / "art" / "stacks" / f"{a.name}.png")
        big.save(dst)
        print(f"wrote {dst.relative_to(ROOT)}")
        if not a.no_carve:
            env = dict(os.environ, ONLY=a.name)
            subprocess.run(["bash", "tools/carve_all.sh"], cwd=ROOT, env=env, check=True)
            print(f"carved art/stacks/{a.name}.png  (check: tools/art_src/checks/{a.name}_check.png)")
    elif a.name in manifest["flats"]:
        info = manifest["flats"][a.name]
        w, h = info["size"]
        art = pixelate(render(root, w * SCALE, h * SCALE, tmp))
        dst = ROOT / info["path"]
        backup(dst)
        Image.fromarray(art).save(dst)
        print(f"wrote {info['path']} ({w}x{h})")
    else:
        print(f"unknown asset '{a.name}'. Known: {', '.join(list(manifest['stacks']) + list(manifest['flats']))}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
