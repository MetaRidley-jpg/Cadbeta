extends VBoxContainer
## The card table: TEXAS HOLD'EM (fixed limit). You, Cadavire (she PLAYS here, across
## the table) and up to 2 managers you have met. Marrow only: you buy in for Marrow
## (capped by rank), play with chips (1 Marrow = 10 chips), and cash out between hands.
## Managers play to their motive (tight, loose bluffer, soft on their crush, wild) and
## cause funny business (data/card_table.json). Same 3D room + camera as blackjack.

signal left_table

const DATA_PATH := "res://data/card_table.json"
const STEP := 0.7             # seconds between AI actions / dealt cards
const STEP_FAST := 0.28       # Fast table
const SLIDE := 0.24
const EVENT_CHANCE := 0.3
const STYLE_BY_EVENT := {"peek": "soft_you", "burn": "loose", "bottom": "loose", "skim": "loose",
	"count": "tight", "clout": "tight", "hide": "soft_her", "audit": "wild", "snack": "wild"}

var he: Holdem
var data: Dictionary = {}
var seats: Array = []          # building indices (for the room view: chairs + images)
var table                      # CardRoomView
var players: Array = []        # see _make_player()
var board: Array = []
var street := ""               # preflop, flop, turn, river
var state := "buyin"           # buyin, dealing, ai, you, result, busted, closed
var last_rake := 0             # house cut from the last pot
var jar := 0                   # house cut this sitting
var chip_adjust := 0           # chips added (reloads) or taken home at the end of the last hand
var button := 0
var cur_bet := 0               # highest bet this round
var bets_made := 0             # bet + raises this round
var buyin := 5                 # Marrow
var stake := 0                 # Marrow you have at risk at this table (settled on cash out)
var result_text := ""
var flags := {}
var peek_card := {}
var tell_text := ""
var event_seat := -1
var auto := false              # demo: you play with the Cadavire AI
var felt_path := "res://art/table/felt_holdem.png"   # the room view uses this felt
var force_next := ""
var _queue: Array = []
var _q_t := 0.0
var _t := 0.0
var _vis: Array = []           # {who, i, t0}
var _strength_cache := {}

var _marrow_lbl: Label
var _msg: Label
var _buy_row: HBoxContainer
var _act_row: HBoxContainer
var _end_row: HBoxContainer
var _buy_lbl: Label
var _btn := {}

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	add_theme_constant_override("separation", 6)
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
	_msg.custom_minimum_size.x = 330
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_msg)
	_buy_row = HBoxContainer.new()
	v.add_child(_buy_row)
	_btn.minus = _mk(_buy_row, "-", func(): _set_buyin(buyin - 1), 80)
	_buy_lbl = Label.new()
	_buy_lbl.theme_type_variation = "TitleLabel"
	_buy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buy_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_row.add_child(_buy_lbl)
	_btn.plus = _mk(_buy_row, "+", func(): _set_buyin(buyin + 1), 80)
	_btn.sit = _mk(_buy_row, "BUY IN", sit, 170)
	_act_row = HBoxContainer.new()
	v.add_child(_act_row)
	_btn.fold = _mk(_act_row, "FOLD", func(): you_act("fold"), 0)
	_btn.call = _mk(_act_row, "CHECK", func(): you_act("call"), 0)
	_btn.raise = _mk(_act_row, "BET", func(): you_act("raise"), 0)
	_end_row = HBoxContainer.new()
	v.add_child(_end_row)
	_btn.next = _mk(_end_row, "NEXT HAND", start_hand, 0)
	_btn.cash = _mk(_end_row, "CASH OUT", cash_out, 0)
	_btn.cash.theme_type_variation = "GhostButton"
	_btn.fast = _mk(_end_row, "FAST", toggle_fast, 150)
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

func set_palette(_p: Dictionary) -> void:
	pass

func toggle_fast() -> void:
	Game.fast_table = not Game.fast_table
	Game.save_game()
	_refresh()

func _step() -> float:
	return STEP_FAST if Game.fast_table else STEP

