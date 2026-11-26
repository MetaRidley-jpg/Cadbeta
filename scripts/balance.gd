class_name Balance
extends RefCounted
## All tuning numbers live here. Change values here, not in game.gd.

enum Cat { GAG, INDUSTRIAL, LAUNDERING }
const CAT_NAMES := ["Gag", "Industrial", "Laundering"]

# AdCap-shaped curve with adjusted numbers.
# cost = first unit price, coef = price growth per unit,
# revenue = bones per cycle for ONE unit, time = seconds per cycle.
const BUILDINGS := [
	{"id": "broth", "name": "Bone Broth Stand", "cat": Cat.GAG,
	 "cost": 4.0, "coef": 1.07, "revenue": 1.0, "time": 0.6,
	 "manager": "Soup Ghoul", "manager_cost": 1000.0,
	 "flavor": "Simmered for nine hours. Or nine years."},
	{"id": "xylo", "name": "Haunted Xylophone Lessons", "cat": Cat.GAG,
	 "cost": 62.0, "coef": 1.15, "revenue": 62.0, "time": 3.0,
	 "manager": "Tone-Deaf Lich", "manager_cost": 15000.0,
	 "flavor": "Every ribcage is an instrument if you are brave."},
	{"id": "crusher", "name": "Calcium Crusher", "cat": Cat.INDUSTRIAL,
	 "cost": 740.0, "coef": 1.14, "revenue": 560.0, "time": 6.0,
	 "manager": "Hydraulic Hank", "manager_cost": 100000.0,
	 "flavor": "Rated for femurs. Not rated for fingers."},
	{"id": "dogpark", "name": "Totally Legit Dog Park", "cat": Cat.LAUNDERING,
	 "cost": 8800.0, "coef": 1.13, "revenue": 4400.0, "time": 12.0,
	 "manager": "Very Good Boy (CPA)", "manager_cost": 520000.0,
	 "flavor": "The dogs bury them. We dig them up clean."},
	{"id": "foundry", "name": "Femur Foundry", "cat": Cat.INDUSTRIAL,
	 "cost": 105000.0, "coef": 1.12, "revenue": 52000.0, "time": 24.0,
	 "manager": "Forge Mummy", "manager_cost": 1.2e6,
	 "flavor": "Bones in. Better bones out."},
	{"id": "carwash", "name": "Ossuary Car Wash", "cat": Cat.LAUNDERING,
	 "cost": 1.26e6, "coef": 1.11, "revenue": 630000.0, "time": 96.0,
	 "manager": "Bubbles Moretti", "manager_cost": 1.05e7,
	 "flavor": "Nobody has ever brought a car."},
	{"id": "merch", "name": "Skele-Tees Merch Co.", "cat": Cat.GAG,
	 "cost": 1.5e7, "coef": 1.10, "revenue": 7.5e6, "time": 384.0,
	 "manager": "Influencer Wraith", "manager_cost": 1.12e8,
	 "flavor": "Limited drop. Very limited. Limbs, really."},
	{"id": "refinery", "name": "Marrow Refinery", "cat": Cat.INDUSTRIAL,
	 "cost": 1.8e8, "coef": 1.09, "revenue": 9.0e7, "time": 1536.0,
	 "manager": "Dr. Pith", "manager_cost": 5.6e8,
	 "flavor": "Smells like pennies and ambition."},
	{"id": "bank", "name": "Offshore Bone Bank", "cat": Cat.LAUNDERING,
	 "cost": 2.15e9, "coef": 1.08, "revenue": 1.08e9, "time": 6144.0,
	 "manager": "The Accountant (Deceased)", "manager_cost": 1.0e10,
	 "flavor": "Registered on an island that is mostly sharks."},
	{"id": "reactor", "name": "Ribcage Reactor", "cat": Cat.INDUSTRIAL,
	 "cost": 2.6e10, "coef": 1.07, "revenue": 2.97e10, "time": 36864.0,
	 "manager": "Chief Containment Ghoul", "manager_cost": 1.0e11,
	 "flavor": "Do not ask what the coolant is."},
]

# Owning this many units of one building halves its cycle time (each step).
const SPEED_MILESTONES := [25, 50, 100, 200, 300, 400]
# Every 100 units after 400 doubles that building's revenue.
const PROFIT_STEP_START := 500
const PROFIT_STEP := 100

# First time EVER a building reaches this count, you get Marrow.
const MARROW_MILESTONE_COUNT := 100
const MARROW_MILESTONE_REWARD := 3

# Prestige rank: own at least N of EVERY building. First time only. Permanent.
const RANK_THRESHOLDS := [10, 50, 75, 100]
const RANK_INCOME_BONUS := 0.5   # each rank adds +50% income
const RANK_COLORS := [
	Color("6b6470"), Color("c9b38a"), Color("43c6b8"), Color("f26a1b"), Color("ff3d8b"),
]
const RANK_NAMES := ["Unranked", "Gravedigger", "Undertaker", "Bone Baron", "Ossuary Queen"]

