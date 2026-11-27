# Sprite redraw kit (slice 16l, 2026-11-26)

T: "Make a master sheet of sprites for me to redraw from front, I will provide vector illustrations but I still want you to adjust and put it in the game with pixel stacking and pixel art".

## What T gets
- `tools/redraw/master_sprite_sheet.png`: every sprite in the game, by where it shows up.
  - **14 pixel stacks** (dogfight: jet_player, jet_fighter, jet_crimson, jet_ghost, kamikaze, ship, gunship, palm, spire, volcano, asteroid, hoop; card room: card_table, chair). TOP / SIDE / FRONT / BACK, in-game pixel size per view, slice count, role, notes. FRONT is "★ start here". (`hoop` is no longer used in play since the 16o ring courses.)
  - **16 flat sprites**: Cadavire dealer + 10 manager table portraits (128 x 160), 2 felts (256 x 208, greyscale: the game tints them), 3 explosion sheets (8 frames of 48 px).
  - **Drawn by code** (no file yet): Play icons, the 52 cards, Cadavire's portrait slot, koi/clouds/HUD, ring courses.
- `tools/redraw/templates/<name>.svg` (30 files): Illustrator / Figma templates. Layers: `REFERENCE` (current art, 45%), `GUIDES`, `LABELS`, `BACKGROUND`, `YOUR_ART` (draw here). 8 x 8 units = 1 game pixel. Do not resize the artboard.
- `tools/redraw/REDRAW_GUIDE.md`, `tools/redraw/manifest.json`.

## Why 4 views and not only the front
The carver cuts the 3D shape from the TOP + SIDE + FRONT outlines (a visual hull), and takes colors from each view. FRONT first, then TOP and SIDE with matching outlines. BACK is optional: an empty BACK uses the FRONT mirrored.

## Import pipeline (Claude's side)
`python3 tools/import_vector.py <name> <file.svg>`:
1. Drops helper layers by id prefix (Illustrator suffixes like `REFERENCE_1_` are fine).
2. Renders the art area with `rsvg-convert` at 8x.
3. Pixelates: each 8 x 8 block → one pixel if ≥ 50% covered, colored with the block's most common color (5-bit buckets merge anti-aliasing).
4. Stacks: writes `tools/art_src/<name>_views.png` and carves only that asset (`ONLY=<name> bash tools/carve_all.sh`, then `fix_magenta.py`). Flats: overwrites the game PNG.
5. Backups: `tools/redraw/backup/` (git-ignored).
6. Then by hand: palette, outlines, readability at in-game size, a turntable check (`tools/art_src/checks/<name>_check.png`) and an in-game screenshot.

Regenerate the sheet + templates after any art change: `python3 tools/make_master_sheet.py`.
Needs: `rsvg-convert` (librsvg2-bin), Python Pillow.

## Verified
- Round trip: current art → import → carve gives a **100% identical** stack for jet_player and gunship, and an identical flat for broth.
- A rough vector jet imports to crisp pixel views; empty BACK filled from mirrored FRONT. Trap shown: a FRONT fin that the SIDE outline does not have gets cut away.

## Risks (hostile audit)
1. **Scale shock.** Most dogfight sprites are 25-40 px wide in game. Design for the silhouette and 3-5 flat colors; small details 2+ game pixels (16+ units).
2. **Outline agreement.** Mismatched views carve away parts.
3. **Gunship geometry is code-bound** (rotor hubs, cannon muzzle in `df_game.gd`).
4. **Illustrator export settings** can flatten layers / rename ids. Hide or delete REFERENCE before export.
5. **Felts are greyscale on purpose.**
