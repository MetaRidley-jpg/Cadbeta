# Dogfight: status review + sky koi + asteroid (2026-11-25/26, slices 14, 14b, 14c)

> Some numbers here are from slice 14. Current state: `docs/build-log.md`, `docs/todo.md`.

## Asteroid event (slice 14c, 2026-11-26)
T: "Can I see asteroid event?". Then, after the first video: "Bigger and should be in view longer".
- **When:** wave 5 ("WAVE 5 · IMPACT"), on the main island. The crater has a radius of 300 m (`DfGame.ASTEROID_RADIUS`). Enemies and ships inside it die. You take damage near it, and a barrel roll does not dodge it.
- **Bigger:** the rock is drawn at 4x (`DfRender.ASTEROID_SCALE`), about 300 m across. It ignores fog, so you see it from far away.
- **In view longer:** an 18 s countdown (`DfGame.ASTEROID_WARN`). The rock starts 4.2 km out and 2.3 km up, on the far side of the island, and comes in at an angle across the view; it speeds up as it falls.
- **Burning streak:** 3.6 km long from the first second; white-hot core → yellow → orange → red → grey smoke, plus a glow pass. Ignores fog.
- Later (14d, `docs/dogfight-cinematics.md`): camera glance, shockwave, debris, slow-mo.
- **Demo:** `--dfwave=5 --dfgod --dfdemo=asteroid`. GIF `tools/demos/demo_asteroid.gif`.
- **Risks:** a player busy with wave 5 can miss most of the show; the rock fills the top of the screen in the last 2 s.

## Sky koi
T, in order:
1. "Can you add giant colored koi fish in the sky above the clouds but visible, to add to asthetic".
2. "Multicolored koi, translucent effect wavering on them semi translucent, reacts to the effects and swims away from explosions and weather".
3. (2026-11-26) T sent a reference image (glowing hologram koi with feathery betta fins, over a neon street with paper lanterns): "More like this".

**Code:** `scripts/dogfight/df_koi.gd` (data, swimming, reactions, shape, colors); `DfRender._draw_koi_layer` / `_draw_holo_koi` / `_fin_fan` / `_strand` / `koi_dark` (drawing on two layers behind the jets and clouds: `_koi_body` normal blend = colored glass, `_koi_glow` ADDITIVE = light). Scenery only.

**Where:** 6 koi, 240-380 m long (a jet is 9 m), slow circles 345-470 m up (above the clouds and the 300 m ceiling). A calm lap takes 3-6 min.

**Look (slice 14b):** chunky koi shape; glass layer with one smooth hue melting into the fin hue, soft back markings, translucent fins, day outline; light layer with an edge glow, fresnel rim, twinkling scale chevrons, scan bands, glowing eye rings, whiskers, fins as fans of wavy glowing rays (13-ray forked tail, 6-ray pectorals, 4-ray pelvics, dorsal crest), sparkles and a rare hologram glitch. Day: the glass carries the color; night / storm: neon. Palettes: cyan ghost, gold leaf, gold + ice, sakura, violet + pink, jade, rainbow. LOD below 22 px and 70 px.

**Reactions (`DfKoi.step`):** blasts scare koi within 650 m x power (laser kill 2.6, normal 0.6-2): they bolt at up to 7x speed, pushed away and up (+140 m), calm over ~4 s. Lightning and the asteroid path / impact scare them too. Weather height: rain +50 m, eruption +110 m (clear of the volcano), impact +180 m, storm +230 m.

**Demos:** `--dfdemo=koi` (day), `--dfwave=6 --dfdemo=koi` (night). GIFs `demo_holo_koi_day.gif`, `demo_holo_koi_night.gif`.

**Risks:** 1/3-res with no real bloom, so it is a pixel-art take on the reference; additive light cannot glow on a bright day sky; koi can sit under the HUD; code-drawn (T cannot paint over it); paper lanterns / confetti from the reference are not built (asked T).

## How the dogfight is coming (status at slice 14; see build-log for later)
| Area | State then |
|---|---|
| Systems (flight, weapons, waves, weather, HUD) | Built and tested |
| Content (enemy types, waves, bosses, goals) | Thin (the gunship boss came in slice 16) |
| Art | All placeholder (redraw kit: `docs/sprite-redraw.md`) |
| Audio | Placeholder sounds, no music |
| Tested on a real phone | Since slice 16i: the iPhone web build |
| Played by a human | T on the iPhone since 2026-11-26 |

**Biggest risks (still open):**
1. Frame cost on the phone (~16 ms of units drawing on desktop; draw calls are only 100-420, so it is CPU / script work).
2. Enemy AI is the weakest part: fighters chase, kamikazes beeline, nobody evades, nobody flies in formation, nobody loops.
3. Shallow goal: "survive the waves" for bones only; needs dogfight-only rewards.
4. Cadavire is barely in it (a cockpit cut-in on the laser / drift boost / KO).
5. Portrait for a flight game narrows the side view.
