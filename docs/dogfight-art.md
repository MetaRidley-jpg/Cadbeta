# Dogfight art direction + beach set v2 (slices 16f, 16g, 2026-11-26)

## T's direction
- 16f: "30% more zoomed in on average in replays and make beach assets look more in line with this", with two reference shots of a tropical cove (`tools/art_src/refs/beach_ref_cove.jpg`, `beach_ref_shore.webp`):
  - clear shallow water, white sand under it, bright emerald → turquoise, light caustics on the bottom, dark reef patches;
  - a white sand beach;
  - tall dark stone stacks covered in moss, bulging moss tiers, moss curtains hanging down;
  - slender palms with long curved trunks leaning out over the water;
  - deep blue sky with white clouds.
- 16g: "also how does the water appear in other weather make sure it's not jarring".

## What changed
### Water + ground (`scripts/dogfight/df_super.gdshader`)
- **Depth field:** `DfWorld.build` writes sea depth near islands into the map's B channel (0 = open sea, 1..255 = shore..deep), from the island height field that draws the coast (`depth = (0.4 - hval) / 4`).
- **Shallows, shore → deep (posterized, dithered edges):** `SH_0` white-sand aqua (0.62, 0.97, 0.86) → `SH_1` bright emerald → `SH_2` emerald → `SH_3` teal → the preset's sea blue.
- **Caustics:** a moving net of light on the bottom from two warped sine fields, quantized to 2 m cells, strongest at the shore, gone by 60% depth.
- **Reef patches:** dark green-teal blobs in the mid shallows (depth 0.12-0.55).
- The open-sea swell lines fade out in the shallows. Shore foam laps in and out.
- **Land:** white sand (0.97, 0.95, 0.87), wet sand (0.84, 0.83, 0.75), jungle greens (0.30/0.70/0.27, 0.16/0.52/0.21, 0.09/0.36/0.17), mossy dark rock (0.29, 0.36, 0.30).

### Weather light (16g)
- **Problem:** the beach colors are daylight constants, so in storm, eruption, impact and night the white sand, emerald shallows and green stacks glowed against a dark sea.
- **Fix:** each weather preset has an `ambient` color, blended between weathers like every other preset color (12 s smoothstep since 16m):

| Weather | ambient |
|---|---|
| morning | 1.00, 1.00, 1.00 |
| rain | 0.74, 0.80, 0.88 |
| storm | 0.50, 0.56, 0.68 |
| eruption | 0.72, 0.50, 0.46 (warm) |
| impact | 0.90, 0.66, 0.66 (warm) |
| night | 0.42, 0.50, 0.80 (moonlit blue) |

  - Land, sand and rock × ambient (lava and the crater glow ignore it).
  - Shallows: `mix(this weather's sea, emerald × ambient, 0.3 + 0.7 × day²)`.
  - Caustics × day². Foam dims toward the weather's sea-light color.
  - Sea stacks, palms and the volcano take ambient as their sprite color. Jets, ships, rings and lights do not (readability).

### Sea stacks (`spire`)
- Voxel model in `tools/make_placeholder_views.py` `spire()`: 30 × 30 × 50. Dark stone column, a wide mossy foot; three offset moss tiers; 22 moss curtains per tier; a mossy crown.
- Palette: stone 75846f / 4f5c50 / 323b34, moss a6ea78 / 5cbc4c / 33893a / 1f5827.
- Placement (`DfWorld.build`): interior stacks 55-110 m tall; sea stacks (~one per 55 m of island radius) in the shallows at 0.95-1.16 of the island radius. Real obstacles. Ring courses clear them (`docs/rings-and-cyan-laser.md`).

### Palms (`palm`)
- Voxel model `palm()`: 31 × 31 × 40. A 2 × 2 ringed trunk curving 11 px out to +x, a crown knot, 3 coconuts, 9 drooping fronds with leaflets. 16 headings, ~22 m tall.
- Half the palms sit on the beach ring; each leans OUT toward the sea (±0.5 rad).

### Rings (16o)
- Ring courses use a thin ring model drawn in code (`df_render._ring_model`: radius 14 px, ~1.4 px band, hot yellow top / orange bottom, 4 white studs), baked at 2 m/px, drawn x1.5. The old `hoop` stack art is no longer used by the game (kept for tools).

### Pipeline
- `project_views(name, vox, W, L, H)`: any voxel dict → the 4 sheet views the carver needs.
- **Magenta leaks:** the carver fills hidden voxels with the sheet's magenta and shades it darker (e.g. 197, 2, 197). `tools/fix_magenta.py` replaces them with the nearest real neighbor color (it fixed palm 88, spire 364, gunship 80, volcano 12). It runs at the end of `tools/carve_all.sh`. `ONLY=<name> bash tools/carve_all.sh` carves one asset.
- Vector redraw import: `docs/sprite-redraw.md`.

## Demo / media
- `--dfwave=N --dfgod --dfdemo=beach`: a slow, low pass (60 m up, 70 m/s) along the main island's shore; no enemies, the wave does not clear. N = 1-6 reviews each weather (demos keep the fixed weather order).
- `tools/demos/beach_flyover.gif`, `video_beach_flyover.mp4`.

## Hostile audit
1. The references are high-res 3D; ours is a 1/3-res Mode-7 floor + sprite stacks. Palette, layering and composition match; texture detail cannot.
2. Close up, the stacks read as green blocks. More dark stone between the moss tiers would be closer to the references.
3. Caustics are subtle at combat altitude (best below ~80 m).
4. The sky is unchanged: three flat bands, vs the references' deep mottled blue.
5. Ambient is per weather, not per light source: lightning and lava do not light the beach locally.
