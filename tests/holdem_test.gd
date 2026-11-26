extends Node
## Hold'em rules, AI and table flow. Run with -- --fresh.

var fails := 0
var passes := 0

func check(c: bool, msg: String) -> void:
	if c:
		passes += 1
	else:
		fails += 1
		printerr("FAIL: ", msg)

func C(r: int, s := 0) -> Dictionary:
	return {"r": r, "s": s}

func cat(cards: Array) -> int:
	return int(Holdem.rank_hand(cards)[0])

func _ready() -> void:
	Game.autosave_enabled = false
	Challenges.enabled = false

	# ---------------- hand ranking (7 cards)
	check(Holdem.hand_name(Holdem.rank_hand([C(1, 1), C(13, 1), C(12, 1), C(11, 1), C(10, 1), C(2), C(3, 2)])) == "Royal flush", "royal flush")
	check(cat([C(9, 2), C(8, 2), C(7, 2), C(6, 2), C(5, 2), C(13), C(13, 1)]) == 8, "straight flush beats the pair")
	check(cat([C(4), C(4, 1), C(4, 2), C(4, 3), C(9), C(9, 1), C(2)]) == 7, "quads")
	check(cat([C(4), C(4, 1), C(4, 2), C(9), C(9, 1), C(2), C(3)]) == 6, "full house")
	var two_trips := Holdem.rank_hand([C(4), C(4, 1), C(4, 2), C(9), C(9, 1), C(9, 2), C(2)])
	check(two_trips[0] == 6 and two_trips[1] == 9 and two_trips[2] == 4, "two trips = full house, nines full of fours")
	check(cat([C(2, 3), C(7, 3), C(9, 3), C(11, 3), C(13, 3), C(13), C(13, 1)]) == 5, "flush beats trips")
	check(cat([C(1), C(2, 1), C(3, 2), C(4, 3), C(5), C(13, 1), C(9, 2)]) == 4, "wheel A-2-3-4-5 is a straight")
	check(Holdem.rank_hand([C(1), C(2, 1), C(3, 2), C(4, 3), C(5), C(13, 1), C(9, 2)])[1] == 5, "wheel tops at 5")
	check(cat([C(10), C(11, 1), C(12, 2), C(13, 3), C(1), C(2), C(2, 1)]) == 4, "broadway straight beats the pair")
	check(cat([C(7), C(7, 1), C(7, 2), C(2), C(9, 1), C(11), C(13, 2)]) == 3, "trips")
	var tp := Holdem.rank_hand([C(7), C(7, 1), C(9), C(9, 1), C(4), C(4, 1), C(13)])
	check(tp[0] == 2 and tp[1] == 9 and tp[2] == 7 and tp[3] == 13, "three pairs: best two + best kicker")
	check(cat([C(7), C(7, 1), C(2), C(9, 1), C(11), C(13, 2), C(4, 3)]) == 1, "pair")
	check(cat([C(1), C(3, 1), C(5), C(9, 1), C(11), C(13, 2), C(8, 3)]) == 0, "high card")
	var a := Holdem.rank_hand([C(1), C(1, 1), C(13), C(9, 1), C(4, 2), C(3, 3), C(2)])
	var b := Holdem.rank_hand([C(1, 2), C(1, 3), C(12), C(9, 1), C(4, 2), C(3, 3), C(2)])
	check(Holdem.compare(a, b) > 0, "same pair: the king kicker wins")
	check(Holdem.compare(a, a) == 0, "equal hands tie")

	# ---------------- side pots
	var pots := Holdem.build_pots([
		{"contrib": 10, "folded": false},    # 0: all in for 10
		{"contrib": 30, "folded": true},     # 1: folded after 30
		{"contrib": 50, "folded": false},
		{"contrib": 50, "folded": false}])
	var total := 0
	for p in pots:
		total += int(p.amount)
	check(total == 140, "pots keep every chip (%d)" % total)
	check(pots[0].amount == 40 and pots[0].eligible == [0, 2, 3], "main pot: 4 x 10, the short stack can win it")
	check(pots[1].amount == 60 and not pots[1].eligible.has(0) and not pots[1].eligible.has(1), "side pot: folded and short players are out")

	# ---------------- strength + AI
	var he := Holdem.new(5)
	var aa := he.strength([C(1), C(1, 1)], [], 1, 400)
	var bad := he.strength([C(7), C(2, 1)], [], 1, 400)
	print("AA vs 1: %.2f   72o vs 1: %.2f" % [aa, bad])
	check(aa > 0.78 and aa < 0.92, "aces win about 85%% heads up (%.2f)" % aa)
	check(bad > 0.25 and bad < 0.42, "7-2 off wins about 34%% (%.2f)" % bad)
	var folds := 0
	for k in 50:
		if he.decide("tight", 0.2, 4, 10, true, "") == "fold":
			folds += 1
	check(folds >= 45, "tight AI folds junk to a bet (%d/50)" % folds)
	var raises := 0
	for k in 100:
		if he.decide("soft_you", 0.95, 2, 10, true, "you") == "raise":
			raises += 1
	check(raises == 0, "a crush never re-raises you")
	var bluffs := 0
	for k in 400:
		if he.decide("loose", 0.15, 0, 10, true, "") == "raise":
			bluffs += 1
	check(bluffs > 30 and bluffs < 160, "the takeover bluffer bets junk sometimes (%d/400)" % bluffs)

	# ---------------- table flow
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.auto_open_challenges = false
	await get_tree().process_frame
	await get_tree().process_frame
	Game.marrow = 30
	Game.rank = 1
	for i in Balance.BUILDINGS.size():
		Game.loyalty[i] = 0
	Game.loyalty[0] = 3     # broth: soft on you, peek
	Game.loyalty[1] = 2     # xylo: loose
	check(main.start_holdem(7), "Hold'em opens")
	var hp = main.holdem_page
	hp._set_buyin(99)
	check(hp.buyin == 10, "buy-in capped by rank 1 (10)")
	hp._set_buyin(6)
	hp.sit()
	check(Game.marrow == 24 and hp.players[0].stack - (0 if hp.players[0].contrib == 0 else 0) <= 60, "buy-in takes 6 Marrow for 60 chips")
	check(hp.players.size() == 4, "you, 2 managers, Cadavire")
	var blinds := 0
	for p in hp.players:
		blinds += int(p.contrib)
	check(blinds == Holdem.SMALL_BLIND + Holdem.BIG_BLIND, "blinds posted (1 + 2)")
	hp.flush()
	check(hp.players[0].hole.size() == 2, "two hole cards each")
	# play many hands with the AI playing for you; chips must be conserved
	hp.auto = true
	var stuck := 0
	var hands := 0
	for h in 40:
		hp.flush(800)
		if hp.state == "closed":
			hands += 1
			break
		if hp.state == "result":
			var chips := 0
			for p in hp.players:
				chips += int(p.stack)
			hands += 1
			hp.flags = {}
			hp.start_hand()
		elif hp.state == "busted":
			check(Game.marrow >= 6, "busting settles the stake (Marrow %d)" % Game.marrow)
			hp._set_buyin(3)
			hp.sit()              # rebuy
			hands += 1
		else:
			stuck += 1
			break
	print("hands played: %d, state %s, your chips %d" % [hands, hp.state, hp.players[0].stack])
	check(stuck == 0, "no hand gets stuck (state %s)" % hp.state)
	check(hands >= 10, "AI hands play through (%d)" % hands)
	hp.flush(800)
	if hp.state == "busted":
		hp._set_buyin(3)
		hp.sit()
	hp.flush(800)
	# a scripted hand: you act
	hp.auto = false
	if hp.state != "busted":
		if hp.state == "result":
			hp.start_hand()
		hp.flush(800)
		var guard := 0
		while hp.state == "you" and guard < 20:
			var to_call: int = hp.cur_bet - int(hp.players[0].bet)
			hp.you_act("call" if to_call <= 2 else "fold")
			hp.flush(800)
			guard += 1
		check(hp.state in ["result", "busted", "closed"], "your actions finish the hand (%s)" % hp.state)   # closed = you broke the house
	# chip conservation inside one hand
	if hp.state == "result":
		hp.start_hand()
		var before := 0
		for p in hp.players:
			before += int(p.stack) + int(p.contrib)
		hp.auto = true
		hp.flush(800)
		var after := 0
		for p in hp.players:
			after += int(p.stack)
		check(after == before - hp.last_rake + hp.chip_adjust, "a hand keeps every chip, minus the house cut (%d vs %d - %d + %d)" % [after, before, hp.last_rake, hp.chip_adjust])
		hp.auto = false
	# funny business
	if hp.state == "result":
		hp.force_next = "peek"
		hp.start_hand()
		hp.flush(hp.players.size() * 2 + 1)
		check(not hp.peek_card.is_empty(), "Soup Ghoul shows you one of Cadavire's cards")
		var cad: Dictionary = {}
		for p in hp.players:
			if p.id == "cadavire":
				cad = p
		check(hp.peek_card == cad.hole[0], "the peek card is really hers")
		hp.flags = {"hide": true}
		var s0: int = hp.players[0].stack
		if hp.state == "you" and hp.cur_bet - int(hp.players[0].bet) > 0:
			hp.you_act("fold")
			check(int(hp.players[0].stack) == s0 + 2, "the dog slides you 2 chips when you fold")
		hp.auto = true
		hp.flush(800)
		hp.auto = false
	# cash out
	if hp.state == "result":
		var chips_now: int = hp.players[0].stack
		var m0: int = Game.marrow
		hp.cash_out()
		check(Game.marrow == m0 + chips_now / 10, "cash out: 10 chips = 1 Marrow (%d -> %d)" % [m0, Game.marrow])
		check(not main.in_minigame, "cash out leaves the table")
	# ---------------- house cut, bankrolls, closed table
	check(Holdem.rake(10, false) == 0, "no flop, no cut")
	check(Holdem.rake(40, true) == 2 and Holdem.rake(200, true) == Holdem.RAKE_CAP, "5% of the pot, max 3")
	check(Holdem.rake(200, true, true) == 0, "no cut during Fever")
	if main.in_minigame:
		hp.state = "result"
		hp.cash_out()
	Game.table_away = {}
	Game.marrow = 50
	check(main.start_holdem(3), "Hold'em opens again")
	hp = main.holdem_page
	hp._set_buyin(2)
	hp.sit()
	hp.flush(800)
	check(int(hp.players[1].start) == Holdem.AI_MIN_STACK, "opponents sit with at least %d chips" % Holdem.AI_MIN_STACK)
	var mgr: Dictionary = hp.players[1]
	var mid: String = mgr.id
	hp._queue.clear()
	hp.state = "result"
	mgr.stack = 3
	hp._bankrolls()
	check(int(mgr.stack) == int(mgr.start) and int(mgr.reloads) == 0, "first time short: the manager reloads")
	mgr.stack = 3
	var n_before: int = hp.players.size()
	hp._bankrolls()
	check(hp.players.size() == n_before - 1 and Game.away_left(mid) > 1700.0, "second time: the manager goes home for 30 min")
	check(hp.seats.has(-1), "their chair is empty")
	check(not BlackjackPage_has(mid), "a manager who went home broke is not at blackjack either")
	hp.start_hand()
	hp.auto = true
	hp.flush(800)
	check(hp.state in ["result", "busted", "closed"], "the table plays on with one less (%s)" % hp.state)
	hp.auto = false
	var cad: Dictionary = {}
	for p in hp.players:
		if p.id == "cadavire":
			cad = p
	if hp.state == "busted":
		hp._set_buyin(2)
		hp.sit()
		hp.auto = true
		hp.flush(800)
		hp.auto = false
	cad.reloads = 0
	cad.stack = 1
	hp._queue.clear()
	hp.state = "result"
	var fev0: float = Game.fever
	hp._bankrolls()
	check(hp.state == "closed" and Game.away_left("cadavire") > 1700.0, "Cadavire broke: the table closes for 30 min")
	check(Game.fever > fev0 or Game.fever_active, "breaking the house adds Fever")
	var m1: int = Game.marrow
	var chips_left: int = hp.players[0].stack
	hp.cash_out()
	check(Game.marrow == m1 + chips_left / 10, "you can still cash out of a closed table")
	main.start_holdem(4)
	check(main.holdem_page.state == "closed" and not main.holdem_page._buy_row.visible, "the table stays closed (no buy-in) while she is away")
	main.holdem_page.cash_out()
	Game.table_away = {}
	print("HOLDEM TESTS: %d passed, %d failed" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)

func BlackjackPage_has(id: String) -> bool:
	for i in load("res://scripts/cards/blackjack_page.gd").pick_seats():
		if Balance.BUILDINGS[i].id == id:
			return true
	return false
