# Ring courses + cyan chain laser (slices 16n-16q, 16s; 2026-11-26/28)

T (16n): "Change the rings to be bigger and twinkle and push around a scripted path. Make 3-4 different variations. If this is completed your laser powers up to big and cyan and your ship sparks. The cyan laser can chain multiple enemies possibly combo all of them. The enemies will spark blue instead of red if they will chain. When the cyan laser makes contact with enemy ship thunder also strikes the ship".
T (16o): "The loops should be skinnier and larger and launch you to the next one and change your yaw".
T (16p): picked option 3 of the launch audit: keep the exact launches, make courses rarer in later waves ("3 later I'm gonna test").
T (16q): "Wrap up and make loops appear in replays then we migrate on mobile to Claude code".
T (16s): "Rings can spawn out of bounds" / "Also stop it from aiming into the ground" / "Also create potential paths for figure 8, big loop and helix shapes".

## Ring courses (`scripts/dogfight/df_rings.gd`, class `DfRings`)
- Replaces the 8 static scattered hoops. One course at a time, 5 rings, spawned ~650 m ahead of you.
- **Skinny + large (16o):** a thin ring sprite (`df_render._ring_model`: radius 14 px, ~1.4 px band, hot yellow top / orange bottom, 4 white studs), x1.5 → 42 m. Hit radius 42 m. Ring spacing 110 m.
- **Twinkle:** 4-point star glints ride round each rim and blink; the NEXT ring is gold, brighter, with 8 bigger glints; other rings orange at 60% opacity. A passed ring bursts into 12 gold sparks.
- **Scripted paths (4 variations), sideways speeds ~15-20 m/s:**
  - SLALOM: the line snakes left/right (±34 m).
  - CORKSCREW: each ring circles the course line (30 m), the line twists.
  - LOOP WHEEL: the rings ride a vertical wheel (R 95 m) turning slowly.
  - SKY STAIRS: rings climb 20 m per step and slide back and forth (±32 m).
