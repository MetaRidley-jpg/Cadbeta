extends VBoxContainer
## The card table: BLACKJACK. Cadavire deals. Up to 2 managers you have met sit in
## and cause "funny business" (data/card_table.json). The ONLY place Marrow is bet.
## Bets are capped by prestige rank (Game.max_bet()). Dialogue: Cadavire in slot 1,
## managers in slot 2 (manager box quips), as on every screen.

signal left_table

const DATA_PATH := "res://data/card_table.json"
const DEAL_STEP := 0.32          # seconds between dealt cards
const SLIDE := 0.24              # card slide time from the shoe
const EVENT_CHANCE := 0.4        # per hand: chance that ONE seated manager acts

var bj: Blackjack
var data: Dictionary = {}
var seats: Array = []            # building indices (max 2)
var table          # CardRoomView
var pal: Dictionary = UiTheme.NORMAL

# hands
var player: Array = []           # the hand you are playing now (hands[cur_hand] after a split)
var hands: Array = []            # after a split: [hand A, hand B]
var hand_bets: Array = []        # Marrow on each split hand
var cur_hand := 0
var rig := {}                    # debug: who -> cards to deal first (e.g. a pair for screenshots)
var dealer: Array = []
var seat_hands: Array = [[], []]
var seat_result: Array = ["", ""]
var hole_up := false             # dealer hole card face up for everyone
var peeked := false              # you saw the hole card (funny business)
var count_hint := ""             # "HIGH" / "LOW" next card (funny business)
var flags := {}                  # funny business effects for this hand: hide, audit, clout, skim
var event_seat := -1
var _vis: Array = []             # visual cards {who, i, t0}

var bet := 1
var stake := 0                   # Marrow on the table this hand (bet + double)
var state := "bet"               # bet, dealing, play, seats, dealer, result
var result_text := ""
var _queue: Array = []           # Callables run one per DEAL_STEP
var _q_t := 0.0
var _t := 0.0

var _marrow_lbl: Label
var _bet_lbl: Label
var _msg: Label
var _bet_row: HBoxContainer
var _act_row: HBoxContainer
var _end_row: HBoxContainer
var _btn := {}

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	add_theme_constant_override("separation", 6)
	# The card room: a 3D view from your seat (scripts/cards/card_room_view.gd).
	# Dialogue slot 2 (manager box) slides in over the top of it, like on every screen.
	table = preload("res://scripts/cards/card_room_view.gd").new()
	table.page = self
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.custom_minimum_size.y = 600
	add_child(table)
	var card := PanelContainer.new()
	card.theme_type_variation = "CardHi"
	add_child(card)
	var v := VBoxContainer.new()
	card.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_marrow_lbl = Label.new()
	_marrow_lbl.theme_type_variation = "TitleLabel"
	_marrow_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_marrow_lbl)
	_msg = Label.new()
	_msg.theme_type_variation = "AccentLabel"
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size.x = 300
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_msg)
	_bet_row = HBoxContainer.new()
	v.add_child(_bet_row)
	_btn.minus = _mk(_bet_row, "-", func(): _set_bet(bet - 1), 80)
	_bet_lbl = Label.new()
	_bet_lbl.theme_type_variation = "TitleLabel"
	_bet_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bet_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bet_row.add_child(_bet_lbl)
	_btn.plus = _mk(_bet_row, "+", func(): _set_bet(bet + 1), 80)
	_btn.max = _mk(_bet_row, "MAX", func(): _set_bet(Game.max_bet()), 100)
	_btn.deal = _mk(_bet_row, "DEAL", deal, 150)
	_act_row = HBoxContainer.new()
	v.add_child(_act_row)
	_btn.hit = _mk(_act_row, "HIT", hit, 0)
	_btn.stand = _mk(_act_row, "STAND", stand, 0)
	_btn.double = _mk(_act_row, "DOUBLE", double_down, 0)
	_btn.split = _mk(_act_row, "SPLIT", split, 0)
	_end_row = HBoxContainer.new()
	v.add_child(_end_row)
	_btn.next = _mk(_end_row, "NEXT HAND", func(): _to_bet(), 0)
	_btn.leave = _mk(_end_row, "LEAVE TABLE", leave, 0)
	_btn.leave.theme_type_variation = "GhostButton"
	_btn.fast = _mk(_end_row, "FAST", func(): Game.fast_table = not Game.fast_table; Game.save_game(); _refresh(), 150)
	_btn.fast.theme_type_variation = "GhostButton"
	Game.marrow_changed.connect(_refresh)

