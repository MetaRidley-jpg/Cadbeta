# Cadavire Godot build log

Engine: Godot 4.7.2 stable, renderer "mobile" (web: gl_compatibility), portrait 720x1280 (stretch canvas_items / expand), PC window 540x960. Project folder `cadavire/` (git repo, branch `main`, remote `github.com/MetaRidley-jpg/Cadbeta`).
**Play on the phone:** https://metaridley-jpg.github.io/Cadbeta/ (rebuilds on every push, ~1 min).
Latest deliverable: `cadavire_slice16q.zip` (2026-11-27, ~4 MB: the zip leaves out `tools/demos/` and `build/`; it includes the git history and the web workflow). Current priorities: `docs/todo.md`. Other docs (in `docs/`; the claude.ai Project mirrors them as `claude/*.md`): `docs/rings-and-cyan-laser.md`, `docs/sprite-redraw.md`, `docs/play-home-and-touch.md`, `docs/web-build.md`, `docs/managers-and-loyalty.md`, `docs/minigames.md`, `docs/challenges.md`, `docs/card-room.md`, `docs/holdem.md`, `docs/sound-and-fx.md`, `docs/dogfight-status.md`, `docs/dogfight-cinematics.md`, `docs/dogfight-boss.md`, `docs/dogfight-art.md`.

## Naming
- The prestige reset is called **Fold** (T's pick; it replaced "Rebury"). Code names stay `rebury` so old saves load.

## Architecture
- `scripts/challenges.gd` autoload **Challenges**: the challenge wall's rules and state. It loads BEFORE Game, and its state saves inside Game's save.
- `scripts/game.gd` autoload **Game**: all state and rules; it sends signals only. Card-table state: `table_away` (who went home broke, until when), `fast_table`. Dogfight settings: `df_assist`, `df_replays`.
- `scripts/lines.gd` autoload **Lines**: Cadavire's lines from `data/dialogue.json` (caveman. > fever. > base, parent-key fallback).
- `scripts/balance.gd`: idle-game numbers. `scripts/ui_theme.gd`: Theme + NORMAL/FEVER palettes.
- Scenes (hand-written .tscn, editor-editable): main, building_row, dialogue_box, manager_box, pool_game, dogfight. The Challenges page, the art viewer and the card tables are built in code.
- `scripts/play_icon.gd` (`PlayIcon`): the app icons on the Play home screen (slice 16j).
- `scripts/pool/`: pool. `scripts/dogfight/`: dogfight (data objects + DfRender Super Scaler renderer).
- `scripts/cards/`:
  - blackjack + holdem rules.
  - blackjack_page + holdem_page.
  - The shared 3D room view (`card_room_view.gd`), which draws the room and calls the page's `draw_felt(view)` / `draw_labels(view)`.
  - Card atlas + card art.
- Nav tabs: Bones, Schemes, Wardrobe, Stash, Play, Fold. The top bar has a CHALLENGES button.
- **Touch scrolling:** `main.gd _touch_scroll_fix()` sets every STOP control inside a ScrollContainer to PASS (on `node_added`), so a drag on a card or button scrolls. A control inside a list that needs its own drag must set its filter after `add_child` (detail: `docs/play-home-and-touch.md`).
- Tests (all pass):
  - test_runner: 366 rule tests + pacing bots.
  - ui_smoke: every button, scenes, full pool matches, bet limits.
  - pool_test: 19 checks + AI-vs-AI.
  - dogfight_test: 197 checks + autopilot matches + performance.
  - challenges_test: 116 checks.
  - cards_test: 56 checks.
  - holdem_test: about 50-58 checks (a few run only when the random hand reaches that state).
  - touch_test: 25 checks — real finger touch/drag events on every list page and the Play icons.
  - dogfight_test is now 193 checks; cards_test 57 (includes the card room draw-cost guard).
  - holdem_stress (optional, slow, not in the gate): real-time Hold'em over many seeds.
  - The web build gate runs rules + dogfight + touch before every publish.
- Always run tests with `--quit-after N` AND `-- --fresh`. Without `--fresh`, the suites load the last save and fail. The tests set `Challenges.enabled = false` so windows do not break while a test drives the game.
- A test script with a parse error leaves the scene without a script, so the run goes on until `--quit-after`. If a suite prints nothing, look for a parse error first. Check for a parse error with a short run before a long run.
- A NEW `class_name` script needs one `godot --headless --path . --import` run before command-line runs can see the class.
- Touch tests: event positions must go through `get_viewport().get_final_transform()` (the canvas is stretched); pick targets after resetting the scroll and away from the bottom edge (the nav bar).
- Screenshots: Xvfb + gl_compatibility at 720x1280, every slice. `--state=late` opens the Challenges wall on top; use `--fresh` for page shots.
- GIF demos: `tools/record_demo.sh` uses Godot's Movie Maker at a fixed 30 fps. Output goes to `tools/demos/`. Movie Maker frames come out at the PC window size (540x960), so crops must scale from that. An `.avi` output includes the sound.
- Checking dialogue: read it on full-size frames, not on contact sheets (twice I matched a dialogue strip to the wrong row and reported a bug that was not there).
- The renderer's FOV is VERTICAL. In portrait a given FOV is much narrower across; anything meant to feel "wide" must set the horizontal FOV and convert.
- Art pipeline: voxel model → `project_views()` → `tools/carve_all.sh` → `tools/fix_magenta.py` (the carver leaks shaded magenta into hidden voxels). T's art references live in `tools/art_src/refs/`.
- Weather: every look that is drawn in daylight colors must take the preset's `ambient` (see `docs/dogfight-art.md`). Review any new look in all 6 weathers (`--dfwave=1..6 --dfdemo=beach`).
- Numbers in docs are measured, not guessed (16h: I first wrote a director cost without measuring it; it is now measured).
- **Runtime file loads:** `data/*.json` and `art/stacks/*.json` are read by path, so any export preset must include them by filter (slice 16i). A new runtime-loaded folder must be added to the Web preset's include filter.
- **Web build:** `.github/workflows/web.yml` (detail: `docs/web-build.md`). Check an export locally with `godot --headless --path . --export-pack "Web" build/test.pck`, then run the pack alone with `--main-pack`.

## Slice 1: core idle loop (2026-11-25)
10 buildings, managers, buy modes, speed milestones, Schemes, Fever, taste tests, 8 costumes, Stash (equip or gift), Fold, prestige rank box, autosave + offline, safe area.

## Slice 2: manager scenes, loyalty, level (2026-11-25)
- A manager is a character with 5 loyalty tiers (x1 -> x7.5, permanent).
- Each tier has a 3-way scene in a second dialogue slot, with the "bones aren't money" arc and tier-5 motives.
- Permanent level meter: 3 levels per x10 bones. Only an endgame reset clears it.
- Bone Density removed.

## Slice 3: pool (2026-11-25)
8-ball vs Cadavire. Her skill comes from her outfit. Drag-to-shoot controls and a guide line. The AI was tuned with AI-vs-AI logs.

## Slice 4: Marrow lock-down + dogfight (2026-11-25)
T's direction: restrict Marrow further; wagers only in card games (blackjack, hold'em; managers can join; funny business); dogfight next. T's answers: max bet tied to rank; dogfight first; camera "Burnout"; survive the waves.
- Pool is a friendly match (bones + Fever). `Game.MAX_BET_BY_RANK` = [5, 10, 25, 50, 100].
- Dogfight rules built: drift/boost, auto-guns, bombs, fighters/kamikaze/flak ships, 5 scripted weather waves + endless night waves.

