# Dogfight cinematics: asteroid show + KO replay (2026-11-26, slices 14d, 15, 15b, 16b-16h, 16k, 16q)

## Asteroid "go nuts" pass (slice 14d)
T asked for the asteroid to be "Bigger and should be in view longer" (slice 14c, see `docs/dogfight-status.md`). Then I listed three weak spots (in real play nothing makes you look; the rock covers enemies; the impact is a white-out), and T said "Go nuts".
- **Warning** (asteroid wave start): "INCOMING! / Look up"; the camera glances at the rock for 2.4 s (max 75% of the way). You keep control of the jet (`ast_glance_t`).
- **Approach:** the scene glows orange as the rock nears; in the last 5 s a red pulse and a beep each second.
- **Impact** (`_on_impact`): a short flash; 0.9 s of slow motion; a column of 7 fire blasts; a big shake and `impact_rumble`.
- **Shockwave:** a ring racing out over the water at 850 m/s to 2.8 km; it shoves jets, no damage; "SHOCKWAVE!" when it reaches you.
- **Debris:** 34 burning rocks on arcs; a rock that hits you does 9 (a barrel roll dodges it).
- **Video:** `tools/demos/video_asteroid_with_sound.mp4`. GIF: `demo_asteroid.gif`.

## KO replay
History of T's asks:
- 15: "I want a cinematic replay on ko like a fighting game and bars on top and bottom of the screen to make it cinematic".
- 15b: "Wider shots".
- 16b: "show a player ko by Enemy laser with replay after".
- 16c: "Also still not the big cinematic wide shots I want in ko screens". I asked which "wide"; T picked **far camera + widescreen strip**.
- 16d: "That replay suck the beam doesn't bend and the explosion is red" (`docs/dogfight-boss.md`).
- 16e: "Clouds need to be obscured or translucent in replays".
- 16f: "30% more zoomed in on average in replays".
- 16g: "It should be barely close enough to make out the planes, combine with randomly picked angles including side wing views overhead, turning into frame, from the front of the target plane, etc".
- 16h: "Make a scoring system for the replay shots with events and multiple planes in the shot worth more and repeating shots takes away points. Manager budget for cool plays basically".
- 16k: "The mobile replays can remove the cinematic bars and just be a replay, pc will still have them".
- 16q: "make loops appear in replays".

**Lesson:** the renderer's FOV is vertical. On a portrait screen a "wide" 78° shot was only ~60° across. The replay gives a HORIZONTAL fov and the game converts it.

**What counts as a KO:** the kill that clears a wave (incl. the boss kill), and your own crash (incl. being lasered by the gunship).

**Flow:**
1. **Live KO:** "K.O." / "WRECKED" / "LASERED", slow motion, thin bars slide in (PC only).
2. 0.9 s later (1.4 s for a crash) the game freezes and the replay plays: 2 s before the KO to 1 s after (0.8x, then 0.32x near the KO). About 6 s.
3. **PC: widescreen strip (16c):** a true 2.39:1 movie frame, gold rules, "REPLAY" in the top bar, a film caption in the bottom bar ("K.O. · WAVE N CLEAR" / "BOSS DOWN · QUAD GUNSHIP" / "LASERED BY THE QUAD GUNSHIP" / "WRECKED · WAVE N").
   **Phones (16k, `Game.is_phone()`):** no bars, no caption; the replay is full screen with a yellow outlined REPLAY tag; the director scores shots on the full frame (`DfReplay.full_frame`). Same horizontal FOV, so phones see more sky and ground above and below.
4. **Three shots per replay** (cuts at 1.1 s and 0.12 s before the KO), picked by the **director** (16h).

### Shot library (16g)
| Shot | Early | KO | Cost | What it is |
|---|---|---|---|---|
| side | yes | yes | 1 | wing-on side view, tracking the target across the frame |
| chase | yes | | 1 | over the attacker's shoulder, past it to the target |
| front | yes | yes | 2 | head-on from the target's nose, the attacker behind it |
| orbit | yes | | 2 | a slow ~70° arc round the target |
| low | | yes | 2 | under the KO, looking up at the blast against the sky, pushing in |
| overhead | yes | yes | 3 | straight down, the target pointing up the frame |
| into_frame | yes | yes | 3 | a FIXED camera where the target will be (read from the replay buffer): it flies / turns into frame; as the KO shot it is aimed at the KO point |

