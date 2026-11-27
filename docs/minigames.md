# Minigames

> **Changed since this doc was written (read these first):**
> - Play page is now an app-icon home screen; the dogfight / table settings live in Play → Options (`docs/play-home-and-touch.md`).
> - Dogfight weather is random per wave (no repeats in a row; asteroid wave keeps the impact sky); transitions blend over 12 s (`docs/build-log.md` slices 16k, 16m).
> - The static hoops are gone: moving ring courses with launches and the cyan chain laser (`docs/rings-and-cyan-laser.md`).
> - Kill text is "KO!"; an "ENEMIES LEFT n" counter sits top right; dogfight text is yellow with a black outline.
> - Wave 6 has the QUAD GUNSHIP boss (`docs/dogfight-boss.md`); KO replays (`docs/dogfight-cinematics.md`).
> - Gun cone 13°, the idle reticle is sized from it (cone ≥ 1.2x reticle).
> - Sounds exist now (placeholders, `docs/sound-and-fx.md`).

## Shared rules (T's direction, 2026-11-25)
- Entry: the **Play** tab (5th nav button).
- **Skill games (pool, dogfight) are FREE.** They pay bones + Fever, never Marrow. Quitting costs nothing.
- **Marrow wagers happen ONLY at the card table** (blackjack and Hold'em, both built).
- **The max bet is tied to prestige rank:** rank 0: 5, rank 1: 10, rank 2: 25, rank 3: 50, rank 4: 100 Marrow (`Game.MAX_BET_BY_RANK`). It is never more than you own.
- Free payout (`Game.end_minigame(won, mult)`): a win pays max(100, 60 s of income) x mult bones and +8 Fever. A loss gives +3 Fever.
- Card bet: `Game.start_wager(bet)` takes the Marrow when the hand starts. `Game.settle_wager(stake, back)` pays out. Closing the app mid-hand counts as a loss.
- Match mode (`main.set_minigame_mode(on, which)`): the top bar and nav hide and the stage shrinks. Cadavire's dialogue box stays in the SAME top-right slot (slot 1). Taste tests and idle chatter pause.
- Second characters use slot 2 (under the stage).

## Pool (built)
- 8-ball vs Cadavire. You = solids and you break; she = stripes. A foul passes the turn. A scratch respots the cue ball (no ball-in-hand).
- Controls: touch the table to aim; `<` `>` nudge the aim; pull the power strip LEFT, then release. A guide line shows the paths.
- On a phone (web or native) the bottom 4.5% of the screen is kept free so the power strip is not on the iOS app-switch swipe (slice 16k).
- Her skill comes from her outfit (`PoolAI.profile()`). Fever makes her less accurate.
- Files: `scripts/pool/`, `scenes/pool_game.tscn`.

## Dogfight (built)
T's direction, in order:
1. Camera "Burnout"; win rule "survive the waves".
2. "tight pixel stacking in saturated colors".
3. "full 3d dog fight environment with jets ... fast as burnout or starfox ... retro sega".
4. "this is what I want" (https://github.com/danielwh2/sprite-stacking). Flight: "Full 360 with drifting in air and trails".
5. 2026-11-25: T's own jet concept sheet, "make it my plane".
6. 2026-11-25:
   - "the ship should have a cyclops visor".
   - "the super laser should be bigger as well and have a burst effect coming out of the plane visor".
   - "Reverse the grey and the red on the nose. The visor should be red and shimmer when you see it".
7. 2026-11-25:
   - "a mechanic that makes you shortly boost at max speed if you drift for long enough, and it gives you a little bit of boost back".
   - "motion lines at max speed and fov should be slightly wider".
   - "on screen enemy arrows need to move around the border pointing to enemies off screen".
8. 2026-11-25 (slice 13): T said "Continue" after I asked "auto-level or full manual?" for 360 flight. I built both behind a setting (ASSIST ON by default). T to confirm.
9. 2026-11-25 (slice 13b): "Enemies aren't leaving contrails". Their trails were there but at 14% opacity. They are now clearly visible.

### 360 flight (slice 13)
- **Attitude:** every jet now has a full `Basis` (-Z = nose, +Y = canopy).
  - The player flies **free**: the stick acts in the jet's own frame. Pull = nose toward the canopy (a full pull is a loop in about 4 s). Turn = rotate about the canopy axis. No pitch limit.
  - AI jets still fly "classic" (heading + pitch, max 68 deg), so their behavior did not change.
  - Old code that writes `yaw` / `pitch` still works: the setters rebuild a level attitude.
- **ASSIST (Play → Options toggle, saved in `Game.df_assist`, default ON):**
  - When you are not pulling hard (stick under 30%), it rolls the wings level at 2.2 rad/s.
  - With the stick centered and the jet upright, it eases the nose to the horizon.
  - So letting go at the top of a half loop gives a half roll upright (an **Immelmann**).
  - ASSIST OFF = expert: the jet holds any attitude, even inverted.
- **Barrel roll:** double-tap the stick (or Q / E on PC).
  - One full roll about the nose in 0.5 s, with a 55 m/s sideways kick. 1.2 s cooldown.
  - **During the roll, enemy bolts, flak and kamikazes miss you.** The screen shows "DODGE!" and you get +15 points. Lava and the asteroid still hit.
  - The camera does not spin with the roll, so you see the jet roll.
- **Camera:**
  - The chase cam's "up" follows the canopy (smoothed), plus 85% of the cosmetic bank. Loops and inverted flight turn the world around you. The ground/sky shader already ray-casts with the full camera frame, so it needed no change.
  - In long hard drifts the camera stays within 28 deg of the spot behind the jet and at least 30 m away, and it looks nearer the jet (30 m ahead instead of 60).
- **Sprites in any attitude:** the renderer picks the baked frame from the camera direction in the jet's own frame, then turns the sprite on screen (`DfRender._frame_turn`).
- **Ceiling (300 m) and "TURN BACK"** steer in the jet's own frame, so they also work inverted.
- **Contrails:** two wingtip trails per jet. Player: faint normally, bright on hard pulls / rolls, orange / blue in a charged drift, cyan at top boost. Fighters: white vapor. Kamikazes: orange smoke.
- Explosion puffs are capped at 70 px (low-res pixels) and fade next to the lens; flecks near the camera use a 5 px cap.

### Renderer (SEGA Super Scaler style)
- Mode-7 ground and sky shader that ray-casts with the full camera frame (any roll or pitch). The world map is a data texture.
- Every object is a sprite stack. The repo's slicer carves four-view sheets into `art/stacks/<name>.png`. At load, each strip is baked into 32 headings x several heights, with one outline.
- Objects are projected through the chase camera and scaled with nearest filtering, far to near. 1/3-res viewport.
- Art workflow: README "Dogfight art pipeline"; redraw kit `docs/sprite-redraw.md`.

### T's jet (default player jet)
Concept sheet: `tools/art_src/tlc_jet_concept.png`. Placeholder views: `tlc_jet()` in `tools/make_placeholder_views.py`.
- **Look:** grey helmet nose with ONE red cyclops visor band and yellow hinges; white delta wings; big violet-navy canopy with a light stripe (no shimmer); blue/red/green/yellow emblem on the right wing; swept tail fin with a red tip; metal nozzle.
- **Red shimmer on the cyclops visor:** visor pixels = visor crimsons (hue 335-354 deg, saturation >= 0.45) on the `jet_player` strip. At bake time they get alpha 250/255; `scripts/dogfight/df_units.gdshader` scrolls a stepped red shimmer over them. To keep the effect when you redraw: paint the visor in those crimsons (for example ff1f5a).
- **Boost: 3 stages, by how long you hold BOOST:** 185 / 220 / 255 m/s; flames red-orange / purple / blue blast; FOV 70 / 82 / 90 / 104; motion lines only at top speed.
- **Drift boost:** drift 1.1 s (tier 1, orange sparks) or 2.2 s (tier 2, blue). Let go: 0.9 / 1.4 s of top speed and +12 / +20 meter.
- **Guns** auto-fire at the target in the gun cone (13°). **Lock-on reticle:** red corner brackets.
- **Super laser:** 9 s charge, 32 deg cone, 1,100 m. A burst from the visor, then a thick homing beam. It kills a jet outright or does 80 damage to a ship. Cyan supercharged version: `docs/rings-and-cyan-laser.md`.

### HUD
- On-screen enemies get colored brackets. Off-screen enemies get an arrow that slides around the screen border (camera space). The next ring gets a gold marker.
- Top right: ENEMIES LEFT n. Under the bars on the left: RINGS n/5 · Ns while a course runs.

### Rules
- Flight: arcade, always forward. DRIFT = 2.3x turn and a slower speed; the velocity lags the nose.
- BOOST fills from danger: flying low, drifting, rings, kills, terrain KOs, drift boosts, dodges.
- BOMB sinks flak ships. Enemies: fighters, kamikaze, flak ships (artillery from the ocean), the wave-6 gunship.
- Islands have sand, palms and rock spires; NO houses.
- Cosmetic alt jets come from the Challenges wall (`Challenges.ship_strip()`).
- Controls on PC: WASD/arrows steer, Shift boost, Space drift, Q / E barrel roll, B bomb, L laser.
- Touch: floating stick (double-tap = roll), BOOST, DRIFT, BOMB, LASER.
- Debug run args:
  - `--dogfight --dfgod --dfsim=7`, `--autopilot`, `--dfwave=N`, `--phone`
  - `--dfstage=1|2|3`, `--dfhold`, `--dfahead=300`, `--dflaser`, `--dffire=0.3`, `--dforbit=160`
  - `--dfdemo=kami | volcano | loop | boss | bossko | ko | fog | beach | rings[_kind] | ringsreplay[_kind]`
- Tests: `tests/dogfight_test.gd` (197 checks).

### Fixed (early)
- Every carved stack was flipped front-to-back (`DfSprites.strip_voxels` now maps the nose-down top view to forward = -z).
- Off-screen arrows now use camera space. Views on the four-view sheets are centered vertically.
- AI jets used to be drawn without their pitch. Enemy contrails were too faint (14% opacity).

### Known gaps
- The jet's ground shadow can show as a large disc when you dive near the ground.
- Bottom-edge arrows can sit between the touch buttons.
- Baked jet frames go up to 80 deg elevation. Straight above or below, the nearest frame is used.
- Dogfight frame cost: fixed in slice 16r (a per-frame PNG re-read, plus baked atlases). See `docs/dogfight-performance.md`.

## Card table (built)
- **Blackjack:** Cadavire deals. 4-deck shoe, S17, 3:2, double, split (slice 12), no insurance. Funny business by seated managers.
- **Hold'em:** fixed limit, Cadavire plays. House cut, manager bankrolls, "break the house". Full detail: `docs/holdem.md`.
- **The room:** one first-person 3D room for both games, with a Poker Night-style camera and FAST mode. Full detail: `docs/card-room.md`.
- Tests: `tests/cards_test.gd` (57), `tests/holdem_test.gd` (about 50), `tests/holdem_stress.tscn` (optional, slow).

## Pinball (not built)
From the project brief. Shown as a locked SOON icon on the Play home screen.