- **Rules:** rings count only in order (next = gold, HUD marker / edge arrow). The 25 s timer starts at ring 1; out of time = "RINGS RESET". Each ring: +30 boost, +25 speed, +50 points. A course you fly 2.6 km away from (not started) moves to you.
- **Gap between courses (16p):** `DfGame.course_gap(wave)`: 6 s in waves 1-3, then +7 s per wave (4: 13 s, 5: 20 s, 6 boss: 27 s, 7: 34 s), max 40 s. Set on every wave start (`rings.respawn`).
- **Placement:** the lowest of 8 headings over ground AND sea stacks / spires; the course top stays under 275 m (the game turns you back at 300 m).
- HUD: "RINGS n/N · Ns" (N = the course's ring count) (gold; red under 6 s), top right beside the enemies-left counter.

## Slice 16s: bounds, ground-safe launches, 3 new shapes
- **Out of bounds (fixed):** every candidate course is moved so its whole footprint (`DfRings.box(kind)`, ring centres + sway) is within `EDGE` = 1040 m of the arena centre (arena 1150 m). 4 of 12 candidate headings point back to the middle; a candidate that had to move far scores worse. Before: courses spawned at the edge, heading out, reached 2,422 m.
- **Into the ground (fixed):** the last-ring launch threw you along your nose; the loop wheel's last ring points down, so it threw you at the sea at 230 m/s. Now a down-pointing last launch is flattened to level. Every launch goes through `DfGame.safe_launch_dir`: the whole throw + 1.2 s of pull-out (~370 m) must stay `LAUNCH_CLEAR` = 35 m above ground and spire tops, or the aim tips up 5° at a time. A launch with room keeps its exact aim.
- **New shapes** (`DfRings.KINDS` now 7; ring count per kind: `count_for`):
  - FIGURE 8: 8 rings on a flat lemniscate (lobes ±230 m along, ±110 m wide), off the crossing point; it sways side to side.
  - BIG LOOP: 6 rings on a round 140 m loop **tilted 50° from vertical** (an oblique loop). Rings cover the climb, the top (inverted) and half way down; the wheel rocks ±9°.
  - HELIX: 7 rings on a climbing spiral turn round a 110 m column (55° and +18 m per ring, 330° in all); the whole spiral turns slowly.
- **Why the big loop leans:** under the 300 m ceiling a round vertical loop can be at most ~95 m radius = the existing LOOP WHEEL. Tried first: a flat oval (400 x 170 m). Its ends were 36 m hairpins (the jet needs ~110 m at cruise, ~180 m after a launch); the test pilot dove into the sea. Then a full-turn wheel: it carried the last ring down to 50 m; same crash. Both rejected by the flyability test.
- **Too tall for the spot:** a course that cannot fit between the ground (+35 m) and the ceiling at the chosen spot becomes a SLALOM or FIGURE 8.
- **Flyability test (all 7 kinds):** the demo pilot (95 m/s cap, no boost, plain steer-to-next-ring) must clear each course in 40 s without a crash.
- Demos: `--dfdemo=rings_figure8`, `rings_bigloop`, `rings_helix`.

## Ring launch (16o)
- `DfPlane.launch(dir, time, min_speed)`. On a ring pass the game predicts where the NEXT ring will be when you arrive (3-pass lead solve at 210 m/s) and throws the jet at it: for 0.55 s the jet flies along that line at ≥ 210 m/s while its nose swings onto it (basis slerp, rate 14/s: ~90% in 0.15 s). Steering still applies.
- The last ring throws you straight ahead (0.3 s, 230 m/s), into the supercharge.
- Measured: after ring 1, the launches alone carry you through rings 2-5 on all 4 courses (0.1-4 m from centre).
- **Crossing fix:** the last jet position is tested against the ring's last pose (`ppos`, `pnormal`) and the current position against the current pose. Before, a moving ring could slide past a jet without the pass counting.

## Course clear → supercharged laser
- Laser fully charged and cyan; +500; "COURSE CLEAR! / LASER SUPERCHARGED · CYAN CHAIN"; power_up sound; Cadavire `df_supercharge` (caveman: "BLUE ZAP! ZAP ALL BIRDS!").
- Until it fires: cyan sparks + glow on the jet; laser button cyan ("CYAN", "CHAIN!" when locked). Spent by the next laser shot (no time-out).

## Cyan shot
- Big cyan beam (1.7x width) from the cyclops visor, cyan visor burst.
- **Chain:** after the first hit it hops every 0.13 s to the nearest live enemy within **380 m** of the last one: jets, kamikazes, ships, the boss. **No cap.** Enemies that die on the way are skipped.
- **Preview:** while armed, every enemy the chain would reach shows a cyan reticle with blue sparks (normal laser: red, one target).
- **Each cyan hit:** lightning from the sky, blue blast, thunder, flash, shake. Jets KO'd; gunship hull 420 + 50 to every live rotor; ships 240.
- **Combo:** each hop 120 x hop number; 2+ hits "CHAIN xN!".

## Replays (16q)
- Each replay frame stores `DfRings.snapshot()`: kind, origin, axis, side, course clock `t`, `next`, `active`, `elapsed`, per-ring passed flags (`df_replay.gd`, also in the saved live state).
- Playback calls `rings.restore(snap, at)`: the course is rebuilt from the snapshot; when two neighbouring frames hold the same course (same kind + origin), the course clock is interpolated, so the rings keep moving smoothly in slow motion. Passed rings vanish, the next one is gold, exactly as at that moment.
- When the replay ends, the live course comes back as it was.
- Cyan chain arcs + strikes were already recorded (16n).
- Before 16q the replay drew the LIVE course, frozen at replay start: missing if it was cleared in the KO window, in the wrong place if it had moved.
- Demo: `--dfdemo=ringsreplay` (or `ringsreplay_slalom|corkscrew|loop|stairs`): the pilot flies the course, and a replay starts right after ring 4, so rings 4-5 show in the footage.
- Tests (dogfight_test 197): the replay frame holds the recorded course kind and place; during playback the ring positions match the recording and move; after the replay the live course is restored.

## Demo + tests
- `--dfdemo=rings` (slalom) or `rings_slalom|corkscrew|loop|stairs`: a scripted pilot flies the course, gets supercharged, then jets appear and the cyan shot chains them.
- `dogfight_test` ring checks: 4 variations move and stay above the ground; in-order counting; course done; time-out reset; supercharge; chain preview covers 4 lined-up jets but not one 1.5 km away; the shot KOs all 4 with 4 strikes and 3+ arcs; combo scores; rings ≥ 40 m; launch nose < 18° after 0.3 s; launch speed ≥ 200 m/s; launch carries you through the next ring; course gap by wave; replay playback (16q).
- GIFs: `demo_cyan_chain.gif`, `demo_ring_launch.gif` (git-ignored, `tools/demos/`).

## Bugs found while recording (fixed)
1. First paths moved ~50 m/s sideways; slowed to ~15-20 m/s.
2. Courses were built through sea stacks / above the ceiling; now spires count and the lowest heading wins.
3. The ring-pickup puff drew a box at the camera; now small flecks with a 5 px cap (same for the supercharge burst).
4. Demo jets spawned inside the terrain.
5. (16o) Moving rings slid past a jet without the pass counting (crossing fix).
6. (16q) Rings demo pilot crashed into an island after the chain; it now holds altitude.

## Risks (hostile audit)
1. **With launches, a course is decided at ring 1.** T's call (16p): keep it; courses get rarer later. Waiting on T's phone test.
2. A cyan shot into a full wave 6+ can delete the whole wave in ~1 s.
3. The chain ignores line of sight (hops through islands).
4. Ships count as chain targets. If T meant only jets, remove ships from `_chain_from`.
5. The supercharge never expires; a player can bank it for the boss.
6. The thin band can break into pixels at long range; the studs and glints carry it. Check on the phone.
7. The replay director does not score rings yet; a ring pass is not a "cool play" to it.
