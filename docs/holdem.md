# Card table: TEXAS HOLD'EM (built 2026-11-25, economy fixes in slice 12)

T's direction: blackjack and Hold'em are the only Marrow wagers; managers can join; "funny business" dialogue. Design note from the start: Cadavire is the dealer in blackjack, and a PLAYER in Hold'em.

## Rules (`scripts/cards/holdem.gd`)
- **Fixed limit**, chosen for a phone: three buttons (FOLD, CHECK/CALL, BET/RAISE) and no bet slider.
  - Blinds 1/2. Bets are 2 on preflop and flop, 4 on turn and river.
  - Max 4 bets per round (a bet plus 3 raises).
- **Chips:** 1 Marrow = 10 chips.
  - You buy in for 1 to your rank cap in Marrow (`Game.max_bet()`: 5/10/25/50/100). The buy-in leaves at BUY IN (`Game.start_wager`).
  - CASH OUT between hands pays floor(chips / 10) Marrow back (`Game.settle_wager`).
  - If you lose all your chips, the stake is settled at 0 and you can REBUY.
  - Leaving mid-hand is blocked.
- **Hand ranking:** best 5 of 7, all 9 categories plus royal flush. The ace plays high and low (wheel). Two trips make a full house; three pairs give the best two plus the best kicker.
- **Pots:** side pots are built from contribution levels (`build_pots`). Folded money stays in the pots, but folded players cannot win. Split pots give the odd chip to the first winner.

## Economy (slice 12, from the audit of slice 11)
Problem found: Hold'em had no house edge, and the AI reloaded for free. A player who beats the AI could farm Marrow without limit, and Marrow buys the costumes.
- **House cut ("the jar"):** 5% of a pot that saw a flop, max 3 chips (`Holdem.rake`). No flop, no cut. **No cut during Fever** (Fever makes things cheaper). The cut comes out of the main pot first. The felt shows "JAR n" for this sitting, and the result line shows "house cut n".
- **Opponents' money:** they sit with your buy-in in chips, at least 20 (`AI_MIN_STACK`).
- **Bankrolls:** when an opponent ends a hand with less than 8 chips:
  - The first time, they reload to their starting stack ("reloads (last time)").
  - The second time, they **go home broke for 30 min** (`Game.send_home`, saved in `Game.table_away`). They say a "broke" line (`card_table.json`). Their chair stays empty ("WENT HOME BROKE"), and they also skip the blackjack table until they come back.
- **Break the house:** if Cadavire runs short after her one reload:
  - The table closes for 30 min, the banner says "YOU BROKE THE HOUSE", and you get +25 Fever.
  - The gold window `g_house` breaks.
  - You can still cash out. The Play home shows a lock + "Closed mm:ss" on the Hold'em icon.
- **Max profit per sitting** is now about 2 x your buy-in per opponent (their stack + one reload), minus the cut. After that, the table is empty for 30 min.

## Seats (same 3D room as blackjack, `docs/card-room.md`)
- You (near side), Cadavire across the table (she plays), and up to 2 met managers who are not home broke. Play goes clockwise: you, left, Cadavire, right. The dealer button moves each hand.
- The camera turns to whoever acts. With **FAST: ON** it stays on the wide shot, and AI turns take 0.28 s instead of 0.7 s.
- Folded hands leave the table. At the showdown every live hand turns face up with its hand name.
- Labels show each stack, the last action, the button (D) and your current best hand. Chips show bets in front of each player and the pot in the middle.

## Seat AI
- **Strength:** a Monte Carlo win chance against the players still in the hand (140 runs, cached per street). ~6 ms per call on desktop (measured slice 16k); on an iPhone in Safari that can be a 20-30 ms hitch per AI decision.
- **Decision:** the strength is compared with the pot odds and a style:

| Style | Who | Plays |
|---|---|---|
| tight | Hydraulic Hank, The Accountant, Influencer Wraith | raises 66%+, folds junk |
| loose | Tone-Deaf Lich, Bubbles Moretti, Chief Containment Ghoul (Takeover) | raises 50%+, bluffs about 22% of the time with weak hands |
| soft_you | Soup Ghoul (crush on you) | never raises you, folds more against you |
| soft_her | Very Good Boy CPA (crush on Cadavire) | soft against Cadavire |
| wild | Forge Mummy, Dr. Pith | random thresholds |
| cadavire | Cadavire | balanced, small bluff rate |

## Funny business (Hold'em versions; 30% per hand, one manager)
- **peek:** Soup Ghoul shows you one of Cadavire's hole cards.
- **count:** Hank / The Accountant tell you whether someone ELSE looks strong or weak.
- **burn / bottom:** the Lich / Moretti burn an extra card, so the board changes.
- **hide:** if you fold, the dog slides you 2 chips.
- **audit:** if you lose at the showdown, half of what you put in comes back.
- **clout:** +5 chips if you win the pot.
- **skim:** -2 chips from your win; Cadavire catches him half the time.
- **snack:** Dr. Pith only talks.
- Manager lines: `data/card_table.json` ("raise", "broke"). Cadavire's lines: `he_*` in `dialogue.json` (he_closed, he_broke_house, he_sent_home added in slice 12).

## Stability (slice 16k)
- T reported "Poker games are not stable at all" → "Freezes / stops, Crashes entire app shortly after launch" on the iPhone web build. Root cause: the card room's draw calls (see `docs/card-room.md`), not the poker logic.
- `tests/holdem_stress.tscn` (optional, slow): plays Hold'em in real time through `_process` over many seeds; found no lost chips or hangs in normal play. `open()` now clears the step queue as a guard.

## Tests / debug / demo
- `tests/holdem_test.gd`: ~50-58 checks. They cover rankings, side pots, strength, AI styles, buy-in, blinds, 40 auto hands, your actions, chip conservation (minus the cut, plus reloads), funny business, cash-out, the cut rules, reload then home, the empty chair, the blackjack seat filter, breaking the house, and the closed table.
- Debug run args: `--holdem --hebuy=5 --heauto --henext=peek --hehands=3 --heshot=result --hehome --hebroke --fast`
- GIF: `tools/demos/demo_holdem.gif`.
- Challenge counters: `he_wins`, `he_sent_home`, `he_house_broke`.

## Known limits / risks
- No-limit is not built. Fixed limit plays faster, but it has less drama than all-in moments.
- The AI does not model opponents beyond its style. Players who bluff a lot can exploit the tight seats.
- The 30-min cooldown is real time. A player can still change the device clock to skip it.
- With the cut at max 3 chips, small pots pay a bigger share than big pots, and most of the edge on a skilled player comes from the bankroll limits, not the cut.
