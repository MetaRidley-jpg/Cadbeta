# Dogfight performance

T (2026-11-27): "Just continue, make dogfight run better as well".

## Result (slice 16r)
| What | Before | After |
|---|---|---|
| Jets + fx queue, wave 8 (desktop) | 26 ms / frame | 2 ms |
| Bake at match start (desktop) | 6.5 s (boss alone 3.2 s) | 45 ms |
| Freeze when a jet kind first shows up | 0.45-1.0 s | none (pre-loaded) |
| Script work per frame, wave 8, **web build** (Chromium) | not measured | ~6-9 ms total |

Desktop numbers: this cloud box, software GL. Phones are slower; the ratios hold.

## The two causes
1. **`DfPlane.sprites()` ran every frame for every jet.** Before its cache check, it rebuilt the jet's voxel model and re-read the PNG strip from disk (decode every pixel, build the voxel shell). 17 jets = ~25 ms per frame. This was the "16 ms fixed draw cost" in the old to-do. Draw calls were never the problem. Fix: cache by art name (`DfPlane._spr_cache`, `DfSprites._art_cache`).
2. **Sprite atlases were baked in GDScript at run time.** Fix: bake once to `art/baked/<key>.png + .json`, load those.

## Baked atlases: how it works
- `bash tools/bake_sprites.sh` writes all 13 atlases (~1.1 MB of PNG) and imports them. Run it after you change `art/stacks/*` or a code model (`_palm_model`, `DfPlane.model`, `_rock_model`, ...).
- **Exported build (web):** trusts the baked files. No hashing, no model building.
- **Dev run:** each file stores a hash of its source (strip PNG + JSON, or the code model) and the bake settings. Stale or missing = bake live as before, and print `art/baked/<key> is stale`.
- **CI** re-bakes before tests and export, so the web build is never stale, even if nobody re-baked.
- **Test** (`dogfight_test`): zero live bakes in a full run (all files fresh), and a baked file = a live bake, pixel for pixel.
- The bake is deterministic (two bakes are byte-identical).

## Profiler (knobs)
- `--dfprof` (desktop) or **`?prof` in the web address** (phone: `https://metaridley-jpg.github.io/Cadbeta/?prof`).
- HUD readout: fps, total script ms per frame, the 3 costliest stages. Console: every stage, avg/max, every 120 frames.
- Stages: `sim`, `camera+hud`, `hud draw`, `trails`, `koi move`, `koi draw`, `shadows`, `scenery`, `jets+fx`, `sort`, `draw`, `weather`, plus `n_items` (sprites queued).
- Add a stage: `var t := DfProf.t0()` ... `DfProf.add("name", t)`. Off = one bool check.

## Tried and rejected
- **Batch the koi quads into one triangle array** (the card-room cure). Desktop 3.0 → 3.6 ms, web 3.4 → 4.0 ms: worse. The koi cost is GDScript math, not engine calls. Reverted.

## What costs the most now (web, wave 8)
- `koi draw` 0.2-5 ms (peaks 13 ms when a big koi fills the screen), `sim` ~1.7 ms, `jets+fx` ~1 ms, `scenery` ~1 ms.
- Real koi fix options (need T's eye, they change the look): fewer spine segments / fin rays at mid range, or draw the koi in a shader.