- **Distance (16g):** every shot frames a 9 m jet at 9 or 11.5 px in the 1/3-res view (~27-35 px on screen, ~150-230 m away).

### The director (16h, `DfReplay._make_plan_scored` / `score_shot`)
- **Test flights:** for each slot (2 early + 1 KO) it flies every candidate (shot type × 2 framings: 34 candidates) through the recorded footage at 6 sample times, projects what is in the frame, and scores it. Per-sample points are averaged × 10:

| In frame | Points |
|---|---|
| the target jet | +6 (not in frame: -8) |
| each other jet (≥ 3 px) | +4 (the gunship 6) |
| 2+ jets together | +3 |
| an explosion | +5 (laser / beam kill blasts +8) |
| your super laser | +6 |
| the gunship's beam | +6 |
| bolts | +0.5 each, max +3 |
| the KO point (KO shot, from the KO on) | +10 |
| looking at land (scenery) | +1 |

- **Repeats cost points:** the same type twice in one replay -30 (first + last shot -15); every use of that type in the last 9 shots (3 replays) -8, the last replay's -16.
- **Budget ("manager budget for cool plays"):** each shot type costs 1-3; a replay gets **6**. The director buys the highest-scoring 3-shot plan it can afford. A ±3 random tie-break keeps it from being robotic.
- **Debug readout:** debug builds show the pick in the top bar: "DIRECTOR 3/3 INTO_FRAME 412 (plan 693, cost 6/6)".
- **Measured:** the same side shot scores 70 with the target alone, 140 with a wingman, 190 with an explosion too. Over 12 replays the history rotated through all 7 types. Planning 5.8 ms on desktop on light footage.

### What a replay shows
- Jets (ghosts), ships, bolts, fx, debris, the shockwave, lasers, the visor burst, the muzzle flash, the gunship + its cannon state incl. the bent beam parts, the cyan chain arcs + lightning strikes (16n), and **the ring course (16q)**: `DfRings.snapshot()` per frame (kind, origin, axis, course clock, next, passed flags), rebuilt on playback with the course clock interpolated, so the rings sit where they were, moving, the next one gold. Before 16q the replay drew the live course frozen at replay start (missing if cleared, wrong place if moved). The live course comes back after the replay.
- See-through: clouds 45% (60% behind the action, 12% where they cover it); sea stacks / the volcano in front of the action 30%. No cloud white-out. Live play unchanged.
- Glow trails + markers (cyan you, red victim) only when a jet is smaller than ~6 px.

**Skip:** a tap, a click or any key. **Afterwards:** the live match comes back exactly; after a crash, the match ends.

**How it works** (`scripts/dogfight/df_replay.gd`): a 3.4 s ring buffer of snapshots; playback through ghost jets; started only from `_process`. The shot math is one pure function (`_shot_cam`) used by both playback and the director's test flights.

**Settings / debug:** Play → Options **KO REPLAY: ON/OFF** (`Game.df_replays`). `--dfcrashat=7`. Demos with replays: `--dfdemo=ko`, `boss`, `bossko`, `rings[_kind]`, `ringsreplay[_kind]` (a replay right after ring 4).

**Media:** `tools/demos/director_wave_ko.gif`, `director_beam_ko.gif`, `director_boss_down.gif`.

**Tests:** replay checks (buffer, freeze, ghosts, bars, restore, OFF), cloud rule, stack ghosting, every shot type frames the target sanely, random plans; director scoring / history / budget; phone full frame vs PC strip; the ring course plays back (recorded kind + place, moving, live course restored).

**Risks / open:**
- The weights are my first guess; T should tune them (constants at the top of `df_replay.gd`).
- The director cannot know a shot is "pretty" beyond the +1 land bonus; rings are not scored yet.
- Planning cost on a busy wave on a phone could be a visible hitch (it happens behind the freeze).
- The history is per session (static), not saved.
- Snapshots deep-copy fx and beam parts each step. Sounds are not replayed (only the KO blast). Contrails restart in the replay.
