extends Node
## Card table (blackjack) rules + table flow. Run with -- --fresh.

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

func _ready() -> void:
	Game.autosave_enabled = false
	Challenges.enabled = false

	# ---------------- rules
	check(Blackjack.total([C(1), C(13)]) == 21 and Blackjack.is_blackjack([C(1), C(13)]), "A+K = blackjack")
	check(Blackjack.total([C(1), C(1), C(9)]) == 21, "A+A+9 = 21")
	check(Blackjack.total([C(1), C(6)]) == 17 and Blackjack.is_soft([C(1), C(6)]), "A+6 = soft 17")
	check(Blackjack.total([C(1), C(6), C(10)]) == 17 and not Blackjack.is_soft([C(1), C(6), C(10)]), "A+6+10 = hard 17")
	check(Blackjack.is_bust([C(10), C(9), C(5)]), "24 busts")
	check(not Blackjack.dealer_should_hit([C(1), C(6)]), "S17: dealer stands on soft 17")
	check(Blackjack.dealer_should_hit([C(10), C(6)]), "dealer hits 16")
	var bjr := Blackjack.settle([C(1), C(12)], [C(10), C(9)], 5)
	check(bjr.result == "blackjack" and bjr.back == 5 + 8, "blackjack pays 3:2 rounded up (bet 5 -> back 13, got %d)" % bjr.back)
	check(Blackjack.settle([C(10), C(9)], [C(10), C(8)], 4).back == 8, "win pays 1:1")
	check(Blackjack.settle([C(10), C(8)], [C(10), C(8)], 4).back == 4, "push returns the bet")
	check(Blackjack.settle([C(10), C(8), C(9)], [C(10), C(6), C(9)], 4).back == 0, "player bust loses even if the dealer busts")
	check(Blackjack.settle([C(10), C(8)], [C(10), C(6), C(9)], 4).result == "dealer_bust", "dealer bust")
	check(Blackjack.settle([C(10), C(9)], [C(1), C(13)], 4).back == 0, "dealer blackjack beats 19")
	check(Blackjack.settle([C(1), C(10)], [C(1), C(13)], 4).result == "push", "blackjack vs blackjack pushes")
	var shoe := Blackjack.new(1)
	check(shoe.shoe.size() == 208, "4-deck shoe (208 cards)")
	var n0 := shoe.shoe.size()
	shoe.burn()
	check(shoe.shoe.size() == n0 - 1, "burn removes the top card")
	var top := shoe.peek_next()
	shoe.bottom_swap()
	check(shoe.shoe.size() == n0 - 1, "bottom deal keeps the card count")
	# house edge sanity: the simple seat AI should lose a little over many hands
	var sim := Blackjack.new(7)
	var net := 0
	for k in 4000:
		if sim.needs_shuffle():
			sim.shuffle()
		var p := [sim.draw(), sim.draw()]
		var d := [sim.draw(), sim.draw()]
		while Blackjack.seat_should_hit(p, d[0], false):
			p.append(sim.draw())
		if not Blackjack.is_bust(p):
			while Blackjack.dealer_should_hit(d):
				d.append(sim.draw())
		net += int(Blackjack.settle(p, d, 2).back) - 2
	print("seat AI over 4000 hands at 2 Marrow: net %d (%.1f%% of stake)" % [net, 100.0 * net / 8000.0])
	check(net < 0 and net > -1600, "house keeps an edge, but not a brutal one")

	# ---------------- table flow
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.auto_open_challenges = false
	await get_tree().process_frame
	await get_tree().process_frame
	var page = main.blackjack_page
	Game.marrow = 0
	check(main.start_cards(5), "table opens")
	check(page.visible and main.in_minigame, "table page shown in match mode")
	check(page._btn.deal.disabled, "no Marrow: DEAL is off")
	page.deal()
	check(page.state == "bet", "no Marrow: cannot deal")
	Game.marrow = 40
	Game.rank = 0
	page._set_bet(99)
	check(page.bet == 5, "bet capped by rank 0 (max 5), got %d" % page.bet)
	Game.rank = 2
	page._set_bet(99)
	check(page.bet == 25, "rank 2 cap = 25")
	page._set_bet(4)
	page.deal()
	page.flush()
	check(Game.marrow == 36, "the bet leaves your Marrow when the hand starts")
	check(page.player.size() == 2 and page.dealer.size() == 2, "two cards each")
	page.leave()
	check(main.in_minigame, "cannot leave mid-hand")
	if page.state == "play":
		page.stand()
		page.flush()
	check(page.state == "result", "hand settles (%s)" % page.state)
	var r := Blackjack.settle(page.player, page.dealer, 4)
	check(Game.marrow == 36 + int(r.back), "payout matches the rules (%d vs %d)" % [Game.marrow, 36 + int(r.back)])
	# double
	var tries := 0
	while tries < 30:
		tries += 1
		page._to_bet()
		page._set_bet(3)
		page.deal()
		page.flush()
		if page.state == "play":
			break
		page.flush()
	var before: int = Game.marrow
	page.double_down()
	page.flush()
	check(page.stake == 6 and page.player.size() == 3, "double: stake x2 and exactly one card")
	check(page.state == "result", "double ends your turn")
	var rd := Blackjack.settle(page.player, page.dealer, 6)
	check(Game.marrow == before - 3 + int(rd.back), "double pays on the doubled stake")

	# ---------------- funny business
	for i in Balance.BUILDINGS.size():
		Game.loyalty[i] = 0
	Game.loyalty[0] = 2      # broth (peek)
	Game.loyalty[4] = 3      # foundry (audit)
	var seats: Array = page.pick_seats()
	check(seats == [4, 0], "seats: met managers, highest loyalty first (%s)" % [seats])
	page.open(11)
	check(page.seats.size() == 2, "two managers sit in")
	page._set_bet(2)
	page.deal()
	page.flush()
	page.force_event("peek")
	check(page.peeked, "Soup Ghoul tips the hole card (peek)")
	# audit: bust refunds half
	page.flags = {"audit": true}
	page.player = [C(10), C(9), C(8)]
	page.dealer = [C(10), C(7)]
	page.stake = 4
	var m0: int = Game.marrow
	page._settle()
	check(Game.marrow == m0 + 2, "audit: a bust refunds half the stake (got %+d)" % (Game.marrow - m0))
	page.flags = {"hide": true}
	page.player = [C(10), C(7)]
	page.dealer = [C(10), C(9)]
	m0 = Game.marrow
	page._settle()
	check(Game.marrow == m0 + 1, "the dog finds 1 Marrow under the table on a loss")
	page.flags = {"clout": true}
	page.player = [C(10), C(9)]
	page.dealer = [C(10), C(7)]
	m0 = Game.marrow
	page._settle()
	check(Game.marrow == m0 + 9, "clout: +1 on a win (4 stake -> 8 back + 1)")
	page.state = "play"
	var nshoe: int = page.bj.shoe.size()
	Game.loyalty[1] = 5      # xylo (burn) — sit him
	page.seats = [1]
	page.force_event("burn")
	check(page.bj.shoe.size() == nshoe - 1, "the Lich burns a card")
	Game.loyalty[2] = 5      # crusher (count)
	page.seats = [2]
	page.force_event("count")
	check(page.count_hint in ["HIGH", "LOW", "MIDDLE"], "Hank calls the next card (%s)" % page.count_hint)
	# ---------------- camera (Poker Night style)
	var view = page.table
	view.focus("seat")
	view._shot_t = 0.0
	view.shot = "seat"
	page._quip_line(page.seats[0], "lines")
	check(view.shot == "seat0", "the camera turns to the manager who talks (%s)" % view.shot)
	view._process(3.5)
	check(view.shot == view._base_shot, "after the line it goes back (%s)" % view.shot)
	page._dealer_turn(false)
	check(view._base_shot == "dealer", "dealer's turn: camera on Cadavire")
	page._queue.clear()
	view.size = Vector2(700, 600)
	view.snap()
	view._setup_cam()
	var pp: Vector3 = view.project(view.hand_spot("p"))
	var pd: Vector3 = view.project(view.hand_spot("d"))
	check(pp.z > 0.0 and pd.z > pp.z, "your cards are nearer than the dealer's")
	view.focus("seat")
	view.snap()
	view._setup_cam()
	var near: Vector3 = view.project(view.hand_spot("p"))
	check(near.y > pd.y - 1000.0 and near.x > 0.0 and near.x < 700.0, "your cards are on screen in the seat shot")
	# ---------------- split
	check(Blackjack.can_split([C(8), C(8, 1)]) and Blackjack.can_split([C(10), C(13)]) and not Blackjack.can_split([C(9), C(10)]), "pairs (and any two 10s) can split")
	check(Blackjack.settle([C(1), C(10)], [C(10), C(9)], 4, true).result == "win", "a split 21 is not a blackjack (pays 1:1)")
	page._queue.clear()
	page.flush()
	page.state = "result"
	page._to_bet()
	Game.marrow = 40
	page.seats = []
	page._set_bet(2)
	page.rig = {"p": [C(8), C(8, 2)], "d": [C(10, 1), C(7, 3)]}
	var m_before: int = Game.marrow
	page.deal()
	page.flush()
	check(page.state == "play" and Blackjack.can_split(page.player), "rigged pair of 8s (%s)" % page.state)
	page.split()
	check(page.hands.size() == 2 and page.stake == 4 and Game.marrow == m_before - 4, "split puts a second bet down")
	check(page.hands[0].size() == 2 and page.hands[1].size() == 1 and page.cur_hand == 0, "hand 1 gets its second card first")
	page.stand()
	check(page.cur_hand == 1 and page.hands[1].size() == 2 and page.state == "play", "stand moves on to hand 2")
	page.stand()
	page.flush()
	check(page.state == "result" and page.result_text.contains("/"), "both hands settle (%s)" % page.result_text)
	var back_ok := true
	var expect := 0
	for k in 2:
		expect += int(Blackjack.settle(page.hands[k], page.dealer, 2, true).back)
	check(Game.marrow == m_before - 4 + expect, "split pays each hand on its own (%d vs %d)" % [Game.marrow, m_before - 4 + expect])
	# split aces: one card each, then the dealer
	page._to_bet()
	page.rig = {"p": [C(1), C(1, 1)], "d": [C(10, 1), C(7, 3)]}
	page.deal()
	page.flush()
	if page.state == "play":
		page.split()
		page.flush()
		check(page.hands[0].size() == 2 and page.hands[1].size() == 2 and page.state == "result", "split aces: one card each, no more hits (%s)" % page.state)
	else:
		check(false, "rigged aces should not be a blackjack hand (%s)" % page.state)
	page.rig = {}
	# fast table
	var f0: bool = Game.fast_table
	page._btn.fast.pressed.emit()
	check(Game.fast_table != f0 and page._btn.fast.text.begins_with("FAST"), "FAST toggle")
	Game.fast_table = false
	page.flush()
	page.state = "result"
	page.leave()
	check(not main.in_minigame and main.get_node("%NavBar").visible, "LEAVE TABLE returns to the game")

	print("CARD TESTS: %d passed, %d failed" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)