# =====================================================================
# Table life
# =====================================================================
func open(seed_value := -1) -> void:
	he = Holdem.new(seed_value)
	seats = BlackjackPage_pick_seats()
	players.clear()
	board.clear()
	_vis.clear()
	stake = 0
	jar = 0
	last_rake = 0
	state = "buyin"
	result_text = ""
	buyin = clampi(buyin, 1, maxi(1, Game.max_bet()))
	table.focus("seat")
	table.snap()
	if Game.away_left("cadavire") > 0.0:
		state = "closed"
		result_text = "TABLE CLOSED"
		Game.say.emit("he_closed", 3)
		_refresh()
		return
	_msg.text = "Buy in to sit down." if Game.max_bet() >= 1 else "No Marrow. Fold a run to get some."
	Game.say.emit("he_sit" if Game.max_bet() >= 1 else "bj_no_marrow", 3)
	_refresh()

## Minutes left, as text, for a player who went home.
static func away_text(id: String) -> String:
	return "%d min" % int(ceil(Game.away_left(id) / 60.0))

## Same seating rule as blackjack: up to 2 met managers, highest loyalty first.
static func BlackjackPage_pick_seats() -> Array:
	var met: Array = []
	for i in Balance.BUILDINGS.size():
		if Game.loyalty[i] >= 1 and Game.away_left(Balance.BUILDINGS[i].id) <= 0.0:
			met.append(i)
	met.sort_custom(func(a, b): return Game.loyalty[a] > Game.loyalty[b] or (Game.loyalty[a] == Game.loyalty[b] and a > b))
	return met.slice(0, 2)

func _set_buyin(v: int) -> void:
	buyin = clampi(v, 1, maxi(1, Game.max_bet()))
	_refresh()

func _make_player(id: String, name: String, who: String, style: String, bidx: int, chips: int) -> Dictionary:
	return {"id": id, "name": name, "who": who, "style": style, "bidx": bidx, "stack": chips,
		"hole": [], "folded": false, "allin": false, "bet": 0, "contrib": 0, "acted": false,
		"last": "", "score": [], "start": chips, "reloads": Holdem.AI_RELOADS}

func sit() -> void:
	if state != "buyin" and state != "busted":
		return
	if not Game.start_wager(buyin):
		return
	stake = buyin
	var chips := buyin * Holdem.CHIPS_PER_MARROW
	if players.is_empty():
		var ai_chips := maxi(chips, Holdem.AI_MIN_STACK)
		players.append(_make_player("you", "You", "p", "", -1, chips))
		if seats.size() > 0:
			players.append(_make_seat(0, ai_chips))
		players.append(_make_player("cadavire", "Cadavire", "d", "cadavire", -1, ai_chips))
		if seats.size() > 1:
			players.append(_make_seat(1, ai_chips))
		button = randi() % players.size()
	else:
		players[0].stack = chips
	start_hand()

func _make_seat(si: int, chips: int) -> Dictionary:
	var b: int = seats[si]
	var id: String = Balance.BUILDINGS[b].id
	var ev := String(data.get(id, {}).get("event", "snack"))
	return _make_player(id, String(Balance.BUILDINGS[b].manager), "s%d" % si, STYLE_BY_EVENT.get(ev, "wild"), b, chips)

func cash_out() -> void:
	if state in ["result", "buyin", "busted", "closed"]:
		if stake > 0:
			var back := int(players[0].stack) / Holdem.CHIPS_PER_MARROW if not players.is_empty() else 0
			Game.settle_wager(stake, back)
			stake = 0
		left_table.emit()

# =====================================================================
# A hand
# =====================================================================
func start_hand() -> void:
	if players.is_empty() or int(players[0].stack) <= 0:
		return
	he.new_deck()
	board.clear()
	_vis.clear()
	_strength_cache.clear()
	flags = {}
	peek_card = {}
	tell_text = ""
	event_seat = -1
	result_text = ""
	last_rake = 0
	chip_adjust = 0
	for p in players:
		p.hole = []
		p.folded = false
		p.allin = false
		p.bet = 0
		p.contrib = 0
		p.acted = false
		p.last = ""
		p.score = []
	button = (button + 1) % players.size()
	street = "preflop"
	cur_bet = 0
	bets_made = 0
	state = "dealing"
	table.focus("seat")
	_put(_idx(button + 1), Holdem.SMALL_BLIND, "SB")
	_put(_idx(button + 2), Holdem.BIG_BLIND, "BB")
	cur_bet = Holdem.BIG_BLIND
	bets_made = 1
	for r in 2:
		for k in players.size():
			var pi := _idx(button + 1 + k)
			_queue.append(func(): _deal_hole(pi))
	_queue.append(_after_deal)
	_q_t = 0.0
	_msg.text = ""
	_refresh()

