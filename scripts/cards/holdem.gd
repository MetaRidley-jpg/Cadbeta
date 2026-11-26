class_name Holdem
extends RefCounted
## Texas Hold'em rules (no drawing): deck, 7-card hand ranking, side pots, and the
## seat AI. FIXED-LIMIT betting (small bet preflop/flop, big bet turn/river, max 4
## bets per round): three buttons on a phone, no bet slider.
## Cards use the blackjack format {"r": 1..13, "s": 0..3}; aces rank high (14) and low (wheel).

const SMALL_BLIND := 1
const BIG_BLIND := 2
const SMALL_BET := 2
const BIG_BET := 4
const MAX_BETS := 4                # bet + 3 raises per round
const CHIPS_PER_MARROW := 10
# House cut ("the jar"): 5% of a pot that saw a flop, max 3 chips. No flop, no cut.
# During Fever there is no cut (Fever makes things cheaper).
const RAKE_PCT := 0.05
const RAKE_CAP := 3
const AI_MIN_STACK := 20           # opponents sit with your buy-in, at least this many chips
const AI_RELOADS := 1              # then each can reload this many times before going home

## Chips the house takes from a finished pot.
static func rake(pot: int, saw_flop: bool, fever := false) -> int:
	if fever or not saw_flop:
		return 0
	return mini(RAKE_CAP, int(floor(pot * RAKE_PCT)))

const NAMES := ["High card", "Pair", "Two pair", "Three of a kind", "Straight", "Flush",
	"Full house", "Four of a kind", "Straight flush"]

var deck: Array = []
var rng := RandomNumberGenerator.new()

func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

func new_deck() -> void:
	deck.clear()
	for s in 4:
		for r in range(1, 14):
			deck.append({"r": r, "s": s})
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = deck[i]
		deck[i] = deck[j]
		deck[j] = t

func draw() -> Dictionary:
	return deck.pop_back()

static func hi(c: Dictionary) -> int:
	return 14 if int(c.r) == 1 else int(c.r)

## Score of the best 5-card hand in `cards` (5..7 cards). Compare with compare().
## [category, tiebreak ranks...]  category: 0 high card .. 8 straight flush.
static func rank_hand(cards: Array) -> Array:
	var counts := {}
	var suits := [[], [], [], []]
	for c in cards:
		var r := hi(c)
		counts[r] = int(counts.get(r, 0)) + 1
		suits[int(c.s)].append(r)
	# straight flush / flush
	for s in 4:
		if suits[s].size() >= 5:
			var sf := _straight_top(suits[s])
			if sf > 0:
				return [8, sf]
			var fl: Array = suits[s].duplicate()
			fl.sort()
			fl.reverse()
			var flush := [5]
			flush.append_array(fl.slice(0, 5))
			# a flush can still lose to quads / full house: check those first
			var q := _of_a_kind(counts)
			if q[0] >= 6:
				return q
			return flush
	var st := _straight_top(counts.keys())
	var k := _of_a_kind(counts)
	if k[0] >= 6:
		return k
	if st > 0:
		return [4, st]
	return k

static func _straight_top(ranks: Array) -> int:
	var have := {}
	for r in ranks:
		have[int(r)] = true
	if have.has(14):
		have[1] = true                      # wheel: A-2-3-4-5
	for top in range(14, 4, -1):
		var ok := true
		for d in 5:
			if not have.has(top - d):
				ok = false
				break
		if ok:
			return top
	return 0

## Quads / full house / trips / two pair / pair / high card from rank counts.
static func _of_a_kind(counts: Dictionary) -> Array:
	var groups: Array = []                 # [count, rank]
	for r in counts:
		groups.append([int(counts[r]), int(r)])
	groups.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]))
	var ranks_desc: Array = []
	for g in groups:
		ranks_desc.append(g[1])
	var top: Array = groups[0]
	if top[0] == 4:
		return [7, top[1], _kickers(ranks_desc, [top[1]], 1)[0]]
	if top[0] == 3:
		# full house: trips + the best other group of 2 or more (a second trips counts)
		for g in groups.slice(1):
			if g[0] >= 2:
				return [6, top[1], g[1]]
		var out := [3, top[1]]
		out.append_array(_kickers(ranks_desc, [top[1]], 2))
		return out
	if top[0] == 2:
		if groups.size() > 1 and groups[1][0] == 2:
			var out2 := [2, top[1], groups[1][1]]
			out2.append_array(_kickers(ranks_desc, [top[1], groups[1][1]], 1))
			return out2
		var out1 := [1, top[1]]
		out1.append_array(_kickers(ranks_desc, [top[1]], 3))
		return out1
	var out0 := [0]
	var all := ranks_desc.duplicate()
	all.sort()
	all.reverse()
	out0.append_array(all.slice(0, 5))
	return out0