## Slice 5: tight sprite stacking, top-down (2026-11-25) - replaced
T: "That's voxel not pixel stacking, do tight pixel stacking in saturated colors". I built a top-down stacked renderer. T then rejected top-down: "I still wanted a full 3d dog fight environment with jets ... fast as burnout or starfox. No voxel meshes ... retro sega".

## Slice 5b (v3): SEGA Super Scaler 3D (2026-11-25)
- Mode-7 ground + sky shader (`df_super.gdshader`). The world map is a data texture (R = terrain band, G = scorch/lava, B = sea depth near islands since 16f).
- Every object is a pre-baked multi-angle sprite (`DfSprites`: 32 headings x several elevations, one outline). It is projected through the chase camera and scaled with nearest filtering, far to near.
- Chase cam: 34 m behind, 7.5 m up. The FOV widens with boost. 1/3-res viewport.

## Slice 6: art from the danielwh2/sprite-stacking pipeline (2026-11-25)
T: "Look at this https://github.com/danielwh2/sprite-stacking this is what I want dude". T's answers: flight "Full 360 with drifting in air and trails"; art "I draw placeholders, you redraw".
- Vendored the repo's slicer (`tools/sprite_stacking/views_to_slices.py`, MIT).
- `tools/make_placeholder_views.py` draws four-view sheets (TOP nose down, SIDE nose left, FRONT, BACK). `tools/carve_all.sh` carves them into `art/stacks/<name>.png` strips + turntable checks.
- The game bakes the strips at load (`DfSprites.bake_art`). World size matches the old models, so hitboxes did not change. Note: `bake_art` scales the art to the fallback model's size, and a stack's origin is its bottom slice.
- Fixes: no outlines in the sheet views; magenta background; closed hoop needs a 2 px slit; near clip; flaky fever test.

## Slice 7: Challenges wall (2026-11-25)
T: an achievement menu based on the Smash Bros. Brawl Challenges screen; "change hammers to bones, we will make the rewards". Prizes: art, tints, alt dogfight jets, card-table skins. "leave most blank for now".
- 4 x 32 wall with a minimap, shatter animation, left/right red hints, gold windows paying Golden Bones.
- Full detail: `docs/challenges.md`.

## Slice 8: T's jet (2026-11-25)
T sent a concept sheet: "ok now make it my plane" (`tools/art_src/tlc_jet_concept.png`).
- `jet_player` redrawn from the sheet. Boost in 3 stages (red/orange, purple, blue blast). Red-outlined bolts, red lock-on reticle, super laser with lock sparks and a homing beam.
- Fix: strips load from the raw PNG in dev builds (a stale import had made a garbage box).