func _mk(parent: Node, text: String, cb: Callable, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 64)
	if w == 0:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func set_palette(p: Dictionary) -> void:
	pal = p

# =====================================================================
# Table life
# =====================================================================
## Sit down. seed_value >= 0 makes the shoe repeatable (tests, demos).
func open(seed_value := -1) -> void:
	bj = Blackjack.new(seed_value)
	seats = pick_seats()
	player.clear(); dealer.clear(); _vis.clear()
	seat_hands = [[], []]
	bet = clampi(bet, 1, maxi(1, Game.max_bet()))
	_to_bet()
	table.focus("seat")
	table.snap()
	Game.say.emit("bj_sit" if Game.max_bet() >= 1 else "bj_no_marrow", 3)
	if not seats.is_empty():
		var i: int = seats[randi() % seats.size()]
		_quip_line(i, "sit")

## Up to 2 managers you have met (loyalty >= 1), highest loyalty first.
static func pick_seats() -> Array:
	var met: Array = []
	for i in Balance.BUILDINGS.size():
		if Game.loyalty[i] >= 1 and Game.away_left(Balance.BUILDINGS[i].id) <= 0.0:   # not home broke from Hold'em
			met.append(i)
	met.sort_custom(func(a, b): return Game.loyalty[a] > Game.loyalty[b] or (Game.loyalty[a] == Game.loyalty[b] and a > b))
	return met.slice(0, 2)

func leave() -> void:
	if state != "bet" and state != "result":
		return          # mid-hand: your Marrow is already on the felt
	left_table.emit()

func _to_bet() -> void:
	state = "bet"
	if table:
		table.focus("seat")
	result_text = ""
	if bj and bj.needs_shuffle():
		bj.shuffle()
		_msg.text = "Fresh shoe."
	else:
		_msg.text = "Place your bet."
	bet = clampi(bet, 1, maxi(1, Game.max_bet()))
	_refresh()

func _set_bet(v: int) -> void:
	bet = clampi(v, 1, maxi(1, Game.max_bet()))
	_refresh()

func _refresh() -> void:
	if _marrow_lbl == null:
		return
	_marrow_lbl.text = "MARROW %d" % Game.marrow
	var cap: int = Game.MAX_BET_BY_RANK[clampi(Game.rank, 0, Game.MAX_BET_BY_RANK.size() - 1)]
	_bet_lbl.text = "BET %d  (max %d)" % [bet, cap]
	_bet_row.visible = state == "bet"
	_act_row.visible = state == "play"
	_end_row.visible = state == "bet" or state == "result"
	_btn.next.visible = state == "result"
	_btn.deal.disabled = Game.max_bet() < 1
	_btn.minus.disabled = bet <= 1
	_btn.plus.disabled = bet >= Game.max_bet()
	_btn.double.disabled = player.size() != 2 or Game.marrow < bet
	_btn.split.visible = hands.is_empty()
	_btn.split.disabled = not Blackjack.can_split(player) or Game.marrow < bet
	_btn.fast.text = "FAST: ON" if Game.fast_table else "FAST: OFF"
	if state == "bet" and Game.max_bet() < 1:
		_msg.text = "No Marrow. Fold a run to get some."
	table.queue_redraw()