func _idx(i: int) -> int:
	return posmod(i, players.size())

func _put(pi: int, amount: int, label := "") -> void:
	var p: Dictionary = players[pi]
	var a := mini(amount, int(p.stack))
	if a > 0:
		Sfx.play("chips", -8.0, 0.12)
	p.stack -= a
	p.bet += a
	p.contrib += a
	if int(p.stack) == 0:
		p.allin = true
	if label != "":
		p.last = label

func _deal_hole(pi: int) -> void:
	var p: Dictionary = players[pi]
	p.hole.append(he.draw())
	Sfx.play("card", -4.0, 0.15)
	_vis.append({"who": p.who, "i": p.hole.size() - 1, "t0": _t, "pi": pi})

func _after_deal() -> void:
	_funny_business()
	_begin_round(_idx(button + 3) if players.size() > 2 else _idx(button + 1))

func _begin_round(first: int) -> void:
	for p in players:
		p.acted = false
	_turn_from(first)

func _turn_from(start: int) -> void:
	if _live_count() <= 1:
		_queue.append(_award_uncontested)
		return
	for k in players.size():
		var pi := _idx(start + k)
		var p: Dictionary = players[pi]
		if p.folded or p.allin:
			continue
		if not p.acted or int(p.bet) < cur_bet:
			_ask(pi)
			return
	_queue.append(_end_street)

func _live_count() -> int:
	var n := 0
	for p in players:
		if not p.folded:
			n += 1
	return n

func _ask(pi: int) -> void:
	var p: Dictionary = players[pi]
	if p.id == "you" and not auto:
		state = "you"
		table.focus("hand")
		var to_call := cur_bet - int(p.bet)
		_msg.text = ("%d to call." % to_call) if to_call > 0 else "Your move."
		_refresh()
		return
	state = "ai"
	if Game.fast_table:
		pass                       # calm camera: stay on the wide shot
	elif p.who == "d":
		table.focus("dealer", 1.4)
	elif p.who in ["s0", "s1"]:
		table.focus("seat" + String(p.who).substr(1), 1.4)
	_queue.append(func(): _ai_act(pi))
	_refresh()

func _bet_size() -> int:
	return Holdem.SMALL_BET if street in ["preflop", "flop"] else Holdem.BIG_BET

func _ai_act(pi: int) -> void:
	var p: Dictionary = players[pi]
	var key := "%d_%s" % [pi, street]
	if not _strength_cache.has(key):
		_strength_cache[key] = he.strength(p.hole, board, _live_count() - 1, 140)
	var s: float = _strength_cache[key]
	var to_call := cur_bet - int(p.bet)
	var facing := _last_aggressor()
	var style: String = "cadavire" if p.id == "cadavire" or p.id == "you" else String(p.style)
	var act := he.decide(style, s, to_call, _pot(), bets_made < Holdem.MAX_BETS and int(p.stack) > to_call, facing)
	if pi == 0 and act == "fold":
		act = "call"            # demo seat: you never fold, so the hand reaches a showdown
	_apply(pi, act)

func _last_aggressor() -> String:
	for p in players:
		if p.last in ["BET", "RAISE"]:
			return String(p.id)
	return ""

## You press FOLD / CHECK-CALL / BET-RAISE.
func you_act(act: String) -> void:
	if state != "you":
		return
	_apply(0, act)

func _apply(pi: int, act: String) -> void:
	var p: Dictionary = players[pi]
	var to_call := cur_bet - int(p.bet)
	if act == "fold" and to_call <= 0:
		act = "call"           # never fold for free
	match act:
		"fold":
			p.folded = true
			p.last = "FOLD"
			if p.id == "you" and flags.get("hide", false):
				p.stack += 2
				_msg.text = "The dog slid you 2 chips. 'For later.'"
			elif p.id == "cadavire":
				Game.say.emit("he_fold", 2)
		"call":
			_put(pi, to_call)
			p.last = "CHECK" if to_call == 0 else ("ALL IN" if p.allin else "CALL")
		"raise":
			if bets_made >= Holdem.MAX_BETS:
				_put(pi, to_call)
				p.last = "CALL"
			else:
				var raise_to := cur_bet + _bet_size()
				_put(pi, raise_to - int(p.bet))
				p.last = "BET" if cur_bet == 0 else "RAISE"
				cur_bet = maxi(cur_bet, int(p.bet))
				bets_made += 1
				for q in players:
					if q != p:
						q.acted = false
				if p.id == "you":
					Game.say.emit("he_you_raise", 2)
				elif p.id == "cadavire":
					Game.say.emit("he_raise", 2)
				elif randf() < 0.35:
					_quip(int(p.bidx), "raise")
	p.acted = true
	state = "ai"
	var who: String = "You" if p.id == "you" else String(p.name)
	_msg.text = "%s: %s" % [who, String(p.last).to_lower()]
	_refresh()
	_queue.append(func(): _turn_from(pi + 1))