## Slice 8b: cyclops visor, bigger laser, GIF demos (2026-11-25)
T: "the ship should have a cyclops visor"; "the super laser should be bigger ... burst effect coming out of the plane visor"; "Reverse the grey and the red on the nose. The visor should be red and shimmer when you see it"; GIF demos.
- Grey helmet nose, one red cyclops band with a red shimmer (`df_units.gdshader`). Thick pulsing laser beam and a visor burst.
- **Bug fixed: every carved stack was flipped front-to-back** (jets flew tail-first since slice 6).
- GIFs: `demo_laser_vs_kamikaze`, `demo_boost_stages`, `demo_cyclops_visor`.

## Slice 9: drift boost, motion lines, border arrows, volcano demo (2026-11-25)
T: drift long enough for a short top-speed boost with some meter back; motion lines at max speed; a slightly wider FOV; border arrows to off-screen enemies; a volcano demo with two kamikazes, a drift, a laser and a regular takedown.
- Drift boost: tier 1 (1.1 s) or tier 2 (2.2 s), fired on release. Motion lines at top speed only; FOV 104.
- Border arrows use camera space (the old ones broke for enemies behind you).
- GIF: `demo_volcano_two_kamikaze`.

## Slice 10: card table, blackjack (2026-11-25)
T: "Continue development". Then, mid-build: "It should be a pixel stacked table with a flat replaceable texture, and chairs at each table, we will have images for each character in position and cadavire in a dealers suit in the dealer area".
- Blackjack with Cadavire dealing: 4-deck shoe, S17, 3:2, double. Marrow only, capped by rank. You cannot leave mid-hand.
- Up to 2 met managers sit in, play their own hands, and cause one "funny business" event per hand (40%).
- Manager quips use slot 2 (`manager_box.quip()`, a no-reply mode). Cadavire's dealer lines are `bj_*`.
- Art: sprite-stacked table (`card_table`) and chairs (`chair`); flat felt texture `art/table/felt.png`; character images `art/table/chars/<id>.png` and `cadavire_dealer.png`. Placeholders: `tools/make_table_art.py`.
- `Game.settle_wager(stake, back)` added. Pipeline fix: sheet views centered vertically.

## Slice 10b: card room in 3D, Poker Night camera (2026-11-25)
T: "More dynamic like the camera angle of night at the inventory".
- First-person 3D view from your seat: the dealer across, the managers at the ends. Sprite stacks in perspective, billboards, cards on the felt from an atlas.
- Camera shots: seat, hand, dealer, seat0/seat1 (whoever talks), result.
- Full detail: `docs/card-room.md`. GIF: `demo_card_room.gif`.

## Slice 11: Texas Hold'em (2026-11-25)
T: "Continue".
- Fixed-limit Hold'em in the same 3D room. Cadavire PLAYS across the table, with up to 2 managers.
- Buy-in in Marrow (rank cap), 1 Marrow = 10 chips, cash out between hands, rebuy after busting.
- 7-card ranking, side pots, Monte Carlo seat AI with a style per manager motive.
- Funny business in Hold'em form. The camera turns to whoever acts.
- Refactor: the room view asks the page to draw its own felt items and labels, so both games share it.
- Full detail: `docs/holdem.md`. GIF: `demo_holdem.gif`.

## Slice 12: card-table economy, FAST table, blackjack split (2026-11-25)
T: "Continue I like your changes keep working". I took this as a yes to the three fixes from the slice 11 audit, then built split.
- **Hold'em house cut:** 5% of a pot that saw a flop, max 3 chips, none in Fever.
- **Bankrolls:** opponents sit with your buy-in (min 20 chips) and reload once. Then they go home broke for 30 min (saved). Their chair empties and they skip blackjack too.
- **Break the house:** Cadavire out of chips closes Hold'em for 30 min, gives +25 Fever and breaks a gold window. The Play page shows a countdown.
- **FAST: ON/OFF** on both tables (saved): quick AI turns, calm camera, short quips.
- **Blackjack split:** once per hand, two cards of the same value (any two 10s). Double after split allowed. Split aces get one card each. A split 21 pays 1:1.
- **3 new challenge windows:** 5 blackjack wins, send a manager home, break the house (gold). 20 designed windows, 6 gold.
- Fixes found in screenshots: chips covered split hand 1; your hand name showed twice; PEEK / TELL stayed after the table closed.
- GIF: `tools/demos/demo_blackjack_split.gif`.

## Slice 13: full 360 flight, barrel roll, contrails (2026-11-25)
T: "Continue". T had not answered "auto-level or full manual?", so I built both behind a setting (ASSIST ON by default).
- **Attitude:**
  - The player jet has a full `Basis` and no pitch limit. The stick acts in the jet's own frame, so a full pull is a loop.
  - AI jets keep "classic" flight.
  - The `yaw` / `pitch` properties still read and write, so old demo and debug code works.