# =====================================================================
# Dealing
# =====================================================================
func deal() -> void:
	if state != "bet" or not Game.start_wager(bet):
		return
	stake = bet
	player = []
	dealer.clear(); _vis.clear()
	hands = []
	hand_bets = []
	cur_hand = 0
	seat_hands = [[], []]
	seat_result = ["", ""]
	hole_up = false
	peeked = false
	count_hint = ""
	flags = {}
	event_seat = -1
	state = "dealing"
	table.focus("seat")
	_msg.text = ""
	Game.say.emit("bj_deal", 1)
	for round in 2:
		_queue.append(func(): _give("p"))
		for s in seats.size():
			var si := s
			_queue.append(func(): _give("s%d" % si))
		_queue.append(func(): _give("d"))
	_queue.append(_after_deal)
	_q_t = 0.0
	_refresh()

func _give(who: String) -> void:
	var c := bj.draw()
	var rk := "p" if who.begins_with("p") else who
	if rig.has(rk) and not rig[rk].is_empty():
		c = rig[rk].pop_front()
	var arr: Array
	match who:
		"p": arr = player
		"p0": arr = hands[0]
		"p1": arr = hands[1]
		"d": arr = dealer
		"s0": arr = seat_hands[0]
		"s1": arr = seat_hands[1]
	arr.append(c)
	Sfx.play("card", -4.0, 0.15)
	_vis.append({"who": who, "i": arr.size() - 1, "t0": _t})
	table.queue_redraw()

func _after_deal() -> void:
	_funny_business()
	# dealer peeks for blackjack with an ace or ten up
	if Blackjack.is_blackjack(dealer) or Blackjack.is_blackjack(player):
		_dealer_turn(true)
		return
	state = "play"
	table.focus("hand")
	_msg.text = "%d. Hit or stand?" % Blackjack.total(player)
	_refresh()

## Who your current hand is in the room view: "p", or "p0"/"p1" after a split.
func _pwho() -> String:
	return "p" if hands.is_empty() else "p%d" % cur_hand

func hit() -> void:
	if state != "play":
		return
	_give(_pwho())
	if Blackjack.is_bust(player):
		Game.say.emit("bj_bust", 2)
		_end_player_turn()
	elif Blackjack.total(player) == 21:
		_end_player_turn()
	else:
		_msg.text = "%d." % Blackjack.total(player)
	_refresh()

func stand() -> void:
	if state == "play":
		_end_player_turn()

func double_down() -> void:
	if state != "play" or player.size() != 2 or Game.marrow < bet:
		return
	Game.marrow -= bet
	Game.marrow_changed.emit()
	stake += bet
	if not hands.is_empty():
		hand_bets[cur_hand] = int(hand_bets[cur_hand]) + bet
	_give(_pwho())
	_msg.text = "Doubled: %d on the felt." % stake
	if Blackjack.is_bust(player):
		Game.say.emit("bj_bust", 2)
	_end_player_turn()

## SPLIT: the pair becomes two hands with one bet each. Each hand gets a second card.
## Split aces get one card each and stop.
func split() -> void:
	if state != "play" or not hands.is_empty() or not Blackjack.can_split(player) or Game.marrow < bet:
		return
	Game.marrow -= bet
	Game.marrow_changed.emit()
	stake += bet
	hands = [[player[0]], [player[1]]]
	hand_bets = [bet, bet]
	cur_hand = 0
	for c in _vis:                 # the two cards slide apart
		if c.who == "p":
			c.who = "p%d" % int(c.i)
			c.i = 0
			c.t0 = _t
	player = hands[0]
	Game.say.emit("bj_split", 2)
	_give("p0")
	if int(hands[0][0].r) == 1:
		_queue.append(func(): _give("p1"))
		_queue.append(_end_player_turn_all)
		state = "seats"
		_msg.text = "Split aces: one card each."
	else:
		_msg.text = "Hand 1: %d." % Blackjack.total(player)
		if Blackjack.total(player) == 21:
			_end_player_turn()
	_refresh()

func _end_player_turn() -> void:
	if not hands.is_empty() and cur_hand == 0:
		cur_hand = 1                  # on to the second split hand
		player = hands[1]
		_give("p1")
		_msg.text = "Hand 2: %d." % Blackjack.total(player)
		state = "play"
		if Blackjack.total(player) == 21:
			_end_player_turn()
		_refresh()
		return
	_end_player_turn_all()