static func _kickers(ranks: Array, skip: Array, n: int) -> Array:
	var k: Array = []
	var sorted := ranks.duplicate()
	sorted.sort()
	sorted.reverse()
	for r in sorted:
		if not skip.has(r):
			k.append(r)
		if k.size() >= n:
			break
	while k.size() < n:
		k.append(0)
	return k

## > 0: a beats b, < 0: b beats a, 0: tie.
static func compare(a: Array, b: Array) -> int:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return 1 if a[i] > b[i] else -1
	return 0

static func hand_name(score: Array) -> String:
	if score[0] == 8 and score[1] == 14:
		return "Royal flush"
	return NAMES[score[0]]

## Pots from total contributions. players: [{contrib, folded}] -> [{amount, eligible: [idx]}]
static func build_pots(players: Array) -> Array:
	var levels: Array = []
	for p in players:
		if int(p.contrib) > 0 and not levels.has(int(p.contrib)):
			levels.append(int(p.contrib))
	levels.sort()
	var pots: Array = []
	var prev := 0
	for lv in levels:
		var amount := 0
		var elig: Array = []
		for i in players.size():
			var c: int = players[i].contrib
			amount += clampi(c - prev, 0, lv - prev)
			if c >= lv and not players[i].folded:
				elig.append(i)
		if amount > 0:
			if elig.is_empty() and not pots.is_empty():
				pots[pots.size() - 1].amount += amount     # dead money goes to the last live pot
			else:
				pots.append({"amount": amount, "eligible": elig})
		prev = lv
	return pots

## Win chance of `hole` vs `opponents` random hands, given the board (Monte Carlo).
func strength(hole: Array, board: Array, opponents: int, iters := 160) -> float:
	var known := hole + board
	var pool: Array = []
	for s in 4:
		for r in range(1, 14):
			var used := false
			for c in known:
				if int(c.r) == r and int(c.s) == s:
					used = true
					break
			if not used:
				pool.append({"r": r, "s": s})
	var wins := 0.0
	for it in iters:
		# partial shuffle: only as many cards as we need
		var need := (5 - board.size()) + opponents * 2
		for i in need:
			var j := rng.randi_range(i, pool.size() - 1)
			var t = pool[i]
			pool[i] = pool[j]
			pool[j] = t
		var b := board + pool.slice(0, 5 - board.size())
		var mine := rank_hand(hole + b)
		var best := 1
		var ties := 1
		var o := 5 - board.size()
		for k in opponents:
			var their := rank_hand([pool[o + k * 2], pool[o + k * 2 + 1]] + b)
			var c := compare(mine, their)
			if c < 0:
				best = 0
				break
			if c == 0:
				ties += 1
		if best == 1:
			wins += 1.0 / ties
	return wins / iters

## Seat AI. style: "tight", "loose", "soft_you", "soft_her", "wild", "cadavire".
## Returns "fold", "call" (check when to_call = 0) or "raise" (bet when nothing to call).
func decide(style: String, s: float, to_call: int, pot: int, can_raise: bool, facing: String) -> String:
	var odds := float(to_call) / maxf(1.0, pot + to_call)
	var raise_at := 0.62
	var call_margin := 0.02
	var bluff := 0.0
	match style:
		"tight":
			raise_at = 0.66
			call_margin = 0.08
		"loose":
			raise_at = 0.5
			call_margin = -0.06
			bluff = 0.22
		"wild":
			raise_at = 0.45 + rng.randf() * 0.3
			call_margin = rng.randf_range(-0.15, 0.1)
			bluff = 0.15
		"cadavire":
			raise_at = 0.58
			call_margin = 0.0
			bluff = 0.1
	# crushes: soft against the one they like (folds more, never re-raises them)
	if (style == "soft_you" and facing == "you") or (style == "soft_her" and facing == "cadavire"):
		raise_at = 2.0
		call_margin = 0.12
	if can_raise and (s >= raise_at or rng.randf() < bluff * (1.0 - s)):
		return "raise"
	if to_call == 0:
		return "call"
	if s >= odds + call_margin:
		return "call"
	return "fold"
