# Cadavire to-do list (updated 2026-11-27, after slice 16r — dev tooling)

Order = what I do next, top first. **P0** blocks shipping or is T's direct ask. **P1** structure (parent classes, scene split). **P2** content. **P3** store and release. Done items stay here with ✅ so the history is clear.

## Audit numbers (measured 2026-11-26)
- Code: 12,671 lines of GDScript before 16j. `df_game.gd` = 2,267 lines / 83 functions (494 lines are demo scripts, 239 are the boss). `df_render.gd` 1,416. `main.gd` ~1,200 (62+ debug command-line flags).
- Dogfight sim: 0.4 ms per step (wave 8).
- **Dogfight units draw: ~16 ms per frame on a desktop CPU, the same with 80 or 600 items.** So a fixed cost (not the sprite count) is eating most of the frame. On a mid phone this can be 3-5x worse = under 30 fps. Koi layers: 0.3-2.4 ms.
- Web build live at https://metaridley-jpg.github.io/Cadbeta/ (slice 16i). No Android or iOS native presets yet.
- `tools/demos/` = ~110 MB of GIFs and videos inside the project folder (git-ignored and left out of zips).
- Save has a version field (`SAVE_VERSION = 1`), but no migration code yet.

## P0: now
1. ✅ **KO replay: big cinematic wide shots** (slice 16c). Detail: `docs/dogfight-cinematics.md`.
2. ✅ **iPhone web build** (slice 16i). Detail: `docs/web-build.md`.
3. ✅ **Touch scrolling + Play app icons** (slice 16j, T's first phone notes). Detail: `docs/play-home-and-touch.md`.
3b. ✅ **iPhone notes round 2** (slice 16k): poker crash (card room 14,000 → ~100 draw calls), pool meter out of the swipe zone, phone replays without bars, wider auto-aim, random weather, yellow outlined text.
3f. ✅ **Skinny, larger rings that launch you** (slice 16o).
3e. ✅ **Ring courses + cyan chain laser** (slice 16n). Detail: `docs/rings-and-cyan-laser.md`. Needs T's phone test for course difficulty.
3d. ✅ **Dogfight polish** (slice 16m): wave 1 sky on boot, 12 s smooth weather, KO! text, enemies-left counter.
3h. ✅ **Rings in replays + Claude Code migration prep** (slice 16q): `CLAUDE.md`, `docs/`, `tools/setup_godot.sh`, SessionStart hook.
3g. ✅ **Courses rarer in later waves** (slice 16p). Waiting for T's phone test.
3c. ✅ **Redraw kit** (slice 16l): master sprite sheet, SVG templates, vector import. Detail: `docs/sprite-redraw.md`. Waiting for T's first SVG.
4. ✅ **First Claude Code session** (slice 16r): Godot downloads and all 8 suites pass in the cloud box. One test command: `bash tools/run_tests.sh`.
4c. **Hold'em test count is not fixed (about 52-55).** Seed the RNG in `holdem_test.gd` so each run checks the same hands.
4b. **More phone notes from T:** dogfight smoothness (boss wave, asteroid), touch controls in the dogfight and pool, text size, the replay strip. Add an on-screen fps counter to the web build for this.
5. **Find and fix the 16 ms fixed draw cost.** Slice 16q measure: draw calls are only 100-420 per frame, so it is CPU / script work, not batching. Profile per stage first. First suspects: the rain/ash/motion-line loops in `_draw_weather`, the ground shadow discs, `draw_circle` halos. Measure each stage AND count draw calls (the card room crash was 14,000 draw calls; batching cut it ~100x). This matters more on the web build (one thread, WebAssembly).
6. **Draw batching plan** (only if 5 is not enough): move the sprite pass from per-item `draw_*` calls to one batched mesh (MultiMesh or one ArrayMesh per frame), or move sort + draw to GDExtension (C# does not export to the web in Godot 4).

## P1: structure (parent classes, scene split)
7. **Split `df_game.gd` into a parent + children:**
   - `DfGame` (parent): state machine, waves, score, input.
   - `DfBoss` (child node): the gunship, cannon, rotors, phase 2.
   - `DfDemo` (child node): all `--dfdemo` scripts. It is not loaded in a shipping build.
   - `DfHud`: meters, brackets, arrows, beam glow.
   - `DfCameraRig`: chase camera, glances, shake.
   - `DfReplay` already is its own class.
8. **A `Minigame` parent class** for pool, dogfight, blackjack and hold'em: start / stop / pause, rewards (bones, Fever, Marrow), Cadavire's dialogue slot, results screen, back button. Today each game does this its own way. The Play icons (`PlayIcon`) would read their badge / lock state from it.
9. **Data-driven content:** waves, boss numbers and weather presets in `data/*.json` (or `.tres` resources), so tuning does not need code edits.
10. **Debug flags out of `main.gd`:** move the flags into a `DebugBoot` script that only loads in debug builds.
11. **Save migration:** a `migrate(from_version)` path before the next save field is added.
12. **Demo videos out of the project:** git and the zip leave out `tools/demos/`. Still to do: a `.gdignore` in `tools/demos/` so the editor skips it.
13. Workflow upkeep: bump the GitHub Actions versions (Node 20 deprecation warning).

## P2: content and feel
14. Boss: a move that is not the cannon (a dive, a ram, or calling escorts); show phase 2 in a demo.
15. Enemy AI pass: fighters that break and loop, wingman pairs.
16. Dogfight rewards: dogfight-only prizes and a reason to come back (challenge windows, alt jets).
17. Cadavire in the dogfight: a cockpit cut-in on the laser / drift boost / KO.
18. Pinball (not started; its icon is a locked SOON teaser).
19. Music (none yet) and final sounds (all placeholders). Replays have no sound except the KO blast.
20. Undecided design: what does a level give, and what resets it (endgame)?
21. Balance: rank 1 is hours away; late managers lag; prestige may be too strong.
22. Play icons: T's real icon art (replace `PlayIcon._draw` glyphs per kind).

## P3: store and release
23. Native export presets (Android + iOS), app icons, splash screen, signing. Native iOS needs a Mac (or a cloud Mac build) and an Apple developer account.
24. **Age rating + parental gate:** Cadavire's tone is flirty and the card tables use a wager currency, so the store rating questionnaires matter. Any IAP needs a parental gate if the game is rated for kids.
25. IAP: the Flight attendant outfit + $2 permanent 2x Bones. Rewarded ads (2x for 10 min).
26. Privacy policy, store listing, screenshots (the demo recorder can make these).
27. Cheat guard: the 30-min table timers use the device clock.
28. Public repo risk: before T's final art goes in, decide private repo + paid Pages or another host (`docs/web-build.md`).

## Test hygiene
- ✅ Hold'em test "your actions finish the hand" was flaky: the test now accepts "closed" (slice 16c).
- ✅ The web workflow runs rules + dogfight + touch before every publish (slice 16i / 16j).
- ✅ `tests/touch_test.tscn`: real finger events; catches any future list that eats drags (slice 16j).

## What I need from T
- **Now:** retest poker / blackjack, pool, a KO replay and the aim on the iPhone. First vector redraw (FRONT first) from `tools/redraw/templates/`.
- Rings / cyan laser: T chose to keep exact launches + rarer courses later (slice 16p); T will phone-test. course difficulty on the phone; should the chain include ships; should the supercharge expire; should later waves get fewer courses (the chain can wipe a wave)?
- Aim: if targets still feel missed, is it range (650 m) rather than angle?
- Answers: keep Pinball as a SOON icon or hide it until built? Level/endgame (20); is the 2.39:1 strip too small on the phone; is the boss dodge too strict on the phone; director weights; sky next or more stone on the stacks; music direction.
- Art: T's real art to replace placeholders (jets, gunship, Cadavire portraits, table characters, Play icons).