- **ASSIST:** levels the wings when you are not pulling hard, and eases the nose to the horizon. Letting go inverted gives an Immelmann. OFF = expert. The toggle is in Play → Options (was the dogfight card before 16j), saved in `Game.df_assist`.
- **Barrel roll:** double-tap the stick or Q / E. One roll in 0.5 s with a sideways kick. Bolts, flak and kamikazes miss you during it ("DODGE!", +15). Lava and the asteroid do not.
- **Camera:**
  - Its "up" follows the canopy. A new `DfRender.set_camera_frame` works in any attitude, including straight up.
  - The ground/sky shader already handled any camera frame.
  - In long drifts the camera stays within 28 deg of behind the jet and at least 30 m away.
- **Sprites in any attitude:** frame chosen in the jet's own frame + screen turn (`_frame_turn`). AI jets now also show their pitch, which they did not before.
- **Contrails:** wingtip trails for every jet. Bright on hard pulls and rolls, orange/blue in charged drifts, cyan at top boost.
- **Ceiling and TURN BACK** steer in the jet's frame (they work inverted). The autopilot uses `steer_to`.
- Demo `--dfdemo=loop` + GIF `tools/demos/demo_360_loop_roll.gif`. The kami and volcano demos were re-recorded and still play through.
- Tests: 18 new dogfight checks (66 total).
- Bugs found while recording:
  - The demo's half loop went over the 300 m ceiling. The ceiling then pulled the jet into a dive, so the demo now starts lower.
  - The demo's drift started before the Immelmann finished.
  - A long hard drift slid the jet off screen (fixed with the camera limits above).
- Full detail: `docs/minigames.md` "360 flight".

## Slices 13b-15b (2026-11-25/26): detail in the dogfight docs
- 13b: enemy contrails. 13c: explosion sprite sheets, weather-tinted kamikaze smoke, 22 placeholder sounds, bigger redder laser-kill blasts (`docs/sound-and-fx.md`).
- 14 / 14b: holographic sky koi that flee explosions and weather; honest dogfight status review (`docs/dogfight-status.md`).
- 14c / 14d: the asteroid, bigger and longer in view, then the "go nuts" pass: camera glance, shockwave, debris, slow-mo (`docs/dogfight-status.md`, `docs/dogfight-cinematics.md`).
- 15 / 15b: fighting-game KO replay with letterbox bars, then wider shots (`docs/dogfight-cinematics.md`).

## Slices 16-16e (2026-11-26): QUAD GUNSHIP boss + KO cinematics — detail in `docs/dogfight-boss.md` and `docs/dogfight-cinematics.md`
- 16: the wave-6 gunship boss (hull + cannon meters, blue belly beam, dodge only at top speed / drift boost); lights pierce fog.
- 16b: audit fixes (lock 2.8 s before the shot, 10 m hit radius, near-miss slow-mo + CLOSE DODGE, rotor weak spots, PHASE 2) + the beam KO replay.
- 16c: the to-do list (`docs/todo.md`); KO replay in a 2.39:1 strip with a film caption, horizontal FOV, moving shots, glow trails; flaky hold'em test fixed; zip without demos.
- 16d: the beam bends (light flies at 2,200 m/s, the gunner leads you, track 240); beam kills blow up blue.
- 16e: see-through clouds in replays.

## Slice 16f: beach set v2 + replay zoom (2026-11-26)
T: "30% more zoomed in on average in replays and make beach assets look more in line with this" + two tropical-cove reference shots.
- Emerald/turquoise depth-graded shallows with caustics, reef patches and lapping foam; white sand; lusher jungle; mossy dark rock.
- Mossy sea stacks (offset moss tiers + moss curtains), new stacks standing in the shallows; tall palms that lean out to sea.
- `tools/fix_magenta.py` (also fixed magenta leaks in the gunship and volcano).
- Replays 1.3x closer; stacks / volcano in front of the action ghost to 30%. Demo `--dfdemo=beach`. Detail: `docs/dogfight-art.md`.

