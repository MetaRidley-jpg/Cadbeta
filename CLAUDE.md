# CLAUDE.md — Cadavire (Godot 4.7.2, PC + phone)

Read this first. Then `docs/build-log.md` (what was built, slice by slice) and `docs/todo.md` (what is next).

## Who you work with
- **T** (also TLC, Tristian). Call him T. T gives creative direction; you build. T reviews, diagnoses and tests on his iPhone. T is strong in Photoshop / Illustrator / Figma, reads some code, is weak at writing code.
- **Write in ASD-STE100 Simplified Technical English.** Short sentences, one instruction per sentence, active voice, approved words.
- **No sycophancy.** Do not validate an approach because T suggested it. Act as a hostile auditor: find the biggest mechanical flaws, say where a system breaks under real pressure, offer a contrary model when it is useful. End each slice report with a short "Risks (hostile audit)" list.
- T is a systems thinker, not a linear one: give the shape of a system and its knobs, not long step lists. He has ADHD: keep reports short, lead with the result.
- T does not want "AI slop" art or UI. Pixel art, chunky bands, no smooth generic gradients.
- Before any server / CLI work: check that a command is correct (docs, forums) before you give it. Commands are one line unless they must be split. Always say in one line what a command does.

## Project rules (from T)
1. **Things are functional and bug-tested before T sees them.** Run the test suites. Record and look at the result.
2. **Screenshots every slice.** Record frames with the movie command below and LOOK at full frames (not only contact sheets: a misread contact sheet once produced a false bug report). Send T the screenshot / GIF.
3. **DOCUMENT EVERYTHING.** Every slice: a build-log entry (`docs/build-log.md`), the feature doc in `docs/`, `docs/todo.md`, and the README slice section. Quote T's exact request at the top of each feature section.

## The game (short)
- AdCap-style idle tycoon: earn **Bones** from buildings (gag + industrial + "bone laundering" schemes). Secondary currency **Marrow** is wagered in minigames and buys **costumes** for Cadavire (stat boosts).
- **Cadavire**: the host. Flirty but never says she has a crush, complicated, excited-shy, never sad. **Fever** meter fills slowly; full = personality shift, UI change, cheaper prices. Gifts raise Fever a lot. Dialogue boxes sit in the same place on every screen.
- Minigames: Pool (PvP / PvE), Dogfight (the big one), Blackjack + Texas Hold'em (Marrow wagers, card room), Pinball (not built).
- Details: `docs/minigames.md`, `docs/managers-and-loyalty.md`, `docs/challenges.md`, `docs/holdem.md`, `docs/card-room.md`.

## Current mode (T, 2026-11-28)
- **Cadavire is disconnected** (`Game.cadavire_on = false`) and the app **boots into the dogfight** (`Game.dogfight_focus`). The text box is RADIO (`Game.radio_say`). Do not delete her code. `--tycoon` opens the old screens.

## Code map
- `scripts/game.gd` — autoload `Game`: save, economy, `is_phone()`, wagers, settings.
- `scripts/main.gd` — main UI, tabs, Play home (`_build_play`), debug command-line flags (`args.has(...)`), touch-scroll fix.
- `scripts/sfx.gd` — autoload `Sfx`. Sounds in `audio/sfx/` (from `tools/make_sfx.py`; append new sounds at the END).
- `scripts/cards/` — blackjack, hold'em, the 3D card room (`card_room_view.gd`, batched drawing).
- `scripts/dogfight/` — `df_game.gd` (rules, waves, boss, rings, cyan laser, demos), `df_plane.gd`, `df_render.gd` (software Mode-7 + sprite stacks, 1/3 res), `df_replay.gd` (KO replay + director), `df_rings.gd`, `df_weather.gd`, `df_world.gd`, `df_fx.gd`, `df_koi.gd`, `df_controls.gd`, `df_super.gdshader`, `df_prof.gd` (profiler: `--dfprof` or `?prof` on web).
- `art/baked/*` — pre-baked sprite atlases (PNG + JSON). Rebuild with `bash tools/bake_sprites.sh` after any change to `art/stacks/*` or a code sprite model. Detail: `docs/dogfight-performance.md`.
- `data/*.json` — dialogue, buildings, costumes, managers, card_table lines. `art/stacks/*` — pixel-stack sprites. `art/fx/*` — explosion sheets.
- `tools/` — art generators, carver (`carve_all.sh`, `ONLY=<name>`), vector import (`import_vector.py`), redraw kit (`tools/redraw/`), `record_demo.sh`, `setup_godot.sh`.

## Set up a new machine
`bash tools/setup_godot.sh` — installs Godot 4.7.2 + web templates + xvfb / rsvg / ffmpeg / Pillow, then imports. In a Claude Code cloud session it runs by itself (SessionStart hook in `.claude/settings.json`), without the web templates (~1 GB; only a local web export needs them). If `godot` is not found after it ran, use `~/godot/godot` or `export PATH="$HOME/.local/bin:$PATH"`.

## Tests (run before every push)
**One command: `bash tools/run_tests.sh`** — runs all 8 suites in parallel (~20 s), prints a PASS/FAIL table, exits 1 on any failure. Logs: `build/test-logs/<name>.log`. Pick suites: `bash tools/run_tests.sh rules df`. CI gate only: `CI=1 bash tools/run_tests.sh`. Timings: `SERIAL=1`. A broken suite is killed after 120 s.