func _pot() -> int:
	var n := 0
	for p in players:
		n += int(p.contrib)
	return n

func _end_street() -> void:
	for p in players:
		p.bet = 0
		if p.last != "FOLD" and p.last != "ALL IN":
			p.last = ""
	cur_bet = 0
	bets_made = 0
	match street:
		"preflop":
			street = "flop"
			_queue.append(func(): _deal_board(3))
		"flop":
			street = "turn"
			_queue.append(func(): _deal_board(1))
		"turn":
			street = "river"
			_queue.append(func(): _deal_board(1))
		"river":
			_queue.append(_showdown)
			return
	_queue.append(func(): _begin_round(_idx(button + 1)))

func _deal_board(n: int) -> void:
	he.draw()                  # burn
	for k in n:
		board.append(he.draw())
		Sfx.play("card", -4.0, 0.15)
		_vis.append({"who": "b", "i": board.size() - 1, "t0": _t + k * 0.12, "pi": -1})
	table.focus("seat")
	if _active_can_act() <= 1:   # everyone else all in: run the board out
		pass

func _active_can_act() -> int:
	var n := 0
	for p in players:
		if not p.folded and not p.allin:
			n += 1
	return n

func _award_uncontested() -> void:
	for pi in players.size():
		var p: Dictionary = players[pi]
		if not p.folded:
			var pot := _pot()
			last_rake = Holdem.rake(pot, street != "preflop", Game.fever_active)
			pot -= last_rake
			p.stack += pot
			_finish(pi, pot, "", true)
			return

func _showdown() -> void:
	table.focus("result")
	var live: Array = []
	for pi in players.size():
		var p: Dictionary = players[pi]
		if not p.folded:
			p.score = Holdem.rank_hand(p.hole + board)
			live.append(pi)
	var pots := Holdem.build_pots(players)
	var total := 0
	for pot in pots:
		total += int(pot.amount)
	last_rake = Holdem.rake(total, true, Game.fever_active)
	var cut := last_rake
	for pot in pots:                 # the house cut comes out of the main pot first
		var c := mini(cut, int(pot.amount))
		pot.amount = int(pot.amount) - c
		cut -= c
	var won_by_you := 0
	var best_pi: int = live[0]
	for pot in pots:
		var winners: Array = []
		for pi in pot.eligible:
			if winners.is_empty():
				winners = [pi]
			else:
				var c := Holdem.compare(players[pi].score, players[winners[0]].score)
				if c > 0:
					winners = [pi]
				elif c == 0:
					winners.append(pi)
		var share: int = int(pot.amount) / winners.size()
		var odd: int = int(pot.amount) - share * winners.size()
		for k in winners.size():
			players[winners[k]].stack += share + (odd if k == 0 else 0)
			if winners[k] == 0:
				won_by_you += share + (odd if k == 0 else 0)
		if not winners.is_empty():
			best_pi = winners[0]
	_finish(best_pi, won_by_you if won_by_you > 0 else _pot() - last_rake, Holdem.hand_name(players[best_pi].score), false)

