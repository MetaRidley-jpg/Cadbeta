# Redraw guide (T → game)

1. Open `master_sprite_sheet.png`, pick a sprite.
2. Open `templates/<name>.svg` in Illustrator or Figma. Layers:
   - `REFERENCE`: the current placeholder art (45% opacity). Draw over it or ignore it.
   - `GUIDES`: one dashed box per view (FRONT is yellow, marked START HERE). Stay inside the boxes.
   - `LABELS`, `BACKGROUND`: info only.
   - `YOUR_ART`: draw here.
3. Do not move or resize the artboard. 8 x 8 units = 1 pixel in the game, so details smaller
   than 8 units disappear. Think in silhouettes and flat color blocks.
4. Stacked 3D objects: draw TOP (seen from above, nose DOWN), SIDE (nose LEFT), FRONT, and BACK.
   The 3D shape is cut from the TOP + SIDE + FRONT outlines, so the outlines must agree
   (the wing span in TOP = the width in FRONT; the length in TOP = the length in SIDE).
   BACK is optional: an empty BACK uses the FRONT, mirrored.
5. Export as SVG (Illustrator: File → Export → Export As → SVG; keep "Layer names" as object IDs).
   Hidden or deleted helper layers are fine. Send the SVG.
6. Claude runs `python3 tools/import_vector.py <name> <file.svg>`: each 8x8 block becomes one pixel
   (the block's most common color, so edges stay crisp), then the stack is carved and checked,
   then cleaned up by hand (palette, outlines, readability at in-game size), then tested in game.
   The replaced files are backed up in `tools/redraw/backup/`.

Regenerate the sheet and templates after art changes: `python3 tools/make_master_sheet.py`.
