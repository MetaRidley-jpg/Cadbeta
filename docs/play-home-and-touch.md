# Play home screen + touch scrolling (slice 16j, 2026-11-26)

T, on the first iPhone test of the web build: "Scrolling doesn't work on mobile, condense play into an app icon screen basically".

## The scroll bug
- **Symptom:** on the phone, a list (Bones, Schemes, Wardrobe, Stash, Play, Fold) only scrolled if the finger started on an empty gap between cards.
- **Cause:** Godot cards (PanelContainer) and buttons have `mouse_filter = STOP` by default. A drag that starts on them never reaches the ScrollContainer. Desktop testing hid it (mouse wheel works). **It is not web-only;** a native phone build had the same bug.
- **Fix:** `main.gd _touch_scroll_fix(n)`. Every Control inside a ScrollContainer that STOPs input is set to PASS. Hooked on `SceneTree.node_added`, so rows built later are covered too. One pass at `_ready` covers nodes from the scene file.
- **Tap vs drag:** a short tap is still a button press. A drag past the scroll deadzone (14 px) scrolls and cancels the press. Measured: drag on a button → scroll ~279-410 px, 0 presses.
- **Rule for new UI:** a control inside a scroll list that needs its own drag (a slider, a draggable card) must set its filter AFTER `add_child`, or it will be switched to PASS.

## Play home screen
- 3 x 2 grid of app icons (`scripts/play_icon.gd`, class `PlayIcon`, a flat Button that draws its own tile): **Pool, Dogfight, Blackjack, Hold'em, Pinball, Options**. One tap starts the game.
- Tile 150 px, chunky 5-band gradient, glyphs drawn in code: 8-ball + cue; T's jet from above over a sunset; K + A cards; chip stack + Q; pinball (locked); gear.
- **Badges / states:** Dogfight shows "W{best wave}". Hold'em shows a lock + "Closed mm:ss" while the table is closed. Pinball shows SOON and is locked.
- Under the grid: the dogfight best (or what it pays) and the card-table bet cap.
- **Options** (gear) opens a sheet with a "< PLAY" back button: Jet + CHANGE JET, ASSIST, KO REPLAY, controls note, table skin + CHANGE, the bet table by rank, her pool style today.
- Debug flag: `--tab=4 --playopts` opens the Options sheet.
- Fits on one screen at 720x1280.

## Phone layout (16k)
- `Game.is_phone()`; web phones keep 4.5% of the height free at the bottom (`Game.WEB_HOME_BAR`) so the iOS home-bar swipe does not eat the pool power meter or the nav bar.

## Tests
- `tests/touch_test.tscn` (25 checks) sends the same ScreenTouch / ScreenDrag events a phone sends:
  - On every list page that overflows: a drag that starts on a card scrolls > 120 px; a drag that starts on a button scrolls > 120 px and presses nothing.
  - The Play home fits on one screen; 6 icons; each icon ≥ 150 x 190 px; Pinball locked.
  - Tap Options → the sheet opens; tap Dogfight → the dogfight starts.
- In the web build gate.
- Test traps: positions must go through `get_viewport().get_final_transform()`; choose a target AFTER resetting the scroll, and away from the bottom edge, or the finger lands on the nav bar.

## Open (hostile audit)
1. The Options sheet still scrolls a little at 720x1280.
2. The icons are code-drawn placeholders. T's icon art can replace `_draw` per kind.
3. Pinball takes a slot while it does not exist.
4. Card-table bets are explained only in Options.