func _end_player_turn_all() -> void:
	state = "seats"
	_refresh()
	for s in seats.size():
		var si := s
		var bold: bool = String(data.get(Balance.BUILDINGS[seats[si]].id, {}).get("event", "")) in ["burn", "bottom", "skim"]
		_queue.append(func(): _seat_play(si, bold))
	_queue.append(func(): _dealer_turn(false))

func _seat_play(si: int, bold: bool) -> void:
	if Blackjack.seat_should_hit(seat_hands[si], dealer[0], bold) and seat_hands[si].size() < 6:
		_give("s%d" % si)
		_queue.push_front(func(): _seat_play(si, bold))

func _dealer_turn(instant: bool) -> void:
	state = "dealer"
	table.focus("dealer")
	hole_up = true
	table.queue_redraw()
	var all_out := Blackjack.is_bust(player) or Blackjack.is_blackjack(player)
	if not hands.is_empty():
		all_out = Blackjack.is_bust(hands[0]) and Blackjack.is_bust(hands[1])
	if not instant and not all_out:
		_queue.append(_dealer_hit)
	else:
		_queue.append(_settle)

func _dealer_hit() -> void:
	if Blackjack.dealer_should_hit(dealer):
		_give("d")
		_queue.push_front(_dealer_hit)
	else:
		_queue.push_front(_settle)

# =====================================================================
# Funny business
# =====================================================================
const EVENTS := ["peek", "burn", "bottom", "count", "hide", "audit", "clout", "skim", "snack"]

var force_next := ""      # debug/demo: the next hand's event
var auto := false         # debug/demo: the table plays itself (deal, hit < 17, stand)
var _auto_t := 0.0

func _funny_business(force := "") -> void:
	if seats.is_empty():
		return
	if force == "" and force_next != "":
		force = force_next
		force_next = ""
	if force == "" and randf() > EVENT_CHANCE:
		return
	var si := randi() % seats.size()
	if force != "":
		for k in seats.size():
			if String(data.get(Balance.BUILDINGS[seats[k]].id, {}).get("event", "")) == force:
				si = k
	var i: int = seats[si]
	var ev := force if force != "" else String(data.get(Balance.BUILDINGS[i].id, {}).get("event", "snack"))
	event_seat = si
	var hint := ""
	match ev:
		"peek":
			peeked = true
			Game.say.emit("bj_peeked", 3)
		"burn":
			bj.burn()
		"bottom":
			bj.bottom_swap()
		"count":
			var nv := Blackjack.card_value(bj.peek_next())
			count_hint = "HIGH" if nv >= 10 or int(bj.peek_next().r) == 1 else ("LOW" if nv <= 6 else "MIDDLE")
			hint = count_hint.to_lower()
		"hide", "audit", "clout", "skim":
			flags[ev] = true
	_quip_line(i, "lines", hint)
	table.queue_redraw()

## Test / demo hook: run one event now.
func force_event(ev: String) -> void:
	_funny_business(ev)

func _quip_line(i: int, key: String, hint := "") -> void:
	var lines: Array = data.get(Balance.BUILDINGS[i].id, {}).get(key, [])
	if lines.is_empty():
		return
	var line := String(lines[randi() % lines.size()]).replace("{hint}", hint)
	var mb = get_tree().get_first_node_in_group("manager_box")
	if mb:
		mb.quip(i, line)
	var si := seats.find(i)
	if si >= 0 and table:
		table.focus("seat%d" % si, 1.5 if Game.fast_table else 3.0)      # the camera turns to whoever talks