# Fold (reset; code name 'rebury'): Marrow gained = floor(sqrt(run_bones / REBURY_DIVISOR)).
const REBURY_DIVISOR := 1.0e7
# ---------------- Manager loyalty (permanent, 5 tiers) ----------------
# Tier 1 = first hire. Each Fold moves every manager you had hired up 1 tier.
# The multiplier is permanent: it works on that building even before you rehire.
const LOYALTY_MAX := 5
const LOYALTY_MULT := [1.0, 1.0, 1.75, 3.0, 5.0, 7.5]   # index = tier (0 = never met)

# ---------------- Level meter (permanent; only an endgame reset clears it) ----------------
# Fed only by bones earned. Level = LEVEL_PER_DECADE * log10(1 + bones earned).
# 3 levels per x10 bones: it moves very slowly. Display only for now (no bonus).
const LEVEL_PER_DECADE := 3.0

# ---------------- Schemes (one-time Bone upgrades, reset on Fold) ----------------
# Per building: 3 schemes, each x3 that building's income.
const SCHEME_PRICE_L1 := [2.5e5, 5.0e5, 1.0e6, 5.0e6, 1.0e7, 2.5e7, 5.0e8, 1.0e9, 5.0e9, 1.0e10]
const SCHEME_LEVEL_SCALE := [1.0, 1.0e5, 1.0e10]
const SCHEME_MULT := 3.0
const SCHEME_NAMES := [
	["Secret Family Marrow Recipe", "Broth Franchise Pyramid", "Soup-of-the-Month Club"],
	["Bone-Tuning Fork Mafia", "Recitals Nobody Asked For", "Catacomb World Tour"],
	["Overclocked Pistons", "Crush Twice, Bill Once", "Skeleton Night Shift"],
	["Bury-Dig-Repeat Pipeline", "Rigged Dog Show Prizes", "Forged Pedigree Papers"],
	["Femur Futures Market", "Molten Calcium Hot Tub", "Cast Iron Ribs"],
	["Wax On, Bones Off", "Tire Shine Shell Company", "Drive-Thru Embalming"],
	["Limited Skull Drop", "Influencer Exhumation Tour", "Bootleg Skele-Tees"],
	["Ultra-Refined Pith", "Smuggle It In The Pipes", "Marrow Spa Retreats"],
	["Shark-Guarded Vault", "Numbered Bone Accounts", "Tax Haven Graveyard"],
	["Coolant: Do Not Ask", "Containment Is A Suggestion", "Meltdown Insurance Fraud"],
]
# Global schemes: x3 ALL income.
const GLOBAL_SCHEMES := [
	{"name": "Bone Laundering 101", "price": 2.0e10},
	{"name": "Grand Ossuary Cartel", "price": 2.0e13},
	{"name": "Skeleton Key to the City", "price": 2.0e16},
]

## Flat list of every scheme: {id, name, price, target (-1 = all)}. Sorted by price.
static func all_schemes() -> Array:
	var out: Array = []
	for i in BUILDINGS.size():
		for lv in 3:
			out.append({"id": "%s_%d" % [BUILDINGS[i].id, lv], "name": SCHEME_NAMES[i][lv],
				"price": SCHEME_PRICE_L1[i] * SCHEME_LEVEL_SCALE[lv], "target": i})
	for g in GLOBAL_SCHEMES.size():
		out.append({"id": "global_%d" % g, "name": GLOBAL_SCHEMES[g].name,
			"price": GLOBAL_SCHEMES[g].price, "target": -1})
	out.sort_custom(func(a, b): return a.price < b.price)
	return out

# ---------------- Fever ----------------
const FEVER_MAX := 100.0
const FEVER_PASSIVE_PER_SEC := 100.0 / (18.0 * 60.0)  # ~18 min of active play
const FEVER_IDLE_AFTER := 40.0       # seconds with no input = idle
const FEVER_IDLE_DECAY := 0.04       # per second while idle
const FEVER_ON_BUY := 0.25
const FEVER_ON_MANAGER := 2.0
const FEVER_ON_COSTUME_BUY := 15.0
const FEVER_DURATION := 120.0
const FEVER_INCOME_MULT := 2.0
const FEVER_COST_MULT := 0.75
const CAVEMAN_FEVER_GAIN := 1.6      # "shorter" meter = fills 1.6x faster

# ---------------- Taste tests ----------------
const TASTE_INTERVAL_MIN := 50.0
const TASTE_INTERVAL_MAX := 110.0
const TASTE_FEVER := [1.0, 2.0, 4.0, 7.0]          # by quality 0..3
const TASTE_BUFF_MULT := [1.0, 1.0, 1.5, 2.0]      # revenue buff on that building
const TASTE_BUFF_TIME := 60.0
const TASTE_MARROW_CHANCE := 0.15                  # on quality 3
const QUALITY_NAMES := ["Stale", "Decent", "Good", "Exquisite"]