Suites (name: scene, about how many checks). A pass prints `N passed, 0 failed` (ui: `ALL PASSED`).
`rules` test_runner 366 · `df` dogfight_test 273 · `touch` touch_test 25 · `ui` ui_smoke · `cards` cards_test 57 · `pool` pool_test 19 · `chal` challenges_test 116 · `holdem` holdem_test about 52-55 (random hands gate some checks, so the count moves).
- To add a suite: add one line to `SUITES` in `tools/run_tests.sh`.
- cards_test prints one harmless "Drawing is only allowed inside _draw" error: the test times `_draw_room()` directly.
- One suite by hand: `godot --headless --path . res://tests/<scene>.tscn --quit-after 30000 -- --fresh`.
- `tests/holdem_stress.tscn` is optional and slow. CI gate (`.github/workflows/web.yml`): `CI=1 bash tools/run_tests.sh` (rules + df + touch).

## Record screenshots / video
```
xvfb-run -a -s "-screen 0 1280x1400x24" godot --path . --rendering-method gl_compatibility --resolution 720x1280 --write-movie /tmp/probe/NAME/f.png --fixed-fps 30 --quit-after FRAMES -- --fresh ARGS
```
Frames come out 540x960. GIF: `bash tools/record_demo.sh NAME FRAMES ARGS` (prefix `xvfb-run -a`). A `.avi` output records sound too. Add `--phone` to get the phone layout on desktop.

Useful ARGS:
- Dogfight: `--dfyaw=DEG` (heading), `--dfat=x,y,z`. `--dogfight --dfwave=N --dfgod --dfdemo=NAME`. Demos: `kami loop roll half immelmann fog beach rings[_slalom|_corkscrew|_loop|_stairs|_figure8|_bigloop|_helix] ringsreplay[_kind] boss bossko asteroid koi volcano ko`. Also `--dfcrashat=7`, `--dfsim=3`, `--dfhold`, `--dforbit=165`. Demos keep the fixed weather order; real play rolls weather per wave.
- HUD: `--dfhurt=hp,shield` (T's bar states).
- UI: `--tab=N`, `--playopts`, `--fever`, `--marrow=N`, `--memlog` (MEM lines), `--phone`.
- Cards: `--holdem --hebuy=5 --heauto --fast`, `--cards --bjauto`.
- Full list: `grep -rhoE 'args\.has\("[a-z_]+"\)' scripts/`.

## Web build (T plays here on his iPhone)
- Push to `main` on `MetaRidley-jpg/Cadbeta` → GitHub Actions runs the gate, exports "Web", publishes to https://metaridley-jpg.github.io/Cadbeta/ (~1 min). Check with `gh run list --limit 3` / `gh run view <id> --log-failed`.
- Web uses `gl_compatibility`, threads OFF. Details: `docs/web-build.md`.

## Git
- Branch `main`. Commit with `git -c user.name="Claude" -c user.email="noreply@anthropic.com" commit`. End every commit message with the attribution lines the session gives you.
- Ignored: `build/`, `tools/demos/`, `tools/redraw/backup/`. `*.import` and `export_presets.cfg` ARE committed.

## Known traps (each one cost time before)
- **Test variable names must be unique** inside a test function (GDScript parse error kills the whole suite).
- **A new `class_name`** needs `godot --headless --path . --import` once, or other scripts cannot see it.
- **The renderer's FOV is vertical.** On a portrait phone a "78°" shot is ~60° across. Replay shots give a horizontal FOV and convert.
- **Any folder the game reads by path at runtime** (json, stacks) must be in the Web preset's include filter, or the web build cannot find it.
- **Touch:** controls inside a ScrollContainer are switched to `MOUSE_FILTER_PASS` on `node_added`. A control that needs its own drag must set its filter after `add_child`.
- **Touch tests:** event positions go through `get_viewport().get_final_transform()`.
- **CI grep:** use `"passed, 0 failed"`; `"0 failed"` matches `"10 failed"`.
- **Demos vs real play:** check `demo == ""` before random systems (weather roll), and `start_demo` resets them.
- **Stack sprites** have their origin at the bottom slice (hit centres, muzzles).
- **Stale baked sprites:** change art or a sprite model → run `bash tools/bake_sprites.sh`, or dogfight_test fails ("all sprite atlases load from fresh art/baked files"). Dev runs still work (they bake live, with a WARN).
- **Per-frame work:** never load, decode or build models in a per-frame path. Profile with `--dfprof` before you guess (the old "16 ms draw cost" was a PNG re-read, not drawing).
- **Speed scaling (`DfPlane.SPEED_K`):** scale speeds AND rates by K, and DURATIONS of motion (launch times) by 1/K, or geometry changes and flight tests fail.
- **Arena is a square** (`DfWorld.ARENA_MIN/MAX`, `clamp_inside`, `zone_of`), not the old 1150 m circle. `AREA_RADIUS` now means zone 0 only.
- **Ring courses must fit under the 300 m ceiling.** A round upright loop maxes out at ~95 m radius. New shapes: run the flyability test (all `DfRings.KINDS`); curves tighter than ~110 m radius crash the pilot.
- **Draw call count:** the card room crashed iPhone Safari at ~14k draw calls; batch with `RenderingServer.canvas_item_add_triangle_array`.

## Open work (see docs/todo.md)
- T phone-tests rings / cyan laser / course gap (slice 16p).
- Dogfight frame cost: fixed in slice 16r (sprites() cache + baked atlases). T phone-tests with `?prof`. Koi draw is the top cost now.
- 4x world: `docs/world-4x.md` (16u highways next).
- Enemy AI depth, dogfight-only rewards, more Cadavire in the dogfight, Pinball.