# =====================================================================
# Settle
# =====================================================================
func _settle() -> void:
	var r := Blackjack.settle(player, dealer, stake)
	var busted_bets := stake if r.result == "bust" else 0
	var split_names: Array = []
	if not hands.is_empty():
		r = {"result": "split", "back": 0}
		busted_bets = 0
		var wins := 0
		for k in 2:
			var hr := Blackjack.settle(hands[k], dealer, int(hand_bets[k]), true)
			r.back = int(r.back) + int(hr.back)
			if hr.result == "bust":
				busted_bets += int(hand_bets[k])
			if int(hr.back) > int(hand_bets[k]):
				wins += 1
				Challenges.bump("bj_wins")
			split_names.append({"win": "WIN", "dealer_bust": "WIN", "push": "PUSH", "lose": "LOSE", "bust": "BUST"}.get(hr.result, "?"))
		r.result = "split_win" if int(r.back) > stake else ("split_push" if int(r.back) == stake else "split_lose")
	var back: int = r.back
	var extra: Array = []
	var win: bool = back > stake
	if flags.get("audit", false) and busted_bets > 0:
		var refund := int(ceil(busted_bets * 0.5))
		back += refund
		extra.append("Audit: +%d back" % refund)
	if flags.get("hide", false) and back < stake:
		back += 1
		extra.append("The dog found 1 under the table")
	if flags.get("clout", false) and win:
		back += 1
		extra.append("Chat tip +1")
	if flags.get("skim", false) and win:
		if randf() < 0.5:
			Game.say.emit("bj_skim_caught", 4)
			extra.append("Skim caught: no loss")
		else:
			back -= 1
			extra.append("Skimmed -1")
	for s in seats.size():
		seat_result[s] = String(Blackjack.settle(seat_hands[s], dealer, 1).result)
	var txt := Game.settle_wager(stake, back)
	Sfx.play("win" if back > stake else ("chips" if back == stake else "lose"), -4.0, 0.0)
	match String(r.result):
		"blackjack":
			Game.say.emit("bj_player_bj", 4)
			Challenges.bump("bj_wins")
		"win":
			Game.say.emit("bj_win", 3)
			Challenges.bump("bj_wins")
		"dealer_bust":
			Game.say.emit("bj_dealer_bust", 3)
			Challenges.bump("bj_wins")
		"push":
			Game.say.emit("bj_push", 2)
		"lose":
			Game.say.emit("bj_lose", 2)
		"split_win":
			Game.say.emit("bj_win", 3)
		"split_push":
			Game.say.emit("bj_push", 2)
		"split_lose":
			Game.say.emit("bj_lose", 2)
	var names := {"blackjack": "BLACKJACK!", "win": "YOU WIN", "dealer_bust": "DEALER BUSTS", "push": "PUSH",
		"lose": "DEALER WINS", "bust": "BUST"}
	result_text = String(names.get(r.result, r.result))
	if not split_names.is_empty():
		result_text = " / ".join(split_names)
	table.focus("result")
	_msg.text = txt + ("   (" + ", ".join(extra) + ")" if not extra.is_empty() else "")
	state = "result"
	_refresh()

func _process(delta: float) -> void:
	_t += delta
	if auto:
		_auto_t += delta
		if state == "bet" and _auto_t > 0.8:
			_auto_t = 0.0
			deal()
		elif state == "play" and _auto_t > 2.6:
			_auto_t = 0.0
			if hands.is_empty() and Blackjack.can_split(player) and int(player[0].r) in [1, 8] and Game.marrow >= bet:
				split()
			elif Blackjack.total(player) < 17:
				hit()
			else:
				stand()
		elif state != "play" and state != "bet":
			if state == "dealing":
				_auto_t = 0.0
	if not _queue.is_empty():
		_q_t -= delta
		if _q_t <= 0.0:
			_q_t = DEAL_STEP * (0.6 if Game.fast_table else 1.0)
			var f: Callable = _queue.pop_front()
			f.call()
			_refresh()
	if is_visible_in_tree():
		table.queue_redraw()

## Tests: run all queued steps now.
func flush() -> void:
	var guard := 0
	while not _queue.is_empty() and guard < 200:
		var f: Callable = _queue.pop_front()
		f.call()
		guard += 1
	_refresh()

# =====================================================================
# Drawing
# =====================================================================
func _hand_of(who: String) -> Array:
	match who:
		"p": return player if hands.is_empty() else []
		"p0": return hands[0] if not hands.is_empty() else []
		"p1": return hands[1] if not hands.is_empty() else []
		"d": return dealer
		"s0": return seat_hands[0]
		"s1": return seat_hands[1]
	return []