# ---------------- Dialogue pacing ----------------
const IDLE_TALK_MIN := 40.0
const IDLE_TALK_MAX := 80.0
const FEVER_TALK_MIN := 8.0
const FEVER_TALK_MAX := 14.0

# ---------------- Costumes (Marrow, permanent) ----------------
# Effects are read by Game.costume_effect(key).
const COSTUMES := [
	{"id": "grave_casual", "name": "Grave Casual", "price": 0, "rank": 0,
	 "desc": "Hoodie, dirt, good intentions. No bonus.", "fx": {}},
	{"id": "hard_hat", "name": "Hard Hat & Hi-Vis", "price": 15, "rank": 0,
	 "desc": "Industrial income x1.5.", "fx": {"cat_mult": {Cat.INDUSTRIAL: 1.5}}},
	{"id": "clown", "name": "Bone-a-fide Clown", "price": 15, "rank": 0,
	 "desc": "Gag income x1.5.", "fx": {"cat_mult": {Cat.GAG: 1.5}}},
	{"id": "pinstripe", "name": "Pinstripe Racketeer", "price": 25, "rank": 0,
	 "desc": "Laundering income x1.5. Laundering costs -10%.",
	 "fx": {"cat_mult": {Cat.LAUNDERING: 1.5}, "cat_cost": {Cat.LAUNDERING: 0.9}}},
	{"id": "lab_coat", "name": "Lab Coat", "price": 40, "rank": 0,
	 "desc": "Taste tests 2x as often. Better bone quality.",
	 "fx": {"taste_rate": 2.0, "taste_quality": 1}},
	{"id": "caveman", "name": "Cave-Gal Pelt", "price": 60, "rank": 0,
	 "desc": "Fever fills 1.6x faster. Eats ANY bone with max joy. Bites are 3x bigger. Bonez.",
	 "fx": {"fever_gain": CAVEMAN_FEVER_GAIN, "eat_anything": true, "bite": 3.0}},
	{"id": "warzone", "name": "Warzone Fatigues", "price": 90, "rank": 1,
	 "desc": "Offline earnings x1.5. Manager costs -25%.",
	 "fx": {"offline_mult": 1.5, "manager_cost": 0.75}},
	{"id": "regal_decay", "name": "Regal Decay", "price": 300, "rank": 2,
	 "desc": "All income x2. Rebury Marrow +25%. Fever lasts +30s. All costs -5%.",
	 "fx": {"all_mult": 2.0, "marrow_mult": 1.25, "fever_time": 30.0, "cost_mult": 0.95}},
]

# ---------------- Items (Bones). Equip one OR gift it. ----------------
# Equipped item is NOT shown on her skin. Gift = consumed, big Fever + line.
const ITEMS := [
	{"id": "dog_chew", "name": "Dog Chew (Premium)", "price": 500.0, "gift_fever": 12.0,
	 "equip_desc": "Taste tests: +1 quality step sometimes.", "fx": {"taste_quality_chance": 0.35}},
	{"id": "knuckle_jar", "name": "Jar of Knuckles", "price": 25000.0, "gift_fever": 18.0,
	 "equip_desc": "All income +10%.", "fx": {"all_mult": 1.10}},
	{"id": "velvet_ribbon", "name": "Velvet Ribbon", "price": 4.0e5, "gift_fever": 25.0,
	 "equip_desc": "Fever drains 50% slower when you idle.", "fx": {"idle_decay": 0.5}},
	{"id": "hand_mirror", "name": "Cracked Hand Mirror", "price": 8.0e6, "gift_fever": 25.0,
	 "equip_desc": "All costs -5%.", "fx": {"cost_mult": 0.95}},
	{"id": "femur_pendant", "name": "Femur Pendant", "price": 1.5e8, "gift_fever": 30.0,
	 "equip_desc": "Taste tests 1.5x as often.", "fx": {"taste_rate": 1.5}},
	{"id": "music_box", "name": "Music Box (Funeral March)", "price": 5.0e9, "gift_fever": 35.0,
	 "equip_desc": "Fever lasts +20s.", "fx": {"fever_time": 20.0}},
	{"id": "valentine", "name": "Fossilized Valentine", "price": 1.0e12, "gift_fever": 45.0,
	 "equip_desc": "All income +25%.", "fx": {"all_mult": 1.25}},
]

static func building_index(id: String) -> int:
	for i in BUILDINGS.size():
		if BUILDINGS[i].id == id:
			return i
	return -1

static func costume(id: String) -> Dictionary:
	for c in COSTUMES:
		if c.id == id:
			return c
	return COSTUMES[0]

static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if it.id == id:
			return it
	return {}