func _finish(winner: int, amount: int, hand: String, uncontested: bool) -> void:
	var you: Dictionary = players[0]
	var you_won := winner == 0
	var extra: Array = []
	if you_won and flags.get("clout", false):
		you.stack += 5
		extra.append("chat tip +5")
	if you_won and flags.get("skim", false):
		if randf() < 0.5:
			Game.say.emit("bj_skim_caught", 4)
			extra.append("skim caught")
		else:
			you.stack -= mini(2, int(you.stack))
			extra.append("skimmed -2")
	if not you_won and not you.folded and flags.get("audit", false):
		var back := int(ceil(int(you.contrib) * 0.5))
		you.stack += back
		extra.append("audit +%d" % back)
	var who: String = players[winner].name
	if uncontested:
		result_text = ("YOU TAKE IT" if you_won else who.to_upper() + " TAKES IT")
		_msg.text = ("You win %d chips. Everyone else folded." % amount) if you_won else ("%s wins %d chips. Everyone else folded." % [who, amount])
	else:
		result_text = ("YOU WIN" if you_won else who.to_upper() + " WINS") + " · " + hand.to_upper()
		_msg.text = ("You win with %s." % hand.to_lower()) if you_won else ("%s wins with %s." % [who, hand.to_lower()])
	if last_rake > 0:
		jar += last_rake
		extra.append("house cut %d" % last_rake)
	if not extra.is_empty():
		_msg.text += " (" + ", ".join(extra) + ")"
	Sfx.play("win" if you_won else "lose", -4.0, 0.0)
	if you_won:
		Game.say.emit("he_win", 3)
		Challenges.bump("he_wins")
	elif winner >= 0 and players[winner].id == "cadavire":
		Game.say.emit("he_she_wins", 3)
	else:
		Game.say.emit("he_lose", 2)
	state = "result"
	table.focus("result")
	_bankrolls()
	if state == "closed":
		_refresh()
		return
	if int(you.stack) <= 0:
		state = "busted"
		Game.settle_wager(stake, 0)
		stake = 0
		_msg.text += " You're out of chips."
		Game.say.emit("he_bust", 3)
	_refresh()

## After a hand: short opponents reload once, then go home broke for 30 min.
## If Cadavire goes broke, she closes the table (you broke the house).
func _bankrolls() -> void:
	var gone: Array = []
	var notes: Array = []
	for pi in range(1, players.size()):
		var p: Dictionary = players[pi]
		if int(p.stack) >= Holdem.BIG_BET * 2:
			continue
		if int(p.reloads) > 0:
			p.reloads = int(p.reloads) - 1
			chip_adjust += int(p.start) - int(p.stack)
			p.stack = int(p.start)
			notes.append("%s reloads (last time)" % p.name)
		else:
			gone.append(p)
	for p in gone:
		chip_adjust -= int(p.stack)
		Game.send_home(String(p.id))
		if p.id == "cadavire":
			_broke_house()
			return
		_quip(int(p.bidx), "broke")
		var bi := seats.find(int(p.bidx))
		if bi >= 0:
			seats[bi] = -1            # the chair stays, the manager leaves
		Challenges.bump("he_sent_home")
		Game.say.emit("he_sent_home", 3)
		notes.append("%s goes home broke" % p.name)
		var at := players.find(p)
		players.erase(p)
		if button >= at:
			button = _idx(button - 1)
	if not notes.is_empty():
		_msg.text += " " + ". ".join(notes) + "."

func _broke_house() -> void:
	state = "closed"
	result_text = "YOU BROKE THE HOUSE"
	_msg.text = "Cadavire is out of chips. The table closes for 30 min."
	Game.say.emit("he_broke_house", 5)
	Game.add_fever(25.0)
	Challenges.bump("he_house_broke")
	table.focus("dealer", 3.0)

# =====================================================================
# Funny business (same managers, Hold'em versions)
# =====================================================================
func _funny_business() -> void:
	var mgr: Array = []
	for k in players.size():
		if int(players[k].bidx) >= 0:
			mgr.append(k)
	if mgr.is_empty():
		return
	var ev := ""
	var pi: int = mgr[randi() % mgr.size()]
	if force_next != "":
		for k in mgr:
			if String(data.get(players[k].id, {}).get("event", "")) == force_next:
				pi = k
		ev = force_next
		force_next = ""
	elif randf() > EVENT_CHANCE:
		return
	else:
		ev = String(data.get(players[pi].id, {}).get("event", "snack"))
	event_seat = int(String(players[pi].who).substr(1)) if String(players[pi].who).begins_with("s") else -1
	var hint := ""
	match ev:
		"peek":
			for p in players:
				if p.id == "cadavire" and not p.hole.is_empty():
					peek_card = p.hole[0]
			Game.say.emit("bj_peeked", 3)
		"burn", "bottom":
			he.draw()
		"count":
			var others: Array = []
			for k in range(1, players.size()):
				if k != pi:            # a tell is about SOMEONE ELSE at the table
					others.append(k)
			var t: int = others[randi() % others.size()]
			var s := he.strength(players[t].hole, [], 1, 80)
			hint = "strong" if s > 0.55 else "weak"
			tell_text = "TELL: %s looks %s" % [players[t].name, hint.to_upper()]
		"hide", "audit", "clout", "skim":
			flags[ev] = true
	_quip(int(players[pi].bidx), "lines", hint)

