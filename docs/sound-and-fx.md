# Sound + effects (slices 13b / 13c, 2026-11-25; additions to 16n)

T's direction, in order:
- "Enemies aren't leaving contrails". I found the trails were drawn at 14% opacity.
- I offered weather-aware kamikaze smoke and a placeholder explosion sprite. T: "Yes those are correct make a place holder then work on the game for 15 minutes and get back to me". I used the 15 minutes for placeholder sound effects and videos with sound.
- Mid-block: "Big laser beam explosions should be bigger and redder and have more debree".

## Contrails
- Player: 0.9 s. Faint in normal flight; bright on hard pulls and rolls; orange/blue in a charged drift; cyan at top boost.
- Fighters: white vapor, 55% opacity, 1.4 s.
- Kamikazes: thick smoke, 70% opacity, 1.4 s, wider. **The color follows the weather:** dark (3a2f38) when the sky is bright (morning, rain), pale ash (f1e4d2) when it is dark (storm, eruption, impact, night). The rule: sky_mid luminance above 0.42 means dark smoke.
- Code: `DfRender._step_trails` / `_queue_trails`.

## Explosions (placeholders, T redraws)
- `art/fx/explosion.png`: 8 square frames of 48 px in one row. Frame 0 is the flash, 1-3 the fireball, 4 the fireball turning to smoke, and 5-7 the smoke tearing apart in clumps with embers. Used for normal kills, crashes, bombs and ships.
- `art/fx/explosion_laser.png`: the same layout in the beam's crimsons.
- `art/fx/explosion_beam.png`: the gunship beam / cyan laser blue blast (slice 16d).
- All made by `tools/make_fx_art.py` (it also writes x4 previews). A redrawn sheet with the same layout works without code changes. Square frames in one row are required; any frame size works.
- **Laser kill** (`DfFx.laser_explosion`): a 3.8-size crimson blast (~1.7x a normal kill), a second pop 0.14 s later offset 9 m, a red + pink shock ring, 24 burning fragments and 14 dark wreck chunks arcing down under gravity.
- Normal explosions no longer use big square smoke puffs. Debris is capped at 4 px. Puffs cap at 70 px and fade within 22 m of the camera. **Puffs spawned at the jet (ring pickups, the supercharge) use a 5 px cap**: one big puff right at the camera drew a box over the jet (slice 16n).

## Sound (placeholders, T or a sound designer replaces them)
- Autoload `Sfx` (`scripts/sfx.gd`): `Sfx.play(name, db, pitch_var)`, `Sfx.loop(name, on, db, pitch)`.
  - 14 voices, max 3 copies of one sound at once, random pitch spread.
  - A hard limiter on the master bus (ceiling -1 dB).
  - Silent in headless runs (tests).
- Retro sounds made by `tools/make_sfx.py` (square waves + filtered noise, bit-crushed) into `audio/sfx/*.wav`. **Drop a real `.ogg` or `.wav` with the same name to replace one.** `.ogg` wins over `.wav`. New sounds are appended at the END of the script so the seeded output of the old ones does not change (checked by md5 in slice 16n).
- Where they play:
  - Dogfight: gun; enemy_gun (within 500 m); laser_charge; laser_fire; explosion; explosion_big; boost_loop; drift_boost (also the ring launch, softer); roll; dodge; hoop (ring pass); hit; bomb_drop; warning; **zap** (cyan chain hop), **thunder** (cyan lightning strike), **power_up** (course clear) — slice 16n.
  - Cards: card, chips, win, lose.
  - Idle: buy / tap; crunch (taste test).
- Setting: **Fold page > SETTINGS > SOUND: ON/OFF**, saved in `Game.sfx_on`.
- Test: the dogfight test checks that the sounds and explosion sheets load.

## Videos with sound
- Movie Maker writes audio when the output ends in `.avi`. Convert with ffmpeg (x264 veryfast, CRF 24, AAC 96k).
- In `tools/demos/` (git-ignored): `video_volcano_with_sound.mp4`, `video_kami_with_sound.mp4`, `video_loop_with_sound.mp4`, `video_holdem_with_sound.mp4`, `video_asteroid_with_sound.mp4`.

## Risks / open
- The sounds are synthetic placeholders. They set timing and mix, not the final style. The gun fires about 10 times a second and can get tiring; it is quiet (-10 dB) with pitch spread.
- There is no music and no per-channel volume (music / SFX sliders).
- Kamikaze smoke switches color by preset. It does not fade during a weather change, so it can pop from dark to pale (weather now blends over 12 s, so the pop is more visible).
