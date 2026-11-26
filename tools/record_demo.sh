#!/bin/bash
# Record a dogfight GIF demo with Godot's Movie Maker (fixed 30 fps, so it is smooth on any PC).
# usage: bash tools/record_demo.sh NAME FRAMES [game args...]
# examples:
#   bash tools/record_demo.sh laser 240 --dogfight --dfsim=3 --dfgod --dfdemo=kami
#   bash tools/record_demo.sh boost 170 --dogfight --dfsim=3 --dfgod --dfhold
#   bash tools/record_demo.sh visor 75  --dogfight --dfsim=3 --dfgod --dforbit=165
# Needs: godot on PATH, python3 + Pillow. On a headless Linux box, prefix with xvfb-run -a.
set -e
name=$1; frames=$2; shift 2
cd "$(dirname "$0")/.."
out=tools/demos/frames_$name
rm -rf "$out"; mkdir -p "$out"
godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
  --write-movie "$out/f.png" --fixed-fps 30 --quit-after "$frames" -- --fresh "$@"
python3 - "$out" "tools/demos/$name.gif" <<'PY'
import sys, glob
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
frames = []
for f in sorted(glob.glob(src + "/f*.png"))[::2]:
    im = Image.open(f).convert("RGB")
    im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
    frames.append(im.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
frames[0].save(out, save_all=True, append_images=frames[1:], duration=66, loop=0, optimize=True)
print("wrote", out, len(frames), "frames")
PY
