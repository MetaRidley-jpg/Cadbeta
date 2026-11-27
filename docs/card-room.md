# Card room: 3D view (Poker Night style)

T, 2026-11-25, on the first flat top-down table: "More dynamic like the camera angle of night at the inventory".

Reference: in Poker Night at the Inventory (Telltale, 2010) the default is a first-person camera from your seat, and the camera angles move during conversations.

Both card games use this room: blackjack (Cadavire deals) and Hold'em (Cadavire plays; see `docs/holdem.md`). Each game page draws its own cards, chips and labels through the hooks `draw_felt(view)` and `draw_labels(view)`.

## What was built (`scripts/cards/card_room_view.gd`)
- **First-person view from your seat.** Cadavire stands across the table, and the managers sit at the left and right ends. You are the unseen player.
- **Sprite stacking in perspective:**
  - Each slice of a stack (table, chairs) is drawn as a flat textured quad at its own height, projected through the camera.
  - Between two slices, extra copies fill the gap: one per screen pixel of rise, max 40. So a stack never looks see-through from a low angle.
  - Each quad is split into a small grid so the texture follows the perspective.
  - **Performance (slice 16k, the iPhone crash):** this used to be one draw call per grid cell per copy, ~8,500-14,900 draw calls per frame (47-79 ms of draw code), which crashed Safari on the iPhone. Now each stack and each quad is ONE triangle batch (`RenderingServer.canvas_item_add_triangle_array`); each slice's grid is projected at its own height and the next slice's height, and the copies are placed by 2D interpolation. ~60-120 draw calls, 3-5 ms, identical look. `cards_test` guards the draw time (< 15 ms).
- **Table:** the `card_table` stack. The slab slices sit at 0.70 to 0.76 m and the pedestal slices are spread down to the floor. The felt texture lies flat on top as its own quad, tinted by the table skin. It turns pink in Fever. Felts: `art/table/felt.png` (blackjack), `art/table/felt_holdem.png`.
- **Chairs:** the `chair` stack at each side seat, turned to face the table. When a Hold'em manager goes home broke, the chair stays and the character leaves (the seat in the page's `seats` list becomes -1).
- **Characters:** billboards (flat images that always face the camera).
  - Cadavire's dealer image stands behind the table; the table hides her waist.
  - Each manager's image sits on their chair.
  - Replace the images in `art/table/chars/` with your art.
- **Cards:** textured quads lying on the felt. An offscreen atlas (`card_atlas.gd`, `card_art.gd`) paints all 52 faces and the back once.
  - Cards fly from the shoe in a small arc.
  - Cards are 1.6x real size so they read on a phone.
  - Seat cards lie turned toward each manager.
  - Hand spots: p (you), d (dealer), s0/s1 (managers), b (Hold'em board), p0/p1 (your two hands after a blackjack split, 0.25 m left and right).
- **Chips:** stacked discs. Labels (totals, names, results) are drawn on the screen at the projected spots.

## Camera shots (`SHOTS`)
| Shot | When | What it frames |
|---|---|---|
| seat | betting, dealing | the whole table, from behind your cards |
| hand | your turn | pushed in, looking down at your cards |
| dealer | dealer's turn / Cadavire acts | Cadavire, close |
| seat0 / seat1 | a manager talks (3 s, then back) or acts | that manager, close |
| result | after the hand | wider, slightly higher |

- The camera eases between shots (exponential smoothing) and always sways a little.
- **FAST: ON** (slice 12; a button on both tables, saved in `Game.fast_table`): AI turns are quicker, the camera does not move for AI turns, and a quip holds the camera for 1.5 s instead of 3 s.
- Dialogue: slot 1 (Cadavire) and slot 2 (manager quips) stay where they are on every screen. Slot 2 slides in over the top of the view, and the camera turns to that manager at the same time.

## Debug + demo
- `--bjshot=seat0` holds a shot. `--bjauto --bjnext=peek` makes the table play itself (deal, split 8s and aces, hit under 17, stand). `--fast` turns FAST on. `--memlog` prints memory, draw calls and the room draw time every 2 s.
- GIFs: `tools/demos/demo_card_room.gif`, `demo_holdem.gif`, `demo_blackjack_split.gif`.
- Tests: `tests/cards_test.gd` (57 checks: rules, funny business, camera, split, FAST, draw cost).

## Known limits
- The placeholder busts are 32x40 pixel art blown up very large in the close-ups. Your art should be drawn for about 300-500 px tall on screen.
- The cards are bigger than real cards; the stack and character proportions are stylized.
- The managers are half off-screen in the wide shot on a narrow phone. The close-up shots show them fully.
- After a split, the hand shot still frames both hands, but the seat cards on the sides are cut off in that shot.
