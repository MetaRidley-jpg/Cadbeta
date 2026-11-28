# Cadavire — Godot 4.7 build (slice 13: 360 dogfight flight)

## Open and run
1. Install Godot **4.7.2** (standard, not .NET).
2. Godot → Import → select `project.godot` in this folder.
3. Press F5. Window is portrait 540×960 on PC. Phone layout is 720×1280 and stretches.

## What works now
- Bones idle loop: 10 buildings (gag / industrial / laundering), tap to run, Ghoul managers, buy x1 / x10 / x100 / MAX, speed milestones (25, 50, 100, 200, 300, 400).
- **Schemes**: one-time bone laundering upgrades, each x3 income. Reset on Fold.
- **Fever**: fills slowly while you are active, drains when you idle. Buying, taste tests and gifts push it. When full: 2 min, income x2, costs −25%, whole UI switches to the Fever palette, she talks every 8–14 s with Fever lines.
- **Taste tests**: every 50–110 s she bites a random building. She eats one cycle of its bones. Better tiers give better bones → Fever + a 60 s x1.5 / x2 boost on that building, rare +1 Marrow.
- **Costumes** (Marrow, permanent): 8 outfits incl. **Cave-Gal Pelt** (Fever fills 1.6x faster, eats ANY bone with max joy, 3x bites, "BONEZ" lines).
- **Stash**: buy items with Bones. EQUIP one (hidden boost, never shown on her skin) or GIFT it (used up, big Fever, item-specific line).
- **Fold** (prestige reset, code name `rebury`): the business folds, bones → Marrow (sqrt curve). **Prestige rank** box near the money: own 10/50/75/100 of EVERY building, first time only, never lost, color escalates.
- **Managers are characters.** Hiring one slides in a 2nd, smaller dialogue box under the stage. A short 3-way scene plays: the manager (small box), Cadavire (main box), and YOU (your line is the reply button). SKIP is always there. Taste tests and chatter pause during a scene.
- **Ghoul loyalty (permanent, 5 tiers)**: x1 → x1 → x1.75 → x3 → x5 → x7.5 on that building. First hire = tier 1. Each Fold moves every manager you had hired up 1 tier. The bonus works at once, even before you rehire. Rehire to see the next scene: "the business fell apart, but bones aren't money". At tier 5 each manager is fully in on it, for their own reason (crush, money, takeover, or unknown). 50 scenes + 10 rehire lines in `data/manager_scenes.json`.
- **Level meter** (thin bar under the bones): fed only by bones earned, 3 levels per x10 bones, so it moves very slowly. Never lost on Fold. Only `Game.endgame_reset_level()` clears it — no endgame event calls it yet. Display only, no bonus yet.
- Marrow is separate from managers: Folding gives Marrow, Marrow buys costumes and is wagered in minigames.
- **Marrow rules:** skill games (pool, dogfight) are FREE and pay bones + Fever, never Marrow. Marrow bets live ONLY at the card table (blackjack / hold'em, not built yet). Max bet by prestige rank: 5 / 10 / 25 / 50 / 100 (`Game.MAX_BET_BY_RANK`), never above your Marrow.
- **Play tab → POOL** (8-ball vs Cadavire, friendly). You: solids, you break. Win = ~1 min of income in bones. Touch table = aim, `<` `>` fine aim, pull the strip LEFT and release. Her skill = her outfit (Lab Coat precise, Cave-Gal SMASH, Fever sloppy).
- **Play tab → DOGFIGHT** (survive the waves). Drawn as TIGHT SPRITE STACKS (pixel stacking): every object is a pile of flat 2D slices, one per pixel of height, each drawn 1 px higher, all turned by the same angle, squashed to 0.75, one bold outline per stack, flat saturated colors. Rendered at 1/3 resolution with nearest filtering (1 art pixel = 3 screen pixels).
  - Camera: top-down; the map turns so your nose points up and you see ahead (Burnout-style chase). It lags in drifts so you see the slide, speed lines on boost, slow-motion takedowns, and it spins around your wreck when you crash. Altitude = lift + ground shadow + ALT bar on the left.
  - Controls: left side = floating stick (drag up = climb). Hold BOOST, hold DRIFT (sharp sliding turn), tap BOMB. Guns fire on their own at anything inside the aim cone. PC: WASD / arrows, Shift boost, Space drift, B bomb.
  - BOOST fills by flying dangerously: low flying (< 14 m), drifting, speed hoops, kills. Boost = more speed + wider FOV.
  - Takedowns: kills trigger a short slow-motion + "TAKEDOWN!". Enemies that crash into terrain while chasing you = TERRAIN TAKEDOWN. You crash = WRECKED crash cam.
  - Enemies: fighters (shoot), kamikaze (ram you), flak ships on the ocean (bomb them).
  - Weather = time passing: W1 morning, W2 rain, W3 fog + thunder, W4 volcano erupts (lava rain + smog), W5 asteroid (10 s warning, hits the main island, carves a crater, kills everything near it), W6+ night storms with more enemies.
  - Islands: sand, grass, palm trees. No houses.
  - Pays bones for every wave survived (x(0.5 + 0.5 × waves) of the 1-minute win) + Fever. Best score and wave are saved.
  - Cadavire is the pilot: portrait uses `art/cadavire/pilot/` during the dogfight.

## Where to change things
| What | File |
|---|---|
| All numbers (costs, timers, Fever, costumes, items, schemes) | `scripts/balance.gd` |
| Her lines (89 lines, 41 categories) | `data/dialogue.json` |
| Manager scenes (10 managers × 5 tiers + rehire lines, motives) | `data/manager_scenes.json` |
| Pool physics + rules | `scripts/pool/pool_sim.gd` (constants at the top) |
| Her pool skill per outfit | `scripts/pool/pool_ai.gd` → `profile()` |
| Minigame payouts, card-table bet limits | `scripts/game.gd` → `end_minigame()`, `MAX_BET_BY_RANK` |
| Dogfight tuning (weapons, boost, waves) | `scripts/dogfight/df_game.gd` (constants at the top, `wave_def()`) |
| Plane handling | `scripts/dogfight/df_plane.gd` → `KINDS`, drift constants |
| Weather looks | `scripts/dogfight/df_weather.gd` → `PRESETS` |
| Island layout / terraces / palms | `scripts/dogfight/df_world.gd`, `df_island.gd` |
| Island colors | `scripts/dogfight/df_island.gdshader` (consts at the top) |
| All other dogfight colors | `scripts/dogfight/df_pal.gd` |
| Plane / ship / hoop pixel models | `df_plane.gd → model()`, `df_render.gd → _ship_model()`, `df_world.gd → _make_hoop_stack()` |
| Stack look (squash, scale, camera anchor) | `scripts/dogfight/df_render.gd` constants |
| Colors (normal + Fever palettes) | `scripts/ui_theme.gd` (top of file) |
| Layout | `scenes/main.tscn`, `scenes/building_row.tscn`, `scenes/dialogue_box.tscn` — edit in the Godot editor |

### Dialogue rules
- `e` = expression: neutral, shy, smug, excited, flustered, hungry, disgusted, feral.
- Key prefix `fever.` = used during Fever. `caveman.` = used in Cave-Gal Pelt. Missing keys fall back (`caveman.x` → `fever.x` → `x` → part before the dot).
- **Dialogue slot rule**: Slot 1 = Cadavire, top-right of the stage, every screen (`scenes/dialogue_box.tscn`). Slot 2 = the other character (manager now, opponents later), full width directly under the stage (`scenes/manager_box.tscn`). Never add a third box.
- Scene beats: `["m", text]` manager, `["c", text, expression]` Cadavire, `["p", text]` you.

## Art slots (drop PNGs, no code change)
- Portrait: `art/cadavire/<costume_id>/<expression>.png` and `<expression>_fever.png`.
  Fallback: same costume `neutral` → `grave_casual` → drawn placeholder. Slot is ~250×330 (scales, keeps aspect).
  Costume ids: grave_casual, hard_hat, clown, pinstripe, lab_coat, caveman, warzone, regal_decay.
- Building icons: `art/buildings/<building_id>.png` (square, shows on the tap button).
- Manager portraits: `art/managers/<building_id>.png` (square, 112×112 slot). Placeholder = initials.
- Dogfight pilot portrait: `art/cadavire/pilot/<expression>.png` (same rules as costumes).
  Ids: broth, xylo, crusher, dogpark, foundry, carwash, merch, refinery, bank, reactor.

## Tests (run from this folder)
All suites at once (parallel, ~20 s, PASS/FAIL table): `bash tools/run_tests.sh`. One by one:
```
godot --headless --path . res://tests/test_runner.tscn -- --fresh   # 366 rule tests + pacing bot + 5-run Fold bot
godot --headless --path . res://tests/ui_smoke.tscn -- --fresh      # presses every button, plays full pool matches
godot --headless --path . res://tests/pool_test.tscn -- --fresh --matches=10   # pool physics, rules, AI vs AI
godot --headless --path . --quit-after 400000 res://tests/dogfight_test.tscn -- --fresh   # flight, weapons, crater, autopilot matches
godot --headless --path . --quit-after 60000 res://tests/challenges_test.tscn -- --fresh  # challenge wall
godot --headless --path . --quit-after 20000 res://tests/cards_test.tscn -- --fresh       # blackjack + split + camera
godot --headless --path . --quit-after 20000 res://tests/holdem_test.tscn -- --fresh      # Hold'em, house cut, bankrolls
```
Always pass `--quit-after N` and `-- --fresh`.
Debug launch flags (after `--`): `--fresh --state=rich|late --fever --caveman --taste --offline --tab=0..4 --say=<key> --hire=<0-9> --beats=<n> --loyalty=<0-5> --rebury --pool=<wager> --scatter --aim=x,y --pull=0..1 --herturn --poolend=win|lose --dogfight --autopilot --dfwave=N --dfsim=SECONDS --dfgod --dfface=volcano|main --dfboost`.
Fold page has WIPE SAVE (two taps) for testing.

## Not in this slice
Pinball, sound, blackjack insurance, ball-in-hand, ads / IAP, real art, export presets.
For a phone export: Project → Export → add iOS/Android preset. `data/dialogue.json` loads as a JSON resource, so it exports by default.

## Dogfight art pipeline (sprite stacking, danielwh2/sprite-stacking)
Every dogfight object is drawn as a four-view sheet, carved into slices, then baked in game.
1. Draw `tools/art_src/<name>_views.png`: one row, MAGENTA (#ff00ff) background, wide gaps,
   in this order: TOP (nose DOWN), SIDE (nose LEFT), FRONT, BACK. No outlines. Thin parts 2 px or more.
   Names: jet_player, jet_fighter, kamikaze, ship, palm, spire, volcano, hoop, asteroid.
   (`tools/make_placeholder_views.py` writes Claude's placeholders. Do not run it after you redraw: it overwrites.)
2. Run `bash tools/carve_all.sh`. It writes `art/stacks/<name>.png` + `.json` and a turntable check
   `tools/art_src/checks/<name>_check.png`. Look at the check before you use the art.
3. Open the project once (or `godot --headless --path . --import`). The game bakes the strips at load
   (`DfSprites.bake_art`). World size stays the same as before, so collisions do not change.
If a strip is missing, the game falls back to the old code model.
In dev builds the game reads the raw PNG, so a fresh carve shows up without a re-import.
Visor: on `jet_player`, pixels in the visor crimsons (hue 335-354 deg, saturation 0.45 or more, e.g. ff1f5a) get the red shimmer.
T's concept sheet: `tools/art_src/tlc_jet_concept.png`.

## Challenges wall
Achievements in the style of the Brawl Challenges screen: 4 x 32 windows, red hints left and right of a broken window, and 5 gold windows that pay Golden Bones.
Data: `data/challenges.json` (windows, conditions, prizes). Full doc: Project doc `docs/challenges.md`.
Debug run args: `-- --fresh --challenges --chdone=c_first_k,g_fold --chbones=2 --chsel=2,1`,
`--chpend=id` (shatter on open), `--art=art_pinup`, `--tint=tint_moss`, `--ship=ship_ghost`, `--table=table_rot`.
Placeholder art: `python3 tools/make_placeholder_art.py` writes `art/gallery/placeholder_0N.png`.

## Dogfight GIF demos
`bash tools/record_demo.sh NAME FRAMES [args]` records with Godot's Movie Maker (fixed 30 fps) and writes `tools/demos/NAME.gif`.
Scripted demo: `--dfdemo=kami`: a kamikaze dives at you, you drift out of its path, swing round, and the super laser stops it (the demo kamikaze has 5,000 hp, so the gun bolts only flash on it).
`--dfdemo=volcano`: the volcano erupts ahead, two kamikazes dive at you: S-drift through the first (let go = DRIFT BOOST), super laser on the second, drift round, guns take the first one down.
`--dfhold`: hold BOOST through all 3 stages. `--dforbit=165`: look at the nose (cyclops visor shimmer).

## Card room (blackjack): 3D view
The room is drawn in perspective from your seat, like Poker Night at the Inventory (`scripts/cards/card_room_view.gd`).
- Every slice of a sprite stack is drawn as a flat textured quad at its own height. Copies fill the gaps, so the stacks look solid from a low angle.
- Characters are billboards. Cards are quads on the felt; the faces come from an offscreen atlas (`card_atlas.gd`).
- Camera shots are in `SHOTS`: seat, hand, dealer, seat0, seat1, result. The camera moves to whoever acts or talks, then comes back. It sways a little all the time.
- Debug: `--bjshot=seat0` holds a shot. `--bjauto --bjnext=peek` makes the table play itself (GIF: `tools/demos/demo_card_room.gif`).

## Card room (blackjack) art
All replaceable:
- `art/stacks/card_table.png` + `art/stacks/chair.png`: sprite stacks. Their four-view sheets come from `card_table()` and `chair()` in `tools/make_placeholder_views.py`. Run `tools/carve_all.sh` after you redraw a sheet.
- `art/table/felt.png`: the flat felt texture laid on the table top.
  - Paint it in LIGHT GREYS: the game multiplies it by the table skin's felt color.
  - 256x208 (the 64x52 felt area x4), rounded-corner alpha.
  - It sits 5 px inside the table top (`FELT_INSET` in `scripts/cards/blackjack_page.gd`).
- `art/table/chars/<building id>.png`: each manager seated, facing you. Any size; drawn about 140 px tall, bottom-centered on the seat.
- `art/table/chars/cadavire_dealer.png`: Cadavire in her dealer suit, behind the table (about 190 px tall). The table hides her waist.
- Placeholders: `python3 tools/make_table_art.py`. Do not run it after you replace the files: it overwrites them.
Debug run args: `-- --fresh --marrow=40 --rankset=1 --seat=broth,xylo --cards [--bjseed=5 --bjdeal=5 --bjevent=peek --bjact=hit,stand --table=table_midnight]`

## Hold'em
`scripts/cards/holdem.gd` holds the rules (7-card ranking, side pots, Monte Carlo strength, seat AI). `scripts/cards/holdem_page.gd` runs the table. Both use the same 3D card room as blackjack.
Fixed limit: blinds 1/2, bets 2 (preflop/flop) and 4 (turn/river), 4 bets max per round. 1 Marrow = 10 chips.
Felt: `art/table/felt_holdem.png`.
Debug: `-- --fresh --marrow=40 --rankset=1 --seat=broth,xylo --holdem [--hebuy=5] [--heauto] [--henext=peek|count|...] [--hehands=N] [--heshot=result]`
GIF: `tools/demos/demo_holdem.gif`.

### Card-table economy (slice 12)
- **House cut ("the jar"):** 5% of a Hold'em pot that saw a flop, max 3 chips. No flop, no cut. No cut during Fever. `Holdem.rake()`.
- **Bankrolls:** opponents sit with your buy-in (at least 20 chips). Each can reload ONCE. The next time they run short, they go home broke for 30 min (`Game.table_away`, saved). Their chair is empty and they also skip blackjack.
- **Break the house:** if Cadavire runs out after her one reload, the table closes for 30 min, you get +25 Fever, and the gold window `g_house` breaks. The Play page shows a countdown.
- **FAST: ON/OFF** (both tables, saved): AI turns at 0.28 s, the camera stays on the wide shot, and quips hold for 1.5 s.
- New challenge windows: `c_bj_5` (5 blackjack wins, Tip Jar Brass table), `c_he_home` (send a manager home, Poker Face tint), `g_house` (gold).
- Debug: `--hehome` (the seat-0 manager goes home), `--hebroke` (break the house), `--fast`.

## Blackjack split
One split per hand: two cards of the same value (any two 10-value cards count). Each hand has its own bet; you can double after a split. Split aces get one card each. A split 21 pays 1:1, not 3:2.
Debug: `--cards --bjpair=8 --bjdeal=4 --bjact=split,hit --bjshot=hand`. With `--bjauto`, the table splits 8s and aces by itself.
GIF: `tools/demos/demo_blackjack_split.gif`.

## Dogfight: 360 flight (slice 13)
- The player jet has a full attitude (`DfPlane.basis`). Pull = loop (no pitch limit); the stick works in the jet's own frame, also upside down.
- **ASSIST** (Play page, saved): wings level when you let go; letting go inverted = half roll upright. OFF = holds any attitude.
- **Barrel roll:** double-tap the stick, or Q / E. 0.5 s, sideways kick, 1.2 s cooldown. Enemy bolts, flak and kamikazes miss you ("DODGE!"); lava and the asteroid still hit.
- **Contrails:** wingtip trails on every jet. Player: faint, brighter on hard pulls/rolls, orange/blue in charged drifts, cyan at top boost (0.9 s). Fighters: white vapor, kamikazes: orange smoke (1.4 s, 55-70% opacity).
- Explosion puffs are capped at 70 px and fade next to the lens.
- PC keys: WASD steer, Shift boost, Space drift, Q / E roll, B bomb, L laser.
- Demo: `-- --fresh --dogfight --dfsim=3 --dfgod --dfdemo=loop`. GIF: `tools/demos/demo_360_loop_roll.gif`.

## Effects + sound (slice 13c)
- **Explosion sprites** (placeholders, redraw freely; same size: 8 square frames of 48 px in one row):
  - `art/fx/explosion.png`: normal kills (flash, fireball, then the smoke tears apart).
  - `art/fx/explosion_laser.png`: super-laser kills, in the beam's crimsons. A laser kill is 1.7x bigger, with a second pop, a red shock ring, 24 burning fragments and 14 dark chunks.
  - Regenerate the placeholders: `python3 tools/make_fx_art.py`.
- **Kamikaze smoke** follows the weather: dark against bright skies (morning, rain), pale ash against dark ones (storm, eruption, impact, night).
- **Sound:** autoload `Sfx` (`scripts/sfx.gd`). The 21 placeholder retro sounds are in `audio/sfx/` (`python3 tools/make_sfx.py`). Drop in a real `.ogg` or `.wav` with the same name to replace one.
  - Dogfight: gun, enemy_gun, laser_charge (ready), laser_fire, explosion, explosion_big (crash + laser kill), boost_loop (pitch rises per stage), drift_boost, roll, dodge, hoop, hit, bomb_drop, warning (kamikaze close).
  - Cards: card, chips, win, lose. Idle: buy / tap (building BUY), crunch (taste test).
  - Max 3 copies of one sound at once; a hard limiter on the master bus. Off in headless runs.
  - **Fold page > SETTINGS > SOUND: ON/OFF** (saved in `Game.sfx_on`).
- Videos with sound: Movie Maker writes audio when the file ends in `.avi` (`--write-movie out.avi`). Convert with `ffmpeg -i out.avi -c:v libx264 -preset veryfast -crf 24 -pix_fmt yuv420p -c:a aac out.mp4`.

## Sky koi (slice 14 + 14b holographic)
- 6 giant koi swim slow circles above the clouds (`scripts/dogfight/df_koi.gd`). Scenery only.
- **Holographic look** (T's reference: the glowing hologram koi of a neon city): drawn on two layers behind the jets and clouds, a normal-blend "colored glass" layer and an ADDITIVE light layer (`DfRender._draw_holo_koi`).
  - Glass: one smooth body hue that melts into the fin hue toward the tail, soft markings on the back, translucent fin membranes. Solid by day, thin at night.
  - Light: soft gradient glow around the body, bright edge rim (fresnel), twinkling scale chevrons, moving scan bands, gill line, glowing eye rings, two whiskers each side, fins as fans of glowing wavy rays, a dorsal crest, sparkles shed from the fins, a rare glitch.
  - Day/night balance (`koi_dark()`): by day the glass carries the color (additive light washes out on a bright sky); at night and in the storm the light takes over and they turn to neon.
  - Palettes: cyan ghost, gold leaf, gold + ice, sakura, violet + pink, jade, rainbow.
- They react: explosions (laser kills most), lightning and the asteroid scare nearby koi. They bolt, get pushed away and up, then calm down and drift back. Weather: they climb away from rain, hide above the storm, keep clear of the erupting volcano.
- Demo: `-- --fresh --dogfight --dfsim=3 --dfgod --dfdemo=koi` (day) or `--dfwave=6 --dfdemo=koi` (night). GIFs `tools/demos/demo_holo_koi_day.gif`, `demo_holo_koi_night.gif`.

## Asteroid (slice 14c) + demo
- T: "Bigger and should be in view longer".
- The rock is ~300 m across (the size of its crater; drawn at 4x, `DfRender.ASTEROID_SCALE`). It ignores fog, so you see it from far away.
- The countdown is 18 s (`DfGame.ASTEROID_WARN`, was 10). The rock starts 4.2 km out and 2.3 km up, coming in at an angle across the view, and is in the sky the whole time.
- A burning streak 3.6 km long (white-hot core, yellow, orange, red, grey smoke) and a flickering orange glow round the rock. The old square smoke puffs are gone.
- Demo: `-- --fresh --dogfight --dfwave=5 --dfgod --dfdemo=asteroid`. The demo holds the jet at 62 m/s during the countdown (`DfPlane.speed_cap`, demo only) and keeps the nose on the rock. GIF `tools/demos/demo_asteroid.gif`, video with sound `tools/demos/video_asteroid_with_sound.mp4`.

## Asteroid "go nuts" pass (slice 14d)
- Warning: "INCOMING! / Look up", the camera glances at the rock for 2.4 s (you keep control), the scene glows orange as it nears, red pulse + beep each second for the last 5 s.
- Impact: a short flash (not a white-out), 0.9 s of slow motion, a column of 7 fire blasts climbing out of the crater, a shockwave ring (white front, foam band, fire ring, air ring) racing out at 850 m/s to 2.8 km that shoves every jet it passes ("SHOCKWAVE!" when it reaches you), 34 burning rocks thrown out on arcs with fire trails that blow up where they land (9 damage if one hits you; a barrel roll dodges), a big shake, and the new `impact_rumble` sound.

## KO replay (slice 15)
- T: "I want a cinematic replay on ko like a fighting game and bars on top and bottom of the screen to make it cinematic".
- KO = the kill that clears a wave, or your crash. Live: "K.O." + slow motion + letterbox bars. 0.9 s later (1.4 s for a crash) the game freezes and replays KO-2 s .. KO+1 s (`scripts/dogfight/df_replay.gd`).
- Every sim step goes into a 3.4 s ring buffer (jets, ships, bolts, fx, debris, shockwave, lasers). Playback swaps those into the live renderer, jets interpolated between steps. 0.8x speed, then 0.32x from 0.35 s before the KO.
- Camera: 3 hard cuts, WIDE (T: "Wider shots"): orbit round the victim at 115 m (FOV 78), over your shoulder from 75 m back (FOV 84; crash: 95 m in front of you looking back), the KO from 125 m to the side (FOV 72).
- Black bars (12% of the height) top and bottom, a blinking red REPLAY tag, the HUD hidden. Tap / click / any key skips. After it the live match comes back exactly; "WAVE N CLEAR" shows then.
- Play page: KO REPLAY: ON/OFF (`Game.df_replays`). Off in scripted demos.
- Debug: `--dfcrashat=7` wrecks the jet at 7 s of match time. Videos: `tools/demos/video_ko_replay_wave.mp4`, `video_ko_replay_crash.mp4`, GIF `demo_ko_replay.gif`.

## QUAD GUNSHIP boss (slices 16 + 16b)
Wave 6 = "WAVE 6 · BOSS: QUAD GUNSHIP" (night) + 2 fighters + 2 kamikazes. Night waves start at 7.
- A 70 m quad-rotor gunship (`art/stacks/gunship.png`, 23 slices; source `tools/make_placeholder_views.py` `gunship()`). It hovers on a 650 m circle, 235 m up, nose on you. 1400 hull.
- **Meters, top middle:** name, red hull bar (tick at 55% = phase 2), 4 rotor pips (cyan up, red X down), blue CANNON bar (tick at the lock point). Labels: CANNON / LOCK! / FIRING.
- **Cannon cycle:** charge (8 s, phase 2: 6 s) → LOCK always 2.8 s before the shot (cyan line + ring on you, lags you ~1/8 s) → FIRE: a 2 s blue beam (phase 2: 2.4 s), hit radius 10 m (= the visible cyan core) → cool 1.2 s.
- **The beam chases you at 230 m/s.** Cruise (125), boost 1 (185) and boost 2 (220) get caught. Only top speed (boost 3 / drift boost, 255 m/s) in a HARD TURN across the beam gets away. A barrel roll does NOT dodge it.
- **Tested timing (slice 16b):** react within ~0.3 s of the lock, drift a full tier 2 (2.2 s), let go ~0.3 s before the shot → dodged with 18 m to spare. React 0.4 s late → only tier 1 → hit.
- **Near miss:** the beam passes within 30 m of you → a beat of slow motion; at the end "CLOSE DODGE!" +350 (a plain dodge: "DODGED!" +200). +15 boost either way.
- **Camera:** while the beam is close, the camera glances up to 35% toward it, so you see what you dodge. A blue glow on the screen edge shows an off-screen beam.
- **Rotors = weak spots:** 150 each. Your guns aim at the point nearest your nose (a live rotor or the hull). A bolt on a rotor: x2 to it, x1.5 to the hull. Your laser also burns the rotor nearest you (100). ROTOR DOWN: +300, -150 hull, it sags to that corner and trails smoke.
- **PHASE 2** (55% hull or 2 rotors down): "QUAD GUNSHIP · ENRAGED", faster cannon, longer beam, closer (430 m) and faster orbit.
- Laser on the hull: 260 (no one-shot). Kill = "BOSS DOWN!" +2500, wreckage, then the KO replay.
- **Killed by the beam:** "LASERED", Cadavire's `df_beam_ko` line, then a KO replay with 3 cuts: over the gunship's shoulder down the beam, a wide side shot (gunship + beam + you), close on your jet.
- Demos: `--dfwave=6 --dfgod --dfdemo=boss` (close dodge, rotors, phase 2, kill + replay) and `--dfwave=6 --dfdemo=bossko` (you get lasered + replay). GIFs `tools/demos/boss_close_dodge.gif`, `boss_rotors_phase2.gif`, `boss_laser_ko_replay.gif`; videos `video_boss_with_sound.mp4`, `video_boss_laser_ko_with_sound.mp4`.

## Lights pierce fog (slice 16)
T: "lights should pierce fog". Solid things (jets, ships, the gunship hull, clouds, bombs) fade out at `fog_end`. Light sources do not: explosions, laser rings, tracers, flak, lava, sparks, burning debris trails, the boss beam, cannon glow and nav beacons, and the holo koi's glow layer keep full strength out to `light_end` (3x fog, min 3.2 km). In fog they also get a scatter halo that grows with fog density (`DfRender._halo`). The gunship has blinking nav beacons (red left, cyan right) on its ducts, so in fog you find it by its lights.
- Demo: `--dfwave=3 --dfgod --dfdemo=fog` (storm fog, the boss 1.4 km out, explosions at 0.4 / 0.9 / 1.6 km). Video `tools/demos/video_fog_lights.mp4`.

## KO replay: widescreen + epic wide shots (slice 16c)
T: "still not the big cinematic wide shots I want in ko screens" → picked far camera + widescreen strip.
- The replay bars close to a true 2.39:1 movie strip, with gold edge rules, "REPLAY" in the top bar and a caption in the bottom bar ("LASERED BY THE QUAD GUNSHIP", "BOSS DOWN · QUAD GUNSHIP", "K.O. · WAVE N CLEAR", "WRECKED · WAVE N").
- Replay FOV is set across the strip (horizontal) and converted; the old "wide" shots were only ~60° across in portrait.
- 3 moving shots from one side of the action: far establishing (380-900 m, scaled to the fog), tracking wide, low-angle KO hero shot with a push-in.
- Glow trails + markers on the jets in far shots (cyan = you, red = the victim).
- GIFs `tools/demos/ko_beam_fullscreen.gif`, `ko_beam_strip.gif`, `ko_wave_strip.gif`; videos `video_ko_beam_with_sound.mp4`, `video_ko_wave_with_sound.mp4`.
- Also fixed: a flaky hold'em test did not accept the "closed" table state (you broke the house in that random hand).

## Bending beam + blue beam blast (slice 16d)
T: "That replay suck the beam doesn't bend and the explosion is red".
- **The beam bends.** It is light that flies out of the cannon at 2,200 m/s (`BOSS_BEAM_SPEED`). Each step the cannon emits a part along its current aim; the beam is the line through the parts. When the gunship sweeps after you, the far end lags behind: it bows ~220 m over its full length while chasing a crossing jet. When the shot ends, the tail detaches from the cannon and flies on until it lands. The hit test uses the same bent line.
- **The gunner leads you** by the light's flight time (the lock ring sits ahead of your nose). Steady flight gets hit; a hard turn swings your future point faster than the aim can follow.
- Track speed 240 m/s (the light delay costs ~10 m/s, so this keeps the old feel). Measured over a full 2 s shot: cruise dead, boost 2 (220) half a hull, top speed across it escapes with ~16 m to spare. The human-timing drift dodge still gives CLOSE DODGE.
- **Blue blast for a beam kill:** new sheet `art/fx/explosion_beam.png` (`tools/make_fx_art.py`, white-cyan to deep blue), blue shock ring, blue halo, cyan sparks (`DfFx.beam_explosion`). Your red laser kills stay red.
- A beam passing right by the camera is now clipped at the near plane, so it fills the screen instead of vanishing.
- `--dfdemo=bossko` is now a FAILED dodge: it breaks across the beam with boost but is capped at 215 m/s, the beam whips after it and catches it. GIFs `tools/demos/beam_ko_fullscreen.gif`, `beam_ko_strip.gif`, `bending_beam_close_dodge.gif`; video `video_beam_ko_with_sound.mp4`.

## Replay clouds (slice 16e)
T: "Clouds need to be obscured or translucent in replays".
- In a replay every cloud is translucent (45%; clouds behind the action 60%).
- A cloud IN FRONT of the action that overlaps it on screen goes nearly clear (12%) around the victim, the attacker, the gunship and the KO point, with a soft edge so it reads as glass, not a hole (`DfRender._replay_focus` / `_replay_cloud_alpha`).
- No cloud white-out when the replay camera flies through a cloud.
- Live play is unchanged (clouds still hide things; that is gameplay).
- GIFs `tools/demos/beam_ko_strip_clouds.gif`, `wave_ko_strip_clouds.gif`.

## Beach set v2 + replay zoom (slice 16f)
T: "30% more zoomed in on average in replays and make beach assets look more in line with this" + two reference shots of a tropical cove (kept in `tools/art_src/refs/`).
- **Water (`df_super.gdshader`):** depth-graded shallows from a depth field in the map's B channel (`DfWorld.build`: the same island field that draws the coast, so the shallows follow every bay). Shore → deep: white-sand aqua, bright emerald, emerald, teal, open-sea blue, with dithered band edges. Animated caustic light nets on the bottom (chunky 2 m cells), dark reef patches in the mid shallows, no open-sea swell lines in the shallows, lapping shore foam.
- **Land colors:** white sand (was orange-yellow), lusher jungle greens, mossy dark rock.
- **Sea stacks (`spire`):** tall dark stone columns with three offset bulging moss tiers, moss curtains hanging off each tier, a mossy crown and a wide foot (`tools/make_placeholder_views.py` `spire()`, voxel model). Interior stacks 55-110 m; new sea stacks stand in the shallows along every beach.
- **Palms:** slender curved trunks with ring bands, 9 drooping fronds with leaflets, coconuts; ~22 m tall, 16 headings, and they lean OUT toward the sea.
- **Pipeline:** `project_views()` turns any voxel model into the 4 sheet views. `tools/fix_magenta.py` removes magenta the carver leaks into hidden voxels (it also fixed 80 px in the gunship and 12 px in the volcano). Both run from `tools/carve_all.sh`.
- **Replays:** every shot 1.3x closer (`DfReplay.ZOOM`). A sea stack or the volcano standing in front of the action and covering it is ghosted to 30% (soft edge); everything else stays solid.
- Demo `--dfwave=1 --dfgod --dfdemo=beach`: a slow low pass along the main island's shore (art review). GIF `tools/demos/beach_flyover.gif`, video `video_beach_flyover.mp4`; replay GIF `replay_zoom_ghost_stack.gif`.

## Replay shot library + weather light on the beach (slice 16g)
T: "It should be barely close enough to make out the planes, combine with randomly picked angles including side wing views overhead, turning into frame, from the front of the target plane, etc also how does the water appear in other weather make sure it's not jarring".
- **Replay shots (`DfReplay.camera`):** each replay picks 3 shots at random (no back-to-back repeat): early shots from side (wing-on, tracking), overhead (straight down, the jet pointing up the frame), into_frame (a fixed camera where the jet is ABOUT to be, read from the replay buffer, so it flies / turns into frame), front (head-on from the target's nose, the attacker behind it), chase (past the attacker to the target), orbit; the KO shot from side, low (looking up at the blast), front, overhead, into_frame (aimed at the KO point).
- **Distance:** every shot sits where the target jet is 8-12 px across in the 1/3-res view (~24-36 px on screen, about 150-230 m away): barely readable, never a dot. The replay camera now also gives an "up" vector (needed for the overhead shot). The glow-trail markers only show when a jet is smaller than ~6 px.
- **Weather light (`ambient` in each `DfWeather.PRESETS` entry):** the ground shader multiplies land, sand and the shallows by it; the shallows sink toward the weather's own sea color as the light drops; caustics need sun; foam dims; stacks, palms and the volcano take it as their sprite color. Morning is unchanged; rain, storm, eruption, impact and night no longer glow.
- Tests: 113 dogfight checks (new: every shot type frames the target at a sane distance; plans are 3 shots, no repeat, 8-12 px; every weather has an ambient and storm / night are darker).
- Media: `tools/demos/replay_shots_day_a.gif`, `replay_shots_day_b.gif`, `replay_shots_beam.gif`.

## Replay director: scored shots + a budget (slice 16h)
T: "Make a scoring system for the replay shots with events and multiple planes in the shot worth more and repeating shots takes away points. Manager budget for cool plays basically".
- Before a replay, the director (`DfReplay._make_plan_scored`) test-flies every candidate shot (7 types x 2 framings, per slot) through the recorded footage at 6 sample times and scores what lands in the 2.39:1 strip (`score_shot`, weights `W_*`):
  - target jet in frame +6 (out of frame -8); each OTHER jet +4 (the gunship 6); 2+ jets together +3;
  - explosions +5 (laser / beam kills +8); your super laser +6; the gunship's beam +6; bolts +0.5 each (max 3);
  - KO shot: the KO point in frame from the KO on +10; looking at land +1. Per-sample points are averaged x10.
- Repeats cost points: the same type twice in one replay -30 (first and last -15); each use in the last 9 shots -8 (the last replay's -16).
- **Budget:** side / chase cost 1, front / orbit / low 2, overhead / into_frame 3; a replay gets 6. The director buys the highest-scoring 3-shot plan it can afford, so the expensive angles go to the coolest moments. A ±3 random tie-break keeps it from being robotic.
- Debug builds show the pick in the top bar: "DIRECTOR 3/3 INTO_FRAME 412 (plan 693, cost 6/6)".
- Tests: a second plane in frame scores more (70 → 140), a blast more again (190); recent shots lose points; every plan is within budget; over 12 replays the history rotates through all 7 shot types.
- GIFs: `tools/demos/director_wave_ko.gif`, `director_beam_ko.gif`, `director_boss_down.gif`.

## Slice 16i: iPhone web build (2026-11-26)
T: "iPhone and we will use web route" (no PC available).
- `export_presets.cfg`: preset **Web**. Threads OFF (runs on plain GitHub Pages, no special headers). Includes `data/*.json` and `art/stacks/*.json` (loaded by path at runtime). Excludes `tools/`, `tests/`, `build/`.
- `project.godot`: `renderer/rendering_method.web="gl_compatibility"` (WebGL 2). Desktop and phone builds stay on "mobile".
- `.github/workflows/web.yml`: on push to `main`, install Godot 4.7.2 + web templates, run the rule and dogfight tests (a failure blocks the publish), export, publish to GitHub Pages.
- `.gitignore`: `export_presets.cfg` and `*.import` are now committed (Godot 4 needs the import settings); `build/` and `tools/demos/` are ignored.
- Local check: `godot --headless --path . --export-pack "Web" build/test.pck`, then run that pack alone from an empty folder with `--main-pack`. Menu and boss wave both run, no script errors.
- Repo: github.com/MetaRidley-jpg/Cadbeta (public). Live build: https://metaridley-jpg.github.io/Cadbeta/ (rebuilds on every push to `main`, ~1 min).
- One-time repo setup (done 2026-11-26): Claude GitHub App installed on the repo (push access); Settings → Pages → Source: "GitHub Actions" (the workflow token cannot turn Pages on).

## Slice 16j: touch scrolling fix + Play home screen (2026-11-26)
T (first test on the iPhone web build): "Scrolling doesn't work on mobile, condense play into an app icon screen basically".
- **Bug:** a finger drag only scrolled a list when it started on an empty gap. Cards (PanelContainer) and buttons STOP input by default, so the ScrollContainer never saw the drag. This was not web-only; it would hit a native phone build too.
- **Fix:** `main.gd _touch_scroll_fix()`: every Control inside a ScrollContainer that STOPs input now PASSes it up (hooked on `SceneTree.node_added`, so rows built later are covered). Godot still makes a short tap a press; a drag past the 14 px deadzone scrolls and presses nothing.
- **Play home screen:** 3x2 app icons (`scripts/play_icon.gd`): Pool, Dogfight (best-wave badge), Blackjack, Hold'em (lock + countdown when the table is closed), Pinball (SOON, locked), Options. One tap = play. Options holds jet / ASSIST / KO REPLAY / table skin / bet table / pool note. Debug flag `--playopts`.
- **Test:** `tests/touch_test.tscn` (25 checks) sends real ScreenTouch / ScreenDrag events: drags on cards and buttons scroll every overflowing list and press nothing; the Play home fits one screen; taps on icons open Options and start the dogfight. Added to the web build gate.

## Slice 16k: iPhone notes round 2 (2026-11-26)
T: "The 8 ball charge meter is in the app swipe away spot so it doesn't work / The mobile replays can remove the cinematic bars and just be a replay, pc will still have them / Make the auto targeting a little wider than the reticle shows / Poker games are not stable at all / Weather should be random and you can make the text that appears in dogfight yellow with black outlines and fade faster". T on poker: "Freezes / stops, Crashes entire app shortly after launch".
- **Poker crash:** the card room sent 8,500-14,900 draw calls per frame (every stack slice copied per pixel of rise, each copy split into up to 36 polygons, each a draw call); room draw code 47-79 ms per frame. Now one triangle batch per stack/quad (copies placed by 2D interpolation between two projected rows): ~60-120 draw calls, 3-5 ms. Same look (before/after frames). Memory was flat (no leak). Guard: `cards_test` times the room draw (< 15 ms).
- **Hold'em stress** (`tests/holdem_stress.tscn`, optional, slow): real-time play over many seeds; no lost chips or hangs in normal play. `open()` now clears the step queue.
- **Phones:** `Game.is_phone()` (native mobile, iPhone/Android browser, or `--phone`). Web phones keep 4.5% of the screen height free at the bottom (home-bar swipe), so the pool power strip works.
- **Replays on phones:** no bars, no film caption, a yellow REPLAY tag; the director scores shots on the full frame. PC keeps the 2.39:1 strip.
- **Auto-targeting:** gun cone 11° → 13°; the idle reticle is sized from the cone (cone ≥ 1.2x the reticle, reticle capped at 56 px).
- **Random weather:** each wave rolls clear / rain / fog+thunder / eruption / night (no repeats in a row); title + Cadavire line follow it. The asteroid wave keeps the impact sky; demos keep the fixed order.
- **Dogfight text:** yellow (#ffe14a) with black outline; messages hold 65% as long (min 0.45 s) and fade in 0.25 s.
- Tests: dogfight 145, cards 57.

## Slice 16l: master sprite sheet + vector import (2026-11-26)
T: "Make a master sheet of sprites for me to redraw from front, I will provide vector illustrations but I still want you to adjust and put it in the game with pixel stacking and pixel art".
- `tools/make_master_sheet.py` → `tools/redraw/`: `master_sprite_sheet.png` (14 stacks with all 4 views + native px sizes + slice counts, 16 flat sprites, code-drawn list), `templates/<name>.svg` (Illustrator/Figma: REFERENCE, GUIDES, LABELS, BACKGROUND, YOUR_ART layers; 8 units = 1 game px), `manifest.json`, `REDRAW_GUIDE.md`.
- `tools/import_vector.py <name> <svg>`: drops helper layers, renders with rsvg-convert, 8x8 block → 1 px (dominant color, ≥ 50% coverage), writes the 4-view sheet (empty BACK = mirrored FRONT) and carves that one asset (`ONLY=<name> bash tools/carve_all.sh`); flats overwrite the game PNG. Backups in `tools/redraw/backup/` (git-ignored).
- Verified: round trip (the current art pasted as YOUR_ART) gives a 100% identical stack for jet_player and gunship and an identical flat for broth; a rough vector jet imports, pixelates crisply and carves.

## Slice 16m: boot weather, smooth weather, KO!, enemies left (2026-11-26)
T: "Make sure the wave 1 weather loads on boot dogfight and make the transitions between weather smoother and longer. Instead of take down have a KO! And have enemies remaining in the right side top".
- Wave 1's random sky is rolled in `start()` and shown instantly during GET READY (it used to open in morning and switch at wave 1). Demos ignore the roll (fixed order); `--dfwave` jumps snap the sky.
- `DfWeather`: colors blend over 12 s with smoothstep (was 4 s linear). Rain / ash / thunder fade by amount over 9 s (`rain_amt`, `ash_amt`, `thunder_amt`); thunder and lava start only once the weather is half built; the renderer draws a share of the drops / ash by amount.
- Kill text "TAKEDOWN!" → "KO!" (also TERRAIN KO!, ASTEROID KO!, "KOs:" in the results, Cadavire's line).
- HUD: "ENEMIES LEFT n" (jets + kamikazes + ships + boss) right-aligned under the bars, during a wave; it pops white and bigger when the count drops.
- Tests: dogfight 155.

## Slice 16n: moving ring courses + cyan chain laser (2026-11-26)
T: "Change the rings to be bigger and twinkle and push around a scripted path. Make 3-4 different variations. If this is completed your laser powers up to big and cyan and your ship sparks / The cyan laser can chain multiple enemies possibly combo all of them. The enemies will spark blue instead of red if they will chain. When the cyan laser makes contact with enemy ship thunder also strikes the ship".
- `scripts/dogfight/df_rings.gd` (`DfRings`): one course of 5 rings at a time (the old static hoops are gone). Rings 1.8x bigger (hit radius 29 m, was 16), each ring rides a scripted path: SLALOM, CORKSCREW, LOOP WHEEL, SKY STAIRS (sideways speeds ~15-20 m/s). Fly them in order (next ring gold, twinkling star glints) within 25 s of the first; out of time = reset; done = a different variation appears after 6 s. Courses avoid ground + spires and stay under the 300 m ceiling (lowest of 8 headings).
- Course clear: `_supercharge()`: laser fully charged + cyan, the jet crackles with cyan sparks until it fires, button reads CYAN / CHAIN!.
- Cyan shot: a big cyan beam to the locked target, then the chain hops (every 0.13 s) to the nearest live enemy within 380 m (jets, kamikazes, ships, the boss), no cap. While armed, every enemy the chain will reach sparks / glows blue. Every cyan hit = a lightning strike from the sky + blue blast + thunder; jets are KO'd, the gunship takes 420 + rotor damage, ships 240. "CHAIN xN!" combo, 120 x hop number points.
- HUD: "RINGS n/5 · Ns" (red under 6 s), gold marker / edge arrow on the next ring. Sounds: zap, thunder, power_up (tools/make_sfx.py). Dialogue: df_supercharge (+ caveman). Replays record the zaps.
- Demo: `--dfdemo=rings` or `rings_slalom|corkscrew|loop|stairs`. Scripted pilot clears each course in 8.6-13.4 s.
- Tests: dogfight 184 (4 variations move + stay clear of the ground, in-order passes, reset, chain KOs 4 lined-up jets with 4 strikes and skips one out of range).
- Fixed while recording: ring paths first moved ~50 m/s sideways (even the scripted pilot missed); a course could be built through a sea stack or above the 300 m ceiling; the ring-pickup puff (also on the old hoops) drew a big square box right in front of the camera; the supercharge blast filled the screen. Now gold / cyan flecks with a 5 px cap.

## Slice 16o: skinny, larger rings that launch you (2026-11-26)
T: "The loops should be skinnier and larger and launch you to the next one and change your yaw".
- New thin ring sprite (`_ring_model`: radius 14 px, ~1.4 px band, white studs at the quarters), x1.5 → 42 m; hit radius 29 → 42 m; ring spacing 95 → 110 m.
- `DfPlane.launch(dir, time, min_speed)`: for 0.55 s the jet flies straight at the next ring's predicted position (lead solved in 3 passes) at ≥ 210 m/s while its nose (yaw + pitch) swings onto the line (slerp 14/s). The last ring throws you straight ahead (0.3 s, 230 m/s). Steering still applies on top.
- Bug found by the new test: the crossing test used the ring's current pose for both ends of the step, so a ring that slid/tilted could pass a jet sitting 0.1 m short of its plane. Now the last position is tested against the ring's last pose (`ppos`, `pnormal`).
- Measured: after ring 1, a launch alone carries you through rings 2-5 on all 4 courses (0.1-4 m from ring centres). Tests: dogfight 189.

## Slice 16p: courses rarer in later waves (2026-11-26)
T picked option 3 ("3 later I'm gonna test"): keep the exact ring launches; make courses rarer later. `DfGame.course_gap(wave)`: the next course appears 6 s after one is cleared in waves 1-3, then +7 s per wave (13, 20, 27, 34), max 40 s. Tests: dogfight 193.

## Slice 16q: ring courses in replays (2026-11-27)
T: "Wrap up and make loops appear in replays then we migrate on mobile to Claude code".
- Replays record the ring course every frame (`DfRings.snapshot()`: kind, origin, axis, course clock, next, passed flags) and rebuild it on playback (`restore()`, course clock interpolated between frames), so rings show where they were, moving, the next one gold. The live course comes back after the replay. Before: replays drew the live course frozen at replay start (missing if it had been cleared, wrong place if it had moved).
- Demo `--dfdemo=ringsreplay[_<kind>]`: a replay right after ring 4. The `rings` demo now allows KO replays, spawns 4 jets, and its pilot holds altitude after the chain (it flew into an island).
- Tests: dogfight 197 (the recorded course plays back, at the recorded place, moving; the live course returns).

## Slice 16r: dev tooling for future work (2026-11-27)
T: "Optimize cadbeta for future work".
- `bash tools/run_tests.sh`: all 8 suites in parallel (~18 s), PASS/FAIL table, exit 1 on failure, logs in `build/test-logs/`. CI calls the same script (`CI=1`).
- Setup: apt fallback fixed (recording tools were silently missing in the cloud box); the session hook skips the ~1 GB web-template download.
- Removed a committed `.pyc`. Tests: all 8 suites pass.

### 16r part 2: dogfight runs better
T: "Just continue, make dogfight run better as well".
- Jets + fx 26 ms → 2 ms per frame at wave 8 (a PNG was re-read every frame for every jet). Match-start bake 6.5 s → 45 ms (`art/baked/`, `bash tools/bake_sprites.sh`). No more freeze when a new jet kind appears.
- Phone profiler: open the game with `?prof` at the end of the address. Detail: `docs/dogfight-performance.md`.

## Slice 16s: rings + boost (2026-11-28)
T: "Rings can spawn out of bounds" / "stop it from aiming into the ground" / "figure 8, big loop and helix shapes" / "let speed hold over longer when letting go of the button".
- Ring courses stay inside the arena; launches never throw you into the ground or sea.
- 3 new courses: FIGURE 8, BIG LOOP (a 140 m loop leaned 50°: a round upright loop this big does not fit under the 300 m ceiling), HELIX. All 7 courses pass a flyability test.
- Boost: the speed holds after you let go, then coasts down (~4.9 s to cruise, was ~1.9 s).