func force_event(ev: String) -> void:
	force_next = ev
	_funny_business()

func _quip(bidx: int, key: String, hint := "") -> void:
	if bidx < 0:
		return
	var lines: Array = data.get(Balance.BUILDINGS[bidx].id, {}).get(key, [])
	if lines.is_empty():
		return
	var line := String(lines[randi() % lines.size()]).replace("{hint}", hint)
	var mb = get_tree().get_first_node_in_group("manager_box")
	if mb:
		mb.quip(bidx, line)
	var si := seats.find(bidx)
	if si >= 0:
		table.focus("seat%d" % si, 1.5 if Game.fast_table else 3.0)

# =====================================================================
# Loop + UI
# =====================================================================
func _process(delta: float) -> void:
	_t += delta
	if auto and state == "you" and _queue.is_empty():
		_q_t = _step()
		_queue.append(func(): _ai_act(0))      # demo: the Cadavire AI plays your seat
	if not _queue.is_empty():
		_q_t -= delta
		if _q_t <= 0.0:
			_q_t = _step() if state == "ai" else (0.15 if Game.fast_table else 0.3)
			var f: Callable = _queue.pop_front()
			f.call()
			_refresh()

## Tests: run every queued step now.
func flush(max_steps := 400) -> void:
	var guard := 0
	while guard < max_steps:
		if _queue.is_empty():
			if auto and state == "you":
				_ai_act(0)
				guard += 1
				continue
			break
		var f: Callable = _queue.pop_front()
		f.call()
		guard += 1
	_refresh()

func _refresh() -> void:
	if _marrow_lbl == null:
		return
	var you_chips := int(players[0].stack) if not players.is_empty() else 0
	_marrow_lbl.text = "MARROW %d · CHIPS %d" % [Game.marrow, you_chips]
	var cap: int = Game.MAX_BET_BY_RANK[clampi(Game.rank, 0, Game.MAX_BET_BY_RANK.size() - 1)]
	_buy_lbl.text = "%d M · %d CHIPS" % [buyin, buyin * Holdem.CHIPS_PER_MARROW]
	if state == "buyin":
		_msg.text = "Buy in (max %d Marrow at your rank)." % cap if Game.max_bet() >= 1 else "No Marrow. Fold a run to get some."
	elif state == "closed" and stake == 0:
		_msg.text = "Cadavire went to count the jar. Back in %s." % away_text("cadavire")
	_buy_row.visible = state == "buyin" or state == "busted"
	_act_row.visible = state == "you"
	_end_row.visible = state in ["buyin", "result", "busted", "closed"]
	_btn.fast.text = "FAST: ON" if Game.fast_table else "FAST: OFF"
	_btn.next.visible = state == "result"
	_btn.cash.text = "LEAVE" if stake == 0 else "CASH OUT (%d)" % (you_chips / Holdem.CHIPS_PER_MARROW)
	_btn.sit.text = "REBUY" if state == "busted" else "BUY IN"
	_btn.sit.disabled = Game.max_bet() < 1
	_btn.minus.disabled = buyin <= 1
	_btn.plus.disabled = buyin >= Game.max_bet()
	if state == "you" and not players.is_empty():
		var to_call := cur_bet - int(players[0].bet)
		_btn.call.text = "CHECK" if to_call <= 0 else "CALL %d" % mini(to_call, you_chips)
		_btn.raise.text = ("BET %d" if cur_bet == 0 else "RAISE %d") % _bet_size()
		_btn.raise.disabled = bets_made >= Holdem.MAX_BETS or you_chips <= to_call
		_btn.fold.disabled = to_call <= 0
	if table:
		table.queue_redraw()

# =====================================================================
# Drawing hooks (CardRoomView)
# =====================================================================
func _player_at(who: String) -> Dictionary:
	for p in players:
		if p.who == who:
			return p
	return {}

func _hand_of(who: String) -> Array:
	if who == "b":
		return board
	var p := _player_at(who)
	return p.get("hole", [])

