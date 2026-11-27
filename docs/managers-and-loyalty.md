# Managers and loyalty

Source of truth for text: `data/manager_scenes.json`. Numbers: `scripts/balance.gd` (LOYALTY_MULT).

## Rules
- Tier 1 = first hire (x1, auto-runs the building). Each **Fold** (prestige reset): every manager hired that run goes up 1 tier. Max 5.
- Multiplier per tier: x1, x1.75, x3, x5, x7.5. Permanent. Works on the building before rehire.
- Scene for a new tier plays on (re)hire. After tier 5: a short rehire line.
- Running joke of tiers 2-5: the business folded, everything was seized, but bones aren't money, so you kept them.
- Arc per manager: T1 intro, T2 first collapse, T3 notices the pattern, T4 shows the motive, T5 fully in on it (motive revealed in the UI on the Fold page).

## Cast
| Building | Manager | Motive (revealed at tier 5) | Voice |
|---|---|---|---|
| Bone Broth Stand | Soup Ghoul | Crush (on you) | nervous, eager, hairnet |
| Haunted Xylophone Lessons | Tone-Deaf Lich | Takeover | theatrical, musical threats |
| Calcium Crusher | Hydraulic Hank | Money | blue-collar, overtime, wants a cut |
| Totally Legit Dog Park | Very Good Boy (CPA) | Crush (on Cadavire: she is made of bones) | dog + accountant |
| Femur Foundry | Forge Mummy | Unknown: undercover auditor who switched sides | dry, secretive, a badge falls out |
| Ossuary Car Wash | Bubbles Moretti | Takeover | mobster, "capisce" |
| Skele-Tees Merch Co. | Influencer Wraith | Money (clout) | influencer, monetizes your collapses |
| Marrow Refinery | Dr. Pith | Unknown: he just likes it here | scientist, studies you two |
| Offshore Bone Bank | The Accountant (Deceased) | Money | dead, greedy, statute-checker |
| Ribcage Reactor | Chief Containment Ghoul | Takeover (final boss energy) | calm threats, "don't ask what the coolant is" |

Cadavire in scenes: stays flirty and complicated, never sad. With the Soup Ghoul's crush on you she gets flustered and possessive in a joking way ("the bones care though, I'm the bones"). With the dog's crush on her, she is flattered and alarmed. With takeover managers she gets excited about having a rival.

## UI
- Slot 1 (main box, Cadavire) top-right of stage. Slot 2 (manager box) full width directly under the stage, slides in from the right. Same rule for future minigame opponents.
- Your lines are the reply button ("YOU: ..."). SKIP always present.
- Art: `art/managers/<building_id>.png`, square 112x112 slot. Placeholder = initials.