func _total_text(hand: Array) -> String:
	var t := Blackjack.total(hand)
	if Blackjack.is_blackjack(hand):
		return "BLACKJACK"
	if t > 21:
		return "%d BUST" % t
	return ("soft %d" % t) if Blackjack.is_soft(hand) else str(t)

# =====================================================================
# Drawing hooks for the 3D card room (CardRoomView calls these)
# =====================================================================
func draw_felt(v) -> void:
	var tex: Texture2D = v.atlas.get_texture()
	var shoe: Vector3 = v.shoe_spot()
	for k in 5:
		v._card_quad(tex, {}, shoe + Vector3(0, 0.006 * k, -0.002 * k), 0.0)
	for c in _vis:
		var who: String = c.who
		var hand: Array = _hand_of(who)
		if c.i >= hand.size():
			continue
		var target: Vector3 = v.card_spot(who, c.i, hand.size())
		var pos: Vector3 = v.fly(shoe, target, (_t - float(c.t0)) / SLIDE)
		var face_up: bool = not (who == "d" and c.i == 1 and not hole_up)
		var yaw := 0.0 if who in ["p", "d", "p0", "p1"] else (PI * 0.5 if who == "s0" else -PI * 0.5)
		v._card_quad(tex, hand[c.i] if face_up else {}, pos, yaw)
	if stake > 0 and state != "bet":
		v._chips(Vector3(-0.32, v.TOP_Y, 0.42) if hands.is_empty() else Vector3(0.0, v.TOP_Y, 0.52), stake)

func draw_labels(v) -> void:
	var CARD: Vector2 = v.CARD
	if not hands.is_empty():
		for k in 2:
			var here: bool = k == cur_hand and state == "play"
			var col := Color("ffe14a") if here else Color.WHITE
			var at: Vector2 = v._p2(v.hand_spot("p%d" % k) + Vector3(0, 0, CARD.y * 0.5 + 0.05))
			v._text(_total_text(hands[k]) + ("  <" if here else ""), at, 20, col)
	elif not player.is_empty():
		v._text(_total_text(player), v._p2(v.hand_spot("p") + Vector3(0, 0, CARD.y * 0.5 + 0.05)), 22, Color.WHITE)
	if not dealer.is_empty():
		var dt: String = _total_text(dealer) if hole_up else str(Blackjack.card_value(dealer[0]) if int(dealer[0].r) != 1 else 11) + " + ?"
		v._text(dt, v._p2(v.hand_spot("d") + Vector3(0, 0, CARD.y * 0.5 + 0.05)), 17, Color.WHITE)
		if peeked and not hole_up and dealer.size() > 1:
			v._text("PEEK: " + Blackjack.rank_text(dealer[1]), v._p2(v.card_spot("d", 1, dealer.size()) + Vector3(0, 0.2, 0)), 18, Color("ffe14a"))
	for si in 2:
		var head: Vector2 = v.seat_head(si)
		if si < seats.size():
			v._text(String(Balance.BUILDINGS[seats[si]].manager), head, 13, Color(1, 1, 1, 0.9))
			if event_seat == si and state != "bet":
				v._text("!", head + Vector2(0, -26), 30, Color("ffe14a"))
			if seat_result[si] != "" and state == "result":
				v._text(String(seat_result[si]).to_upper().replace("_", " "), v._p2(v.hand_spot("s%d" % si) + Vector3(0, 0, 0.14)), 13, Color("ffe14a"))
		else:
			v._text("EMPTY SEAT", head + Vector2(0, 40), 12, Color(1, 1, 1, 0.45))
	v._text("%d" % (bj.shoe.size() if bj else 0), v._p2(v.shoe_spot() + Vector3(0, 0, 0.12)), 12, Color(1, 1, 1, 0.75))
	if count_hint != "":
		v._text("NEXT: " + count_hint, v._p2(v.shoe_spot() + Vector3(0, 0.12, 0)), 15, Color("ffe14a"))
	if result_text != "" and state == "result":
		v.banner(result_text)