func draw_felt(v) -> void:
	var tex: Texture2D = v.atlas.get_texture()
	var deck_pos := Vector3(0.5, v.TOP_Y, -0.42)
	for k in 4:
		v._card_quad(tex, {}, deck_pos + Vector3(0, 0.006 * k, -0.002 * k), 0.0)
	var showdown := state in ["result", "busted"] and street == "river"
	for c in _vis:
		var who: String = c.who
		var hand := _hand_of(who)
		if c.i >= hand.size():
			continue
		var p := _player_at(who)
		if not p.is_empty() and p.folded:
			continue                    # folded cards leave the table
		var n := 5 if who == "b" else hand.size()
		var target: Vector3 = v.card_spot(who, c.i, n)
		var pos: Vector3 = v.fly(deck_pos, target, (_t - float(c.t0)) / SLIDE)
		var up := who == "b" or who == "p" or showdown
		var yaw := 0.0 if who in ["p", "d", "b"] else (PI * 0.5 if who == "s0" else -PI * 0.5)
		v._card_quad(tex, hand[c.i] if up else {}, pos, yaw)
	# bets in front of each player, pot in the middle
	for p in players:
		if int(p.bet) > 0:
			var hs: Vector3 = v.hand_spot(p.who)
			v._chips(hs.lerp(Vector3(0, v.TOP_Y, 0.0), 0.45), int(p.bet))
	var pot := _pot()
	for p in players:
		pot -= int(p.bet)
	if pot > 0:
		v._chips(Vector3(0.3, v.TOP_Y, 0.15), pot)

func draw_labels(v) -> void:
	var CARD: Vector2 = v.CARD
	for p in players:
		var pos: Vector2
		if p.who == "p":
			pos = v._p2(v.hand_spot("p") + Vector3(0, 0, CARD.y * 0.5 + 0.05))
		elif p.who == "d":
			pos = v._p2(Vector3(-0.42, v.TOP_Y, -0.44))
		else:
			pos = v.seat_head(int(String(p.who).substr(1)))
		var line := "%s · %d" % [p.name, int(p.stack)] if p.id != "you" else "%d chips" % int(p.stack)
		v._text(line, pos, 14 if p.id != "you" else 18, Color(1, 1, 1, 0.92))
		if p.last != "":
			v._text(p.last, pos + Vector2(0, 22), 16, Color("ffe14a") if p.last != "FOLD" else Color(1, 1, 1, 0.5))
		if not p.score.is_empty() and state in ["result", "busted"] and not p.folded:
			v._text(Holdem.hand_name(p.score), pos + Vector2(0, 44), 14, Color("8fdcff"))
		if players.find(p) == button:
			v._text("D", pos + Vector2(-70, 0), 18, Color.WHITE)
	if not players.is_empty() and players[0].hole.size() == 2 and not players[0].folded:
		var mine := Holdem.rank_hand(players[0].hole + board) if board.size() >= 3 and players[0].score.is_empty() else []
		if not mine.is_empty():
			v._text(Holdem.hand_name(mine), v._p2(v.hand_spot("p") + Vector3(0, 0, CARD.y * 0.5 + 0.05)) + Vector2(0, 24), 15, Color("8fdcff"))
	if not peek_card.is_empty() and state not in ["result", "busted", "closed"]:
		v._text("PEEK: " + Blackjack.rank_text(peek_card) + " of " + ["spades", "hearts", "clubs", "diamonds"][int(peek_card.s)], v._p2(v.hand_spot("d") + Vector3(0, 0.22, 0)), 18, Color("ffe14a"))
	if tell_text != "" and state not in ["result", "busted", "closed"]:
		v._text(tell_text, v._p2(Vector3(0.5, v.TOP_Y + 0.16, -0.42)), 15, Color("ffe14a"))
	for si in 2:
		if si >= seats.size():
			v._text("EMPTY SEAT", v.seat_head(si) + Vector2(0, 40), 12, Color(1, 1, 1, 0.45))
		elif int(seats[si]) < 0:
			v._text("WENT HOME BROKE", v.seat_head(si) + Vector2(0, 40), 12, Color(1, 1, 1, 0.55))
		elif event_seat == si and state not in ["buyin"]:
			v._text("!", v.seat_head(si) + Vector2(0, -26), 30, Color("ffe14a"))
	if jar > 0:
		v._text("JAR %d" % jar, v._p2(Vector3(0.3, v.TOP_Y, 0.15)) + Vector2(0, 30), 12, Color(1, 1, 1, 0.6))
	if result_text != "" and state in ["result", "busted", "closed"]:
		v.banner(result_text)
