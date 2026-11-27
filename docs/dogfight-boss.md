# Dogfight: QUAD GUNSHIP boss + lights pierce fog (slices 16, 16b, 16d, 2026-11-26)

## Requests
- T: "Quad helicopter boss boss meter in middle of screen, along with his charged meter, shoots a blue laser out of a bottom mounted cannon bigger than yours and the only way to dodge is top speed hard turn or a well tuned drift boost".
- Mid-build: "Note that lights should pierce fog".
- After slice 16: "Yes everything you said but show a player ko by Enemy laser with replay after". "Everything you said" = the audit fixes: track speed 230, phase 2 with rotor weak spots, near-miss camera/slow-mo, fix the too-tight timing (slice 16b).
- After slice 16c: "That replay suck the beam doesn't bend and the explosion is red" (slice 16d).

## The boss
- **When:** wave 6, "WAVE 6 · BOSS: QUAD GUNSHIP", + 2 fighters + 2 kamikazes. (Weather is random per wave since slice 16k; it used to be night.)
- **Body:** a 70 m quad-rotor gunship (`DfPlane.BOSS_SPAN`). 1400 hull, hit radius 40 m measured from `hit_center()` (the stack's origin is its bottom slice). Kind `"boss"`.
  - Art: `art/stacks/gunship.png` (23 slices), from `gunship()` in `tools/make_placeholder_views.py`: deep armoured hull with a hazard stripe, wrap-round blue cockpit, roof engine humps, tall red fin, 4 girder arms, 4 ducted rotors, a hanging cannon pod with a cyan muzzle. Rotor / muzzle positions are constants in `df_game.gd` (`boss_hub`, `BOSS_MUZZLE`): moving them in art means moving them in code.
  - Live-drawn: spinning rotor blades + blur discs, a cannon glow that grows with charge, nav beacons. A dead rotor is a dark, still, broken disc with smoke and sparks.
- **Movement (`DfGame._boss_step`):** a slow circle, 650 m out (phase 2: 430 m, faster), 235 m up. Nose on you. Tilts with motion and sags toward dead rotors.
- **HUD (`_draw_boss_meters`):** name (phase 2: "QUAD GUNSHIP · ENRAGED", pulsing red), red hull bar with a tick at 55%, 4 rotor pips (cyan / red X), blue CANNON bar with a tick at the lock point. Labels CANNON / LOCK! / FIRING.

## The cannon
| Phase | Phase 1 | Phase 2 | What happens |
|---|---|---|---|
| charge | 8 s | 6 s | muzzle glow grows |
| lock | 2.8 s before the shot (both phases) | | "CANNON LOCK! / Top speed. Hard turn.", cyan line + ring on your LEAD point, lag ~1/8 s |
| fire | 2.0 s | 2.4 s | blue bending beam; the aim chases your lead point at 240 m/s; 55 hull/s while in it |
| cool | 1.2 s | 1.2 s | the cut-off tail flies on and lands |

### The beam bends (slice 16d)
- The beam is light that FLIES out of the cannon at 2,200 m/s (`BOSS_BEAM_SPEED`). Each step the cannon emits a "part" along its current aim (`_beam_emit`); a part flies along its own direction and stops where it hits the ground. The beam is the line through the parts (`boss_beam_pts`), so when the gunship sweeps after you, the far end lags and the beam bows like a hose. Measured: **~220 m of bow** over its full length while chasing a crossing jet.
- When the shot ends, the tail detaches and flies on until every part has landed. A flying head is a glowing ball.
- The hit test uses the same bent line (`boss_beam_dist`), radius 10 m + your 7 m.
- **The gunner leads you** by the light's flight time during the lock and the shot. Track speed **240 m/s**. Measured over a full 2 s shot: cruise 125 m/s dead; boost 2 (220) caught, half a hull; top speed 255 escapes, ~16 m clear.
- The human-timing drift dodge (react 0.3 s after the lock, full tier-2 drift, let go 0.3 s early) gives CLOSE DODGE +350 in the demo.
- A beam that passes right by the camera is clipped at the near plane.
- **Near miss:** within 30 m → 0.45 s slow motion (x0.35) + a whoosh; "CLOSE DODGE!" +350. Plain dodge "DODGED!" +200. +15 boost either way.
- **Camera glance:** while the beam is within ~150 m, the camera looks up to 35% toward its nearest point.

## Rotors + phase 2
- Each rotor: 150. Your auto-guns aim at the point nearest your nose (a live hub or the hull). A bolt within 12 m of a live hub: x2 to that rotor, x1.5 to the hull. Elsewhere x1. Far-side rotors are shielded by the hull.
- Super laser: 260 to the hull and 100 to the rotor nearest you. Cyan laser (16n): 420 to the hull + 50 to every live rotor per chain hit.
- ROTOR DOWN: blast, +300, -150 hull, it sags and smokes from that corner.
- **PHASE 2** at 55% hull or 2 rotors down: "PHASE 2 / It's enraged: faster cannon, closer orbit", rumble, Cadavire `df_boss_phase2`.

## Deaths and replays
- **Boss dies:** "BOSS DOWN!" +2500, chained blasts, wreckage, `Challenges.bump("df_boss")`, `df_boss_down`, then the KO replay.
- **You die to the beam:** a **blue** blast (`art/fx/explosion_beam.png`, `DfFx.beam_explosion`), "LASERED", `df_beam_ko`, KO replay "LASERED BY THE QUAD GUNSHIP".
- The replay records the gunship and its cannon state every step, including the beam parts.

## Lights pierce fog
- Solid things fade out at `fog_end`. Light sources keep full strength to `light_end` = 3x fog (min 3.2 km): explosions, laser rings, tracers, flak, lava, sparks, burning debris trails, the boss beam, cannon glow, nav beacons, the koi glow layer, cyan chain arcs / strikes.
- In fog, lights get a scatter halo (`DfRender._halo`); the beam gets a wide blue haze.
- The gunship's beacons find it in fog; beacons on dead rotors go out.

## Demos
- `--dfwave=6 --dfgod --dfdemo=boss`: approach → CLOSE DODGE → rotor attack runs → ROTOR DOWN x2 → PHASE 2 → super laser → BOSS DOWN → KO replay.
- `--dfwave=6 --dfdemo=bossko`: a FAILED dodge (capped at 215 m/s) → bending beam catches it → blue blast → LASERED → KO replay.
- `--dfwave=3 --dfgod --dfdemo=fog`: storm fog, the boss 1.4 km out, explosions at 0.4 / 0.9 / 1.6 km.
- GIFs / videos in `tools/demos/` (git-ignored).

## Bugs found while building (fixed)
- The demo cleared the enemy list after the wave spawned the boss (ghost meters).
- Wreckage used the asteroid rock sprite before it existed → crash (`DfWeather.rock_sprites()` bakes on first use).
- `bake_art` scales art to the fallback's size: v1 came out jet-sized. v1 art (12 slices) was a flat sliver; v2 is 23.
- Origin = bottom slice: muzzle, rotor offsets and the hit sphere were wrong.
- The beam called the normal hit function every frame (sound spam).
- Rotor hits almost never counted; now measured along the bolt's whole step.
- 16d: the light delay + lead first let boost 2 escape; fixed by leading during the lock too and track 240.
- **Correction:** a "kill line mid-fight" bug reported in slice 16 was a contact-sheet misread. Check dialogue on full frames only.

## Hostile audit (risks)
1. **The bend is strongest far from you.** Near your jet the beam is still almost straight. A whip at your jet needs slower light (~1,400 m/s) and retuned tracking.
2. **The dodge is a strict skill check.** Knobs: `BOSS_WARN` (2.8 s), `BOSS_TRACK` (240), `BOSS_BEAM_R` (10 m), `BOSS_BEAM_SPEED` (2200).
3. **Phase 2 barely shows in the demo.**
4. **The boss is still a turret.** It never dives, rams or calls escorts.
5. **Fog lights change gameplay:** enemy tracers read from 3 km in fog.
6. A banked cyan supercharge (it never expires) does 420 + rotor damage per hop to the boss.
