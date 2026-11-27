#!/usr/bin/env bash
# Carve every 4-view sheet in tools/art_src/ into a slice strip in art/stacks/.
# Uses the vendored sprite-stacking slicer (MIT, Daniel White): tools/sprite_stacking/.
# Usage (from the project folder):  bash tools/carve_all.sh   (ONLY=<name> carves one asset)
# Needs: python3 with Pillow + numpy  (pip install pillow numpy)
set -euo pipefail
cd "$(dirname "$0")/.."
SLICER=tools/sprite_stacking/views_to_slices.py
mkdir -p art/stacks tools/art_src/checks

carve () {   # name  extra-flags...
  local name=$1; shift
  if [ -n "${ONLY:-}" ] && [ "$ONLY" != "$name" ]; then return 0; fi   # ONLY=jet_player: one asset
  local src=tools/art_src/${name}_views.png
  # slice count = SIDE view native height (sheets are drawn at 8x, no view outlines)
  local slices
  slices=$(python3 - "$src" <<'PY'
import sys
from PIL import Image
import numpy as np
im = np.array(Image.open(sys.argv[1]).convert("RGB")).astype(int)
mask = (np.abs(im - np.array([255, 0, 255])).max(axis=2) > 28)
cols = np.where(mask.any(axis=0))[0]
# split into the 4 views by column gaps, take the 2nd (SIDE)
groups, start, prev = [], cols[0], cols[0]
for c in cols[1:]:
    if c - prev > 8:
        groups.append((start, prev)); start = c
    prev = c
groups.append((start, prev))
x0, x1 = groups[1]
rows = np.where(mask[:, x0:x1 + 1].any(axis=1))[0]
print(int(round((rows[-1] - rows[0] + 1) / 8)))
PY
)
  python3 "$SLICER" "$src" "art/stacks/${name}.png" --slices "$slices" --order reading \
    --top-nose down --side-nose left --colours 32 --shade 0.18 --dark-thresh 0 \
    --preview "tools/art_src/checks/${name}_check.png" "$@"
  echo "{\"slices\": $slices}" > "art/stacks/${name}.json"
  echo "carved $name: $slices slices"
}

carve jet_player
carve jet_fighter
carve jet_crimson
carve jet_ghost
carve kamikaze
carve ship
carve gunship
carve palm
carve spire          # beach v2: irregular mossy stack (no --round)
carve volcano --round
carve hoop
carve asteroid --round
carve card_table
carve chair
python3 tools/fix_magenta.py palm spire gunship volcano   # carving leaks magenta into hidden voxels