## Slice 16g: replay shot library + weather light on the beach (2026-11-26)
T: "It should be barely close enough to make out the planes, combine with randomly picked angles including side wing views overhead, turning into frame, from the front of the target plane, etc also how does the water appear in other weather make sure it's not jarring".
- A replay shot library (side / wing-on, overhead, into_frame, front, chase, orbit, low KO shot), each framed so the target jet is just readable (~150-230 m). Detail: `docs/dogfight-cinematics.md`.
- Weather presets got an `ambient` daylight color; the ground shader, the shallows (sink toward the weather's sea), caustics, foam and scenery sprites take it. The beach no longer glows in storm / eruption / impact / night. Detail: `docs/dogfight-art.md`.

## Slice 16h: replay director — scored shots + a budget (2026-11-26)
T: "Make a scoring system for the replay shots with events and multiple planes in the shot worth more and repeating shots takes away points. Manager budget for cool plays basically".
- Before a replay, a director test-flies all 34 candidate shots through the recorded footage and scores what lands in the strip (target, extra planes, multi-plane bonus, explosions, laser, beam, bolts, the KO, scenery). Repeats in a replay and shot types used in the last replays lose points.
- Budget: shots cost 1-3 (overhead / into_frame 3), 6 per replay; the director buys the best plan it can afford. Debug builds show the pick + score in the top bar.
- Measured: target alone 70 → with a wingman 140 → with a blast 190; all 7 shot types used over 12 replays; planning 5.8 ms on desktop (light footage).
- 117 dogfight checks. Detail: `docs/dogfight-cinematics.md`.

## Slice 16i: iPhone web build (2026-11-26)
T: "Is there a way I could do a phone build without pc? I'm on mobile rn" → "iPhone and we will use web route".
- `export_presets.cfg` preset **Web** (threads off, includes the runtime JSON data and stack art), `renderer/rendering_method.web="gl_compatibility"`, `.github/workflows/web.yml` (install Godot + templates, run tests as a gate, export, publish to GitHub Pages).
- `.gitignore`: `export_presets.cfg` and `*.import` now committed; `build/` and `tools/demos/` ignored.
- **Live:** repo `MetaRidley-jpg/Cadbeta` (public), site https://metaridley-jpg.github.io/Cadbeta/. T linked GitHub (Customize → Connectors → GitHub Integration), installed the Claude GitHub App on the repo (push was 403 before), and set Pages source to GitHub Actions (the first publish failed "Not Found" before). Detail and risks: `docs/web-build.md`.

## Slice 16j: touch scrolling fix + Play home screen (2026-11-26)
T, first phone test: "Scrolling doesn't work on mobile, condense play into an app icon screen basically".
- **Bug:** a drag that started on a card or a button scrolled 0 px (STOP mouse filter). Not web-only; a native phone build had it too. Fix: `_touch_scroll_fix()` (STOP → PASS inside any ScrollContainer, on `node_added`). Measured after: ~279-410 px scroll, 0 accidental presses.
- **Play home screen:** 3 x 2 app icons (`PlayIcon`): Pool, Dogfight (W-best badge), Blackjack, Hold'em (lock + countdown while closed), Pinball (SOON), Options (jet, ASSIST, KO REPLAY, table skin, bet table, pool note). Fits one screen at 720x1280.
- Fixed from the screenshots: the home line said "Your max bet: 0 Marrow" on a new save (it showed Marrow held, not the rank cap); now "bet up to 5 Marrow at rank 0 (you have 0)".
- `tests/touch_test.tscn` (25 checks), added to the web build gate. Detail: `docs/play-home-and-touch.md`.

## Slice 16k: iPhone notes round 2 (2026-11-26)
T: "The 8 ball charge meter is in the app swipe away spot so it doesn't work / The mobile replays can remove the cinematic bars and just be a replay, pc will still have them / Make the auto targeting a little wider than the reticle shows / Poker games are not stable at all / Weather should be random and you can make the text that appears in dogfight yellow with black outlines and fade faster". Poker, asked what it looks like: "Freezes / stops, Crashes entire app shortly after launch".
- **Poker crash (root cause found by measuring):** the card room sent 8,500-14,900 draw calls per frame (menu: 70); its draw code took 47-79 ms. Each stack slice was copied once per pixel of rise (max 40) and each copy split into up to 36 polygons, each its own draw call. Now one triangle batch per stack / quad, copies placed by 2D interpolation: ~60-120 draw calls, 3-5 ms, identical look (before/after frames). Memory was flat (not a leak). Also fixes blackjack (same room). Guard: `cards_test` times the room draw.
- Hold'em logic stress: no lost chips, no hangs in normal play; my first "crashes" came from my test leaving mid-hand (a player cannot). `open()` now clears the step queue anyway.
- `Game.is_phone()`: native mobile, `web_ios` / `web_android`, or `--phone`. Web phones keep 4.5% of the screen height free at the bottom (iOS home-bar swipe); the pool power strip is now above it.
- Phone replays: no bars / film caption, yellow REPLAY tag, the director scores shots on the full frame. PC keeps the 2.39:1 strip.
- Auto-aim: gun cone 11° → 13°; the dim reticle is sized from the cone (cone ≥ 1.2x the reticle; reticle capped at 56 px because a cone-sized box hid the jet). Measured: the old cone (~80 px) was already ~4x the old 20 px reticle, so the reticle was what looked narrow. Possible real cause still open: the 650 m gun range.
- Random weather per wave (no repeats in a row; title + Cadavire line follow it; asteroid wave keeps the impact sky; demos fixed).
- Dogfight text: yellow #ffe14a + black outline; hold 65% (min 0.45 s), fade 0.25 s.

## Slice 16l: master sprite sheet + vector import (2026-11-26)
T: "Make a master sheet of sprites for me to redraw from front, I will provide vector illustrations but I still want you to adjust and put it in the game with pixel stacking and pixel art".
- `tools/make_master_sheet.py` → `tools/redraw/` (master PNG, 30 SVG templates, manifest, guide); `tools/import_vector.py` (SVG → 8x8-block pixelation → view sheet → carve one asset). Round trip 100% identical; a rough vector jet imports and carves. Detail: `docs/sprite-redraw.md`.

## Slice 16m: boot weather, smooth weather, KO!, enemies left (2026-11-26)
T: "Make sure the wave 1 weather loads on boot dogfight and make the transitions between weather smoother and longer. Instead of take down have a KO! And have enemies remaining in the right side top".
- Wave 1's random sky is rolled in `start()` and shown instantly during GET READY (before: morning, then a switch when wave 1 began). Demos ignore the roll; `--dfwave` jumps snap the sky. Bug caught by a test: demos start after `start()`, so the random roll leaked into demos; `start_demo()` now resets it.
- `DfWeather`: colors blend over 12 s with smoothstep (was 4 s linear); rain / ash / thunder fade by amount over 9 s; thunder and lava only once the weather is half built.
- "TAKEDOWN!" → "KO!" (TERRAIN KO!, ASTEROID KO!, "KOs:" in results, Cadavire's line now says "K.O.!"). Code names stay `takedown`.
- HUD: "ENEMIES LEFT n" right-aligned under the bars during a wave; pops white + 25% bigger for 0.35 s when it drops.
- Tests: dogfight 155.

## Slice 16n: moving ring courses + cyan chain laser (2026-11-26)
T: "Change the rings to be bigger and twinkle and push around a scripted path. Make 3-4 different variations. If this is completed your laser powers up to big and cyan and your ship sparks / The cyan laser can chain multiple enemies possibly combo all of them. The enemies will spark blue instead of red if they will chain. When the cyan laser makes contact with enemy ship thunder also strikes the ship".
- `DfRings` (new): one 5-ring course at a time (SLALOM, CORKSCREW, LOOP WHEEL, SKY STAIRS), rings 1.8x, twinkling, in order within 25 s. The static hoops are gone.
- Clear = cyan supercharge (sparking jet, cyan button). Cyan shot: big cyan beam; chain hops ≤ 380 m, no cap; blue preview sparks; lightning strike + thunder on every hit; CHAIN xN combo.
- New sounds zap / thunder / power_up; dialogue df_supercharge; zaps in replays; demo `--dfdemo=rings[_kind]`.
- Fixed while recording: too-fast paths, courses through sea stacks / above the ceiling, the ring-pickup puff drawing a box over the jet (old hoops too), screen-filling supercharge blast, demo jets spawning in terrain.
- Detail: `docs/rings-and-cyan-laser.md`. Tests: dogfight 184.

## Slice 16o: skinny, larger rings that launch you (2026-11-26)
T: "The loops should be skinnier and larger and launch you to the next one and change your yaw".
- Thin ring sprite, 42 m (hit radius 29 → 42), spacing 110 m. `DfPlane.launch()`: a ring pass throws you at the next ring's predicted position (≥ 210 m/s, 0.55 s) and swings your yaw + pitch onto the line; the last ring throws you straight ahead.
- Bug found by the new launch test: moving rings could slide past a jet without the pass counting; crossings now test the last position against the ring's last pose.
- Measured: after ring 1 the launches alone clear all 4 courses. Detail: `docs/rings-and-cyan-laser.md`. Tests: dogfight 189.

## Slice 16p: courses rarer in later waves (2026-11-26)
T picked option 3 of the launch audit ("3 later I'm gonna test"): exact launches stay; the gap before the next course grows with the wave: 6 s (waves 1-3), 13, 20, 27, 34, max 40 s (`DfGame.course_gap`). Tests: dogfight 193. T will phone-test later.

## Slice 16q: rings in replays + move to Claude Code (2026-11-27)
T: "Wrap up and make loops appear in replays then we migrate on mobile to Claude code".
- Replays now record the ring course each frame (`DfRings.snapshot()`) and rebuild it on playback with the course clock interpolated: the rings sit where they were, still moving, passed rings gone, next ring gold. The live course comes back after the replay. Before, the replay drew the live course frozen at replay start. New demo `--dfdemo=ringsreplay[_kind]` (a replay right after ring 4). Tests: dogfight 197.
- Migration prep: the Project docs are now copied into the repo (`docs/`), plus `CLAUDE.md` (T's rules, code map, test + record commands, traps), `tools/setup_godot.sh` (Godot 4.7.2 + web templates + xvfb / rsvg / ffmpeg / Pillow; tested from zero and as a no-op re-run) and a SessionStart hook in `.claude/settings.json` that runs it in Claude Code cloud sessions only.
- **From now on `docs/` in the repo is the source of truth.** The claude.ai Project docs are a mirror of slice 16q.

## Decisions Claude made (T to confirm or override)
1. Schemes: one-time x3 upgrades; they reset on Fold.
2. Marrow sources: Fold, first 100 of a building (+3), rare exquisite taste (+1), card-table wins. Skill games never pay Marrow.
3. Taste test: she eats one cycle of that building. Reward: Fever + a 60 s buff.
4. Fever: about 18 active minutes. Minigames add Fever.
5. Items, costumes, rank, loyalty and level stay after Fold.
6. Rank thresholds: 10/50/75/100 of every building. Rank gates costumes and the max bet.
7. The loyalty bonus works before rehire.
8. Level gives no bonus; the endgame is not defined.
9. Pool: fixed groups, you break, no ball-in-hand.
10. Dogfight: guns auto-fire; you steer; portrait orientation kept.
11. Stacks are pre-baked per angle for the dogfight (mobile cost). The card room draws its stacks live in perspective.
12. Challenges: the wall opens by itself after a break (never mid-minigame). Golden Bones cannot break gold or empty windows. Tints go in the Wardrobe. Alt jets are cosmetic only.
13. T's jet:
    - Boost stages come from how long you hold boost.
    - The laser is a separate button with a 9 s charge.
    - The guns stay automatic.
    - The canopy is violet-navy, so only the cyclops band shimmers.
14. Drift boost: two tiers, fired on RELEASE, +12 / +20 meter.
15. Card table:
    - Blackjack has no insurance.
    - Managers only change the odds through funny business (they bet fake chips).
    - Seats go to the 2 highest-loyalty managers.
    - The player has no visible chair or character (first person).
16. Card room camera: Cadavire across the table, managers at the ends; cards 1.6x real size; the camera turns to a manager for 3 s when they talk.
17. Hold'em: FIXED LIMIT (not no-limit), 1 Marrow = 10 chips. Manager styles come from their funny-business role.
18. Card-table economy:
    - Cut 5% max 3, none in Fever.
    - One reload, then 30 min home.
    - Cadavire broke = the table closes for 30 min.
    - Blackjack split: once, any two 10s.
19. 360 flight:
    - ASSIST ON by default (Immelmann on release).
    - Barrel roll = double-tap / Q-E, 0.5 s, dodges bolts, flak and kamikazes.
    - AI jets do not loop.
    - The camera rolls with the canopy but not with a barrel roll.
20. Boss (T approved "230" + phase 2): the beam's light flies at 2,200 m/s and the gunner leads you; track 240 m/s (= the old 230 feel after the light delay); warning 2.8 s; hit radius 10 m; laser 260 to the hull + 100 to the nearest rotor; rotors 150 each; a roll does not dodge the beam.
21. Fog: lights reach 3x the fog distance (min 3.2 km); the boss hull fogs, its beacons do not.
22. KO replay framing: 2.39:1 strip (T picked); 3 shots per replay from the library; every shot frames the target jet at 9 or 11.5 px (T: "barely close enough to make out the planes").
23. Kill colors: a kill takes the color of what killed it (your laser red, the gunship's beam blue).
24. Replay see-through: clouds 45% / 60% behind / 12% over the action; stacks + volcano in front of the action 30%; live play unchanged.
25. Beach v2: sea stacks are real obstacles in the shallows; palms ~22 m tall, leaning out to sea.
26. Weather ambient values (morning 1.0 … night 0.42/0.50/0.80); jets, ships and lights do not take ambient (readability).
27. Replay director (T's idea, my numbers): the score weights, the shot costs (1-3) and the budget (6) are my first guess; the history covers the last 3 replays and is not saved.
28. Web build: threads off (works on free GitHub Pages); tests gate every publish; public repo (free Pages) for now.
29. Play home (T asked for icons; my layout): 3 x 2 grid, code-drawn icons, settings moved into an Options icon, Pinball shown as a locked SOON teaser.
30. Web phone bottom margin 4.5% of the screen height (no real safe-area value is available in the browser).
31. Auto-aim: 13° cone, reticle = cone / 1.2, max 56 px.
32. Weather pool: clear, rain, fog+thunder, eruption, night; the asteroid wave always uses the impact sky.
33. Redraw import: 8x8 block = 1 px, ≥ 50% coverage, dominant color; empty BACK = mirrored FRONT.
34. Weather timing: 12 s color blend, 9 s rain/ash/thunder ramp; the enemies counter counts ships and the boss too.
35. Rings: 5 per course, in order, 25 s from ring 1, +boost per ring kept; 6 s between courses.
36. Cyan laser: no hop cap, 380 m hop range, ships + boss are chain targets, the supercharge never expires.
38. Course gap numbers (6 s, then +7 s per wave from wave 4, max 40 s) are my pick for T's option 3.
37. Ring launch: aims exactly (lead-solved) at the next ring, 210 m/s for 0.55 s; it does not fly the jet by itself after that.

## Open questions / risks (raised to T)
- What endgame event resets the level? What does a level give?
- Rank 1 is hours away, and it gates bet size too.
- Late managers lag far behind early ones.
- Prestige may be too strong (run 5 is about 600x run 1 at minute 40).
- Challenges: with 20 of 128 windows designed, most hints point at empty windows.
- Web build: not a true native speed test; Safari can wipe web saves after 7 days unvisited; a public repo shows all code and art (see `docs/web-build.md`).
- Play home: Pinball takes a home slot while it does not exist; the bet cap is explained only in Options (see `docs/play-home-and-touch.md`).
- Dogfight:
  - A 5th touch button (LASER).
  - The laser one-shots any jet (not the boss).
  - The visor is hidden from the chase cam.
  - The drift-boost refill can make BOOST unneeded.
  - The drift boost can aim you away from laser targets.
  - Barrel-roll dodge: with a 1.2 s cooldown and 0.5 s of immunity, a player who rolls on cooldown is immune about 40% of the time against bolts.
  - Double-tap on the stick can fire by accident when a player lifts and re-touches the stick quickly to correct their steering.
  - Full camera roll in loops can cause motion sickness for some players. ASSIST helps, but there is no "keep the horizon level" camera option.
  - AI jets cannot loop, so in a turning fight a loop always shakes them. That may make loops too strong.
  - Boss: the dodge is a strict skill check; the beam's bend is strongest past your jet, not at it; phase 2 is tested but barely shown; the boss never dives or rams (see `docs/dogfight-boss.md`).
  - KO strip: 2.39:1 is ~1/4 of a portrait phone screen. In a beam KO the beam fills close shots. The director's weights are untuned and it cannot judge "pretty".
  - Beach v2: close up the stacks read as green blocks; the sky is still three flat bands; sea stacks make low beach runs harder (see `docs/dogfight-art.md`).
  - The units draw costs ~16 ms per frame on desktop (fixed cost); never tested on a phone.
- Card table:
  - Marrow buys costumes AND is the only stake. A losing streak at the table takes away outfit progress, and nothing in the game warns about that.
  - Funny business is mostly in your favor, so the blackjack house edge is smaller in practice.
  - Seats are automatic, so the player cannot choose a crush or a rival to sit with.
  - Hold'em profit is capped per sitting, but a strong player still has a positive edge over the AI. At rank 4 (100 Marrow buy-in) one cleared table is worth about 600 Marrow.
  - Sending managers home also removes them from blackjack and its funny business for 30 min.
  - The 30-min timers are real time and can be skipped by changing the device clock.

## Next
See `docs/todo.md`: T's phone retest (poker, pool, replays, aim); T's first vector redraw; then the 16 ms dogfight draw cost (the card room fix shows the likely cure: batch the per-sprite draws).

## Slice 16r: dev tooling for future work (2026-11-27)
T: "Optimize cadbeta for future work".
- `tools/run_tests.sh`: one command runs all 8 suites in parallel (~18 s vs ~74 s one by one), prints a PASS/FAIL table, exits 1 on failure, logs to `build/test-logs/`. Checked that a parse error makes it FAIL (exit 1). 120 s cap per suite.
- CI test step now calls `CI=1 bash tools/run_tests.sh` (one list of suites, no drift between CI and local).
- `setup_godot.sh`: apt now tries `install` before `update` (in the cloud box `apt-get update` failed, so librsvg / recording tools were silently missing).
- SessionStart hook skips the ~1 GB web-template download (`SKIP_TEMPLATES=1`).
- Removed a committed `tools/__pycache__/*.pyc`; `__pycache__/` and `*.pyc` ignored.
- Found: the hold'em suite count moves (about 52-55) because random hands gate some checks. Docs said a fixed 54.
- Tests: all 8 suites pass (rules 366, df 197, touch 25, ui, cards 57, pool 19, chal 116, holdem 55).

### 16r part 2: dogfight runs better
T: "Just continue, make dogfight run better as well". Detail: `docs/dogfight-performance.md`.
- Profiled per stage first (`DfProf`, `--dfprof`). The cost was NOT drawing: `DfPlane.sprites()` re-read the PNG strip and rebuilt the voxel model every frame for every jet (~25 ms at wave 8). Cached: jets + fx 26 ms → 2 ms.
- Baked atlases: `tools/bake_sprites.sh` → `art/baked/`. Match-start bake 6.5 s → 45 ms; the 0.5-1 s freeze when a jet kind first appeared is gone (all kinds pre-loaded). CI re-bakes before export. Web export include filter: `art/baked/*.json`.
- On-screen profiler readout: `?prof` in the web address.
- Tried koi batching: slower on desktop and web. Reverted.
- Checked in the exported web build (headless Chromium): baked files load, sprites draw right, script work ~6-9 ms per frame at wave 8.
- Tests: dogfight 201 (+4: sprites() is a cache lookup; all atlases fresh; 2 baked = live bake pixel checks). A stale file makes the test fail (checked).

## Slice 16s: ring bounds, ground-safe launches, 3 new ring shapes, boost hold (2026-11-28)
T: "Rings can spawn out of vounds" / "Also stop it from aiming into the ground" / "Also create potential paths for figure 8 big loop and helix shapes" / "When boosting let speed hold over longer when letting go of the button".
- Bounds: courses stay inside the arena (footprint check + headings back to the middle). Old worst case: 2,422 m out (test fails without the fix: checked).
- Launches: the last-ring launch never points down; every launch is tipped up until the throw + pull-out clears the ground by 35 m. Exact aim kept when safe.
- New courses FIGURE 8 (8 rings), BIG LOOP (6, tilted 50°), HELIX (7). Two big-loop designs failed the new flyability test (oval hairpins, full-turn wheel) and were replaced. Detail: `docs/rings-and-cyan-laser.md`.
- Boost: let go = the speed holds 0.4 / 0.8 / 1.2 s (stage 1/2/top), then coasts at 35 m/s² (was 70). Top speed → cruise ~4.9 s (was ~1.9 s). Drift still brakes at once. `DfPlane.BOOST_HOLD`, `COAST_DECEL`.
- Tests: dogfight 231 (+30: bounds over 3,600+ ring poses, launch safety x3, 3 shapes x3, flyability x7, boost hold x4).

