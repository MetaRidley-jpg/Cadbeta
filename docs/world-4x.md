# 4x world (slices 16t →)

T (2026-11-28): "Ask me questions to 4x the map and make this just one quadrant".
T's answers: 3 themed biomes · fights follow you · edge: "Dragon ball arena games have a transparent grid that appears and limits movement without harming you ... it should glide against the wall" · "Speed it up + ring course highways. Warp zone/bonus stages from a hexagon mint green and blue portal with a grey frame. Sealed in a seed that takes a laser to open and spawns randomly. These linear segments will be unique per zone and are more starfox/kiu like" · alien zone: "StarCraft style aliens with Gatling guns in cliffs, and cannons in valleys as well as flying ones kamikaze and swarms. Instead of volcano the queen hatches and shoots 3 rotating red pink lasers that sweep horizontally out of 3 mouths in a triangle spinning shape. 3 headed hydra plant aliens" · speed: everything +30% · bonus reward: Marrow · art: placeholders by Claude, T redraws · zones 3 + 4: decide later · "Start now optimize tokens".

## Plan
| Slice | Contents | State |
|---|---|---|
| 16t | 4600 m square arena (4 quadrants), glide wall + grid, scenery culling, +30% tempo, fights follow you | ✅ |
| 16u | Ring course highways between zones | ✅ |
| 16v | Alien hive zone (zone 1, NE): terrain, hydra plants, gatling cliffs, valley cannons, swarms | ✅ |
| 16w | Queen boss: hatches, 3 mouths, 3 sweeping red-pink lasers, spinning triangle | ✅ |
| 16x | Seed (laser opens it) → hex portal (mint/blue, grey frame) → on-rails bonus stage engine + first stage, Marrow reward | |
| later | Bonus stage per zone; zones 3 + 4. T (2026-11-28): the domed saucer ship (`art/ref/t_dome_sketch.jpg`) is for **zone 3**. It lands on a cliff and shoots a FLAT STAIRWAY down out of the ship on landing (not a ladder) | |

## Slice 16t (built)
- **Arena:** `DfWorld.ARENA_MIN/MAX` = (-1150,-1150)..(3450,3450). Zone 0 = the old islands (same coordinates), 1 = NE, 2 = SW, 3 = SE (`zone_of`, `ZONE_NAMES`). Each new zone has up to 5 placeholder islands. Map texture 1280 px x 4 m.
- **Glide wall:** `DfGame._glide_wall`: the jet stops `WALL_GAP` = 40 m inside the drawn grid, the part of its velocity into the wall is removed, the nose turns along the wall (`WALL_TURN` 5 rad/s). No damage, no speed loss. Grid: mint pixel lines every 30 m on the wall plane, a 260 m patch, shown from 170 m (`WALL_SHOW`). The 40 m gap exists because a camera ON the wall saw the grid edge-on (one line).
- **+30% tempo:** `DfPlane.SPEED_K` = 1.3 scales speeds AND turn/pitch rates (so every turn radius, ring course and launch keeps its size), accel, grip, bullets, and divides launch durations (same throw length). Demo speeds scale too.
- **Fights follow you:** enemies and ships spawn near the player, clamped inside the arena.
- **Culling:** `DfWorld.cells` (500 m grid). Render queues only cells inside the fog and not behind the camera; `ground_y` checks only the 3x3 cells round a point. Measured: scenery 0.4-1.2 ms with 4x the objects (old map: ~0.6 ms).
- Flag: `--dfyaw=DEG` (heading, for wall / zone shots).
- Tests: dogfight 261 (+30): arena + zones, +30% / same radius, ground_y grid = brute force, wall holds / no damage / keeps speed / glides, spawns near you in the far quadrant; all 7 ring courses still flyable at the new tempo.

## Risks (hostile audit)
- **The new zones are empty placeholder islands.** Until 16u-16v, the map is 4x bigger with no more reasons to explore.
- **No minimap.** Edge arrows only. On a 4.6 km map you can get lost; a zone name / compass is cheap and likely needed.
- **The asteroid, volcano and boss still live in zone 0.** Big events always pull you back to the islands quadrant.
- **The wall slide can be used to escape:** an enemy behind you while you glide along the wall cannot cut the corner either; check that AI at the wall does not stick.

## Slice 16v (built)
See `docs/build-log.md` 16v. Knobs: `DfGame.GROUND` (hp, range, fire interval, burst, points), `GATLING_GAP`, `HYDRA_DMG`, `DRONE_DMG`, `SWARM_SIZE`, `UNIT_ARROW_RANGE/MAX`; `DfWorld` cliff counts/heights.
Risks: wave titles still name the islands' weather ("THE VOLCANO WAKES") in the hive; the hive units are fixed for the whole match (no respawn), so a cleared hive goes quiet; units are ~15 m, small at range.

## Slice 16w (built)
Knobs: `DfGame.QUEEN_*` (trigger kills / distance, rise, altitude, bob, spin, mouth offset, charge / fire / rest times, beam length / width / damage / tick, score). Risks: she never moves off the mound (a hover turret); the beam plane is easy to read from above but hard to judge from the same height; one Queen per match, no reward beyond score yet (Marrow comes with 16x).
