# Challenges wall (achievements)

Source: T's direction on 2026-11-25. It is based on the Challenges screen in Super Smash Bros. Brawl. Golden Hammers became **Golden Bones**. Prize types: art, tints, alt dogfight jets, card-table skins. "Leave most blank for now."

## How it works (built)
- **The wall:** 4 rows x 32 columns = 128 glass windows. All windows start opaque. Swipe or drag to pan; the mouse wheel also pans. A minimap strip on top shows the whole wall; tap or drag it to jump.
- **Breaking:** when a hidden condition is met, the window is queued. The game then opens the wall by itself, about 1 s later. It waits until no minigame, popup, manager scene or art viewer is open. The camera scrolls to the window, the glass cracks, shards fly, and the prize shows. Cadavire comments in dialogue slot 1.
- **Hints:** a broken window turns the windows to its **left and right** red. Tap a red window to see the prize silhouette and the exact condition. Up and down do not give hints, as in T's brief.
- **Golden Bones:** each gold window pays 1 Golden Bone instead of a prize. A Golden Bone breaks any window at once, even a blank one. It cannot break gold windows or empty (not designed) windows.
- **Empty windows:** cells not listed in `data/challenges.json` are empty. They look like any other glass. As a hint, they show "Nothing designed here yet."
- **Access:** the CHALLENGES n/128 button in the top bar. A dot on it means a window is waiting to break.

## Prize types
| Type | What it does | Where it is used |
|---|---|---|
| Art | Full-resolution image, with credits | VIEW ART button opens a full-screen viewer: pinch or mouse wheel to zoom, drag to pan, double tap to fit, X or Esc to close |
| Tint | A color overlay on top of Cadavire. It stacks with outfits and changes color only (overlay blend, 70%) | Wardrobe > TINTS, or WEAR TINT on the wall |
| Jet | An alt player jet in the dogfight. Cosmetic only; same hitbox | Play > Options > CHANGE JET, or FLY THIS JET on the wall |
| Table | Card-table felt and rim colors | Play > Options > card table CHANGE. Used by the 3D card room (blackjack and Hold'em) |

## Current content (placeholders: T makes the real prizes)
20 of 128 windows are designed, and 6 of these are gold. All others are empty.
- Art: Bone Yard (earn 1,000 bones), Pilot Pin-up (exquisite taste test), Ash Over the Islands (level 10). The images are placeholders, 1440x2560, made from the carved stacks.
- Tints: Grave Moss (25 of one building), Fever Pink (fill Fever), Ectoplasm (3 gifts), Bog Iron (own 3 outfits), Poker Face (send a manager home broke at Hold'em; slice 12).
- Jets: Crimson Fang (survive 3 waves), Ghost Wing (score 5,000).
- Tables: Bone White (first manager), Midnight (beat her at pool), Royal Rot (loyalty tier 3), Tip Jar Brass (win 5 blackjack hands; slice 12).
- Gold: first Fold, survive wave 5, prestige rank 1, loyalty tier 5, 100 of every building, break the house at Hold'em (slice 12).

## How to add or change a window
Edit `data/challenges.json`. Each panel has an id, col (0-31), row (0-3), gold, `cond {stat, value}`, text and reward.
- Stats: total_bones, owned_max, owned_min, managers, folds, rank, level, df_best_wave, df_best_score, costumes, loyalty_max, cleared, pool_wins, gifts, fevers, exquisite, df_matches, bj_wins, he_wins, he_sent_home, he_house_broke.
- New counter: call `Challenges.bump("name")` at the event.
- Art: put the image anywhere under `res://` and point `file` at it. Any size works.
- Jet: draw `tools/art_src/<name>_views.png`, add it to `tools/carve_all.sh`, and set `strip` to that name.

## Files
- `scripts/challenges.gd`: autoload with rules, conditions, Golden Bones, cosmetics and save. It loads before Game, and its data saves inside Game's save.
- `scripts/challenges_page.gd`, `scripts/challenge_wall.gd`, `scripts/challenge_icons.gd`: the UI.
- `scripts/art_viewer.gd`: the art viewer. `scripts/stack_draw.gd`: live sprite-stack drawing for jet icons.
- `shaders/tint_overlay.gdshader`: the tint. `tools/make_placeholder_art.py`: the placeholder gallery images.
- Tests: `tests/challenges_test.gd` (116 checks).

## Decisions Claude made (T to confirm or override)
1. The wall opens by itself after a break, as in Brawl, but never mid-minigame. It waits 1 s so the player sees what they did first.
2. Golden Bones cannot break gold or empty windows.
3. Hints are left and right only, as in T's notes.
4. Tints go in the Wardrobe, not the Stash, because they are a look and not a consumable.
5. Alt jets are cosmetic only.

## Known problems / risks
- **Hints point at nothing.** With 20 of 128 windows designed, most red hints show "Nothing designed here yet." Brawl's loop depends on the windows near a broken one holding real prizes. Fill the windows near the start of the wall first, or move the designed windows together.
- **The tint colors the whole placeholder portrait card**, including its background. With real art on a transparent background, only her sprite changes.
- Crimson Fang's placeholder reads as a red lump in the turntable; Ghost Wing reads well.
