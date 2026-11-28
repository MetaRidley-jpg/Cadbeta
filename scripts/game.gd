extends Node
## Autoload "Game". Owns ALL game state and rules. UI only reads + calls methods.

signal bones_changed
signal marrow_changed
signal building_changed(i: int)
signal run_reset
signal fever_changed
signal fever_mode_changed(active: bool)
signal costume_changed
signal inventory_changed
signal rank_changed(rank: int)
signal say(category: String, priority: int)
## T (2026-11-28): "For now remove cadavire and focus on dogfight. Don't delete just disconnect
## and redirect" / "Text box space will still be used". Cadavire's lines and portrait are OFF
## (nothing deleted: set cadavire_on = true to bring her back). The text box shows dogfight
## RADIO text instead (Game.radio_say), and the app boots into the dogfight (main.gd).
var cadavire_on := false
var dogfight_focus := true
signal radio(text: String)

func radio_say(text: String) -> void:
	radio.emit(text)
signal taste_test(i: int, quality: int, eaten: float)
signal floating(text: String, i: int)          # i = building index, -1 = top bar
signal offline_earned(amount: float, seconds: float)
signal schemes_changed
signal manager_scene(i: int, tier: int)   # tier 0 = short rehire line
signal level_changed(level: int)
signal reburied(gain: int, promoted: Array)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const BUY_MODES := [1, 10, 100, -1]   # -1 = MAX
const BUY_MODE_NAMES := ["x1", "x10", "x100", "MAX"]
const OFFLINE_MIN_SECONDS := 10.0

# ---- run state (reset by Rebury) ----
var bones := 0.0
var run_bones := 0.0
var owned: Array = []
var managers: Array = []
var progress: Array = []
var running: Array = []
var buff_mult: Array = []
var buff_left: Array = []
var schemes := {}             # scheme id -> true

# ---- permanent state ----
var total_bones := 0.0
var marrow := 0
var marrow_earned := 0        # lifetime stat only
var loyalty: Array = []       # per manager, 0..5
var scenes_seen: Array = []   # highest loyalty scene already played
var level_xp := 0.0           # bones earned since last ENDGAME reset
var df_best_score := 0        # dogfight
var df_best_wave := 0
# ---- card table ----
const TABLE_AWAY_SECS := 1800.0        # a busted Hold'em player goes home for 30 min
var table_away := {}                   # id -> unix time they come back
var fast_table := false                # card tables: quick AI turns, calm camera
var df_assist := true                  # dogfight: wings level when you let go
var df_replays := true                 # dogfight: fighting-game KO replay
var sfx_on := true                     # sound effects (Fold page toggle)
var rank := 0
var rebury_count := 0
var marrow_claimed: Array = []
var costumes_owned: Array = ["grave_casual"]
var costume := "grave_casual"
var inventory := {}            # item id -> count
var equipped := ""

# ---- fever ----
var fever := 0.0
var fever_active := false
var fever_left := 0.0
var fever_total := 0.0

# ---- misc ----
var buy_mode_idx := 0
var scene_active := false     # a manager scene is playing: no taste tests or chatter
var minigame_active := false  # a minigame is playing: no taste tests or idle chatter
var pending_offline := Vector2.ZERO   # (bones, seconds) for the welcome-back popup
var autosave_enabled := true   # tests switch this off

## Phone check (2026-11-26): native mobile export OR the web build on an iPhone / Android
## browser. `--phone` (debug) forces it on a PC for screenshots and tests.
static var force_phone := false
static func is_phone() -> bool:
	return force_phone or OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")

## Web on a phone: the browser reports no safe area, but the bottom edge belongs to the
## home bar / app-switch swipe. Keep this share of the screen height free at the bottom.
const WEB_HOME_BAR := 0.045
var rng := RandomNumberGenerator.new()

var _idle_time := 0.0
var _taste_timer := 0.0
var _talk_timer := 0.0
var _save_timer := 0.0
var _paused_at := 0.0

func _ready() -> void:
	rng.randomize()
	_init_permanent()
	new_run(false)
	if not OS.get_cmdline_user_args().has("--fresh"):
		load_game()
	_taste_timer = _next_taste_delay()
	_talk_timer = 6.0

# =====================================================================
# Setup / reset
# =====================================================================
func _init_permanent() -> void:
	var n := Balance.BUILDINGS.size()
	for arr in [marrow_claimed, loyalty, scenes_seen]:
		arr.resize(n)
	marrow_claimed.fill(false)
	loyalty.fill(0)
	scenes_seen.fill(0)

func new_run(emit := true) -> void:
	var n := Balance.BUILDINGS.size()
	bones = 0.0
	run_bones = 0.0
	for arr in [owned, managers, progress, running, buff_mult, buff_left]:
		arr.resize(n)
	owned.fill(0)
	managers.fill(false)
	progress.fill(0.0)
	running.fill(false)
	buff_mult.fill(1.0)
	buff_left.fill(0.0)
	owned[0] = 1   # start with one Bone Broth Stand
	schemes = {}
	_scheme_counts = {}
	fever = 0.0
	fever_active = false
	fever_left = 0.0
	if emit:
		run_reset.emit()
		schemes_changed.emit()
		bones_changed.emit()
		fever_changed.emit()
		fever_mode_changed.emit(false)

# =====================================================================
# Main tick
# =====================================================================
func _process(delta: float) -> void:
	tick(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey:
		_idle_time = 0.0

func tick(delta: float) -> void:
	_idle_time += delta
	var earned := 0.0
	for i in Balance.BUILDINGS.size():
		if owned[i] <= 0:
			continue
		if buff_left[i] > 0.0:
			buff_left[i] -= delta
			if buff_left[i] <= 0.0:
				buff_left[i] = 0.0
				buff_mult[i] = 1.0
				building_changed.emit(i)
		if managers[i]:
			progress[i] += delta / cycle_time(i)
			if progress[i] >= 1.0:
				var cycles := floorf(progress[i])
				progress[i] -= cycles
				earned += revenue(i) * cycles
		elif running[i]:
			progress[i] += delta / cycle_time(i)
			if progress[i] >= 1.0:
				progress[i] = 0.0
				running[i] = false
				earned += revenue(i)
				building_changed.emit(i)
	if earned > 0.0:
		add_bones(earned)
	_tick_fever(delta)
	_tick_taste(delta)
	_tick_talk(delta)
	if autosave_enabled:
		_save_timer += delta
		if _save_timer >= 10.0:
			_save_timer = 0.0
			save_game()

func add_bones(v: float) -> void:
	bones += v
	run_bones += v
	total_bones += v
	var lv_before := level()
	level_xp += v
	var lv := level()
	if lv > lv_before:
		level_changed.emit(lv)
	bones_changed.emit()

# =====================================================================
# Level meter
# =====================================================================
func level_exact() -> float:
	return Balance.LEVEL_PER_DECADE * log(1.0 + level_xp) / log(10.0)

func level() -> int:
	return int(floorf(level_exact() + 1e-9))

func level_progress() -> float:
	return maxf(0.0, level_exact() - level())

## Endgame only. Nothing calls this yet: the endgame event is not designed.
func endgame_reset_level() -> void:
	level_xp = 0.0
	level_changed.emit(0)

# =====================================================================
# Multipliers
# =====================================================================
func costume_fx() -> Dictionary:
	return Balance.costume(costume).fx

func item_fx() -> Dictionary:
	if equipped == "":
		return {}
	return Balance.item(equipped).get("fx", {})

func loyalty_mult(i: int) -> float:
	return Balance.LOYALTY_MULT[loyalty[i]]

func global_income_mult() -> float:
	var m := 1.0 + rank * Balance.RANK_INCOME_BONUS
	m *= pow(Balance.SCHEME_MULT, _scheme_count(-1))
	m *= costume_fx().get("all_mult", 1.0)
	m *= item_fx().get("all_mult", 1.0)
	if fever_active:
		m *= Balance.FEVER_INCOME_MULT
	return m

func cat_income_mult(i: int) -> float:
	var cat: int = Balance.BUILDINGS[i].cat
	return costume_fx().get("cat_mult", {}).get(cat, 1.0)

func speed_steps(i: int) -> int:
	var s := 0
	for m in Balance.SPEED_MILESTONES:
		if owned[i] >= m:
			s += 1
	return s

func profit_steps(i: int) -> int:
	if owned[i] < Balance.PROFIT_STEP_START:
		return 0
	return 1 + (owned[i] - Balance.PROFIT_STEP_START) / Balance.PROFIT_STEP

func next_milestone(i: int) -> int:
	for m in Balance.SPEED_MILESTONES:
		if owned[i] < m:
			return m
	return Balance.PROFIT_STEP_START + profit_steps(i) * Balance.PROFIT_STEP

func cycle_time(i: int) -> float:
	return Balance.BUILDINGS[i].time / pow(2.0, speed_steps(i))

func revenue(i: int) -> float:
	var b: Dictionary = Balance.BUILDINGS[i]
	return b.revenue * owned[i] * pow(2.0, profit_steps(i)) \
		* cat_income_mult(i) * buff_mult[i] * global_income_mult() \
		* pow(Balance.SCHEME_MULT, _scheme_count(i)) * loyalty_mult(i)

func income_per_sec() -> float:
	var t := 0.0
	for i in Balance.BUILDINGS.size():
		if owned[i] > 0 and managers[i]:
			t += revenue(i) / cycle_time(i)
	return t

func offline_rate() -> float:
	# No fever, no taste buffs while away.
	var t := 0.0
	var fever_div := Balance.FEVER_INCOME_MULT if fever_active else 1.0
	for i in Balance.BUILDINGS.size():
		if owned[i] > 0 and managers[i]:
			t += revenue(i) / buff_mult[i] / fever_div / cycle_time(i)
	return t * costume_fx().get("offline_mult", 1.0)

func cost_mult(i := -1) -> float:
	var m := 1.0
	if fever_active:
		m *= Balance.FEVER_COST_MULT
	m *= costume_fx().get("cost_mult", 1.0)
	m *= item_fx().get("cost_mult", 1.0)
	if i >= 0:
		m *= costume_fx().get("cat_cost", {}).get(Balance.BUILDINGS[i].cat, 1.0)
	return m

# =====================================================================
# Buying buildings
# =====================================================================
func cost_for(i: int, n: int) -> float:
	var b: Dictionary = Balance.BUILDINGS[i]
	var c: float = b.coef
	return b.cost * pow(c, owned[i]) * (pow(c, n) - 1.0) / (c - 1.0) * cost_mult(i)

func max_affordable(i: int) -> int:
	var b: Dictionary = Balance.BUILDINGS[i]
	var c: float = b.coef
	var first: float = b.cost * pow(c, owned[i]) * cost_mult(i)
	if bones < first:
		return 0
	var n := int(floorf(log(bones * (c - 1.0) / first + 1.0) / log(c)))
	while n > 0 and cost_for(i, n) > bones:   # float safety
		n -= 1
	return n

func buy_amount(i: int) -> int:
	var mode: int = BUY_MODES[buy_mode_idx]
	if mode == -1:
		return maxi(1, max_affordable(i))
	return mode

func can_buy(i: int) -> bool:
	return bones >= cost_for(i, buy_amount(i))

func buy(i: int) -> bool:
	var n := buy_amount(i)
	var cost := cost_for(i, n)
	if n <= 0 or bones < cost:
		return false
	var before: int = owned[i]
	var steps_before := speed_steps(i)
	bones -= cost
	owned[i] += n
	add_fever(Balance.FEVER_ON_BUY)
	if before == 0:
		say.emit("buy_new", 1)
	elif speed_steps(i) > steps_before:
		say.emit("milestone", 1)
		floating.emit("SPEED x2!", i)
	_check_marrow_milestone(i)
	_check_rank()
	bones_changed.emit()
	building_changed.emit(i)
	return true

func cycle_buy_mode() -> void:
	buy_mode_idx = (buy_mode_idx + 1) % BUY_MODES.size()
	for i in Balance.BUILDINGS.size():
		building_changed.emit(i)

func manager_cost(i: int) -> float:
	return Balance.BUILDINGS[i].manager_cost * costume_fx().get("manager_cost", 1.0) * cost_mult()

func hire_manager(i: int) -> bool:
	if managers[i] or owned[i] <= 0:
		return false
	var cost := manager_cost(i)
	if bones < cost:
		return false
	bones -= cost
	managers[i] = true
	running[i] = false
	add_fever(Balance.FEVER_ON_MANAGER)
	if loyalty[i] == 0:
		loyalty[i] = 1
	if scenes_seen[i] < loyalty[i]:
		scenes_seen[i] = loyalty[i]
		manager_scene.emit(i, loyalty[i])
	else:
		manager_scene.emit(i, 0)
	bones_changed.emit()
	building_changed.emit(i)
	return true

func run(i: int) -> void:
	if owned[i] > 0 and not managers[i] and not running[i]:
		running[i] = true
		building_changed.emit(i)

func _check_marrow_milestone(i: int) -> void:
	if not marrow_claimed[i] and owned[i] >= Balance.MARROW_MILESTONE_COUNT:
		marrow_claimed[i] = true
		add_marrow(Balance.MARROW_MILESTONE_REWARD)
		floating.emit("+%d Marrow" % Balance.MARROW_MILESTONE_REWARD, i)

func _check_rank() -> void:
	var lowest: int = owned.min()
	var r := 0
	for t in Balance.RANK_THRESHOLDS:
		if lowest >= t:
			r += 1
	if r > rank:
		rank = r
		rank_changed.emit(rank)
		say.emit("rank_up", 2)
		for i in Balance.BUILDINGS.size():
			building_changed.emit(i)

func add_marrow(v: int) -> void:
	marrow += v
	marrow_earned += v
	marrow_changed.emit()

# =====================================================================
# Schemes
# =====================================================================
var _scheme_cache: Array = []

func scheme_list() -> Array:
	if _scheme_cache.is_empty():
		_scheme_cache = Balance.all_schemes()
	return _scheme_cache

var _scheme_counts := {}   # target -> owned count (cache)

func _scheme_count(target: int) -> int:
	return _scheme_counts.get(target, 0)

func _recount_schemes() -> void:
	_scheme_counts = {}
	for s in scheme_list():
		if schemes.has(s.id):
			_scheme_counts[s.target] = _scheme_counts.get(s.target, 0) + 1

func scheme_price(s: Dictionary) -> float:
	return s.price * cost_mult()

func buy_scheme(id: String) -> bool:
	if schemes.has(id):
		return false
	for s in scheme_list():
		if s.id == id:
			var p := scheme_price(s)
			if bones < p:
				return false
			bones -= p
			schemes[id] = true
			_recount_schemes()
			add_fever(Balance.FEVER_ON_MANAGER)
			say.emit("scheme", 1)
			schemes_changed.emit()
			_refresh_all()
			return true
	return false

## Cheapest scheme not owned yet (for the "next scheme" hint), or {}.
func next_scheme() -> Dictionary:
	for s in scheme_list():
		if not schemes.has(s.id):
			return s
	return {}

# =====================================================================
# Fever
# =====================================================================
func fever_gain_mult() -> float:
	return costume_fx().get("fever_gain", 1.0)

func add_fever(v: float) -> void:
	if fever_active:
		return
	fever = minf(Balance.FEVER_MAX, fever + v * fever_gain_mult())
	fever_changed.emit()
	if fever >= Balance.FEVER_MAX:
		start_fever()

func start_fever() -> void:
	fever_active = true
	fever_total = Balance.FEVER_DURATION + costume_fx().get("fever_time", 0.0) \
		+ item_fx().get("fever_time", 0.0)
	fever_left = fever_total
	fever = Balance.FEVER_MAX
	_talk_timer = 4.0
	fever_mode_changed.emit(true)
	say.emit("fever_start", 3)
	_refresh_all()

func _end_fever() -> void:
	fever_active = false
	fever = 0.0
	fever_left = 0.0
	fever_mode_changed.emit(false)
	say.emit("fever_end", 3)
	_talk_timer = randf_range(Balance.IDLE_TALK_MIN, Balance.IDLE_TALK_MAX)
	_refresh_all()

func _tick_fever(delta: float) -> void:
	if fever_active:
		fever_left -= delta
		fever = Balance.FEVER_MAX * maxf(fever_left, 0.0) / fever_total
		fever_changed.emit()
		if fever_left <= 0.0:
			_end_fever()
		return
	if _idle_time < Balance.FEVER_IDLE_AFTER:
		add_fever(Balance.FEVER_PASSIVE_PER_SEC * delta)
	elif fever > 0.0:
		fever = maxf(0.0, fever - Balance.FEVER_IDLE_DECAY * item_fx().get("idle_decay", 1.0) * delta)
		fever_changed.emit()

func is_idle() -> bool:
	return _idle_time >= Balance.FEVER_IDLE_AFTER

func _refresh_all() -> void:
	bones_changed.emit()
	for i in Balance.BUILDINGS.size():
		building_changed.emit(i)
	inventory_changed.emit()

# =====================================================================
# Taste tests — she steals one cycle of bones from a random building
# =====================================================================
func _next_taste_delay() -> float:
	var rate: float = costume_fx().get("taste_rate", 1.0) * item_fx().get("taste_rate", 1.0)
	return rng.randf_range(Balance.TASTE_INTERVAL_MIN, Balance.TASTE_INTERVAL_MAX) / rate

func _tick_taste(delta: float) -> void:
	if scene_active or minigame_active:
		return
	_taste_timer -= delta
	if _taste_timer <= 0.0:
		_taste_timer = _next_taste_delay()
		do_taste_test()

func do_taste_test(force_index := -1) -> void:
	var pool: Array = []
	for i in Balance.BUILDINGS.size():
		if owned[i] > 0:
			pool.append(i)
	if pool.is_empty():
		return
	var i: int = force_index if force_index >= 0 else pool[rng.randi_range(0, pool.size() - 1)]
	var q := clampi(int(i / 2.5) + rng.randi_range(-1, 1), 0, 3)
	q += int(costume_fx().get("taste_quality", 0))
	if rng.randf() < item_fx().get("taste_quality_chance", 0.0):
		q += 1
	if costume_fx().get("eat_anything", false):
		q = 3
	q = clampi(q, 0, 3)
	var eaten := minf(bones, revenue(i) * costume_fx().get("bite", 1.0))
	bones -= eaten
	buff_mult[i] = Balance.TASTE_BUFF_MULT[q]
	buff_left[i] = Balance.TASTE_BUFF_TIME if q >= 2 else 0.0
	add_fever(Balance.TASTE_FEVER[q])
	if q == 3 and rng.randf() < Balance.TASTE_MARROW_CHANCE:
		add_marrow(1)
		floating.emit("+1 Marrow", i)
	Sfx.play("crunch", -2.0)
	taste_test.emit(i, q, eaten)
	say.emit("taste_%d" % q, 2)
	bones_changed.emit()
	building_changed.emit(i)

# =====================================================================
# Idle chatter
# =====================================================================
func _tick_talk(delta: float) -> void:
	if scene_active or minigame_active:
		return
	_talk_timer -= delta
	if _talk_timer <= 0.0:
		if fever_active:
			_talk_timer = randf_range(Balance.FEVER_TALK_MIN, Balance.FEVER_TALK_MAX)
		else:
			_talk_timer = randf_range(Balance.IDLE_TALK_MIN, Balance.IDLE_TALK_MAX)
		say.emit("idle_away" if is_idle() else "idle", 0)

# =====================================================================
# Costumes (Marrow) and items (Bones)
# =====================================================================
func costume_unlocked(id: String) -> bool:
	return rank >= Balance.costume(id).rank

func buy_costume(id: String) -> bool:
	var c := Balance.costume(id)
	if costumes_owned.has(id) or marrow < c.price or not costume_unlocked(id):
		return false
	marrow -= c.price
	costumes_owned.append(id)
	add_fever(Balance.FEVER_ON_COSTUME_BUY)
	costume = id
	marrow_changed.emit()
	costume_changed.emit()
	say.emit("costume_buy", 2)
	_refresh_all()
	return true

func wear(id: String) -> bool:
	if not costumes_owned.has(id) or costume == id:
		return false
	costume = id
	costume_changed.emit()
	say.emit("costume_wear", 1)
	_refresh_all()
	return true

func item_price(id: String) -> float:
	return Balance.item(id).price * cost_mult()

func item_count(id: String) -> int:
	return int(inventory.get(id, 0))

func buy_item(id: String) -> bool:
	var p := item_price(id)
	if bones < p:
		return false
	bones -= p
	inventory[id] = item_count(id) + 1
	bones_changed.emit()
	inventory_changed.emit()
	return true

func equip(id: String) -> bool:
	if item_count(id) <= 0 or equipped == id:
		return false
	equipped = id
	inventory_changed.emit()
	say.emit("equip", 1)
	_refresh_all()
	return true

func unequip() -> void:
	equipped = ""
	inventory_changed.emit()
	_refresh_all()

func gift(id: String) -> bool:
	if item_count(id) <= 0:
		return false
	inventory[id] = item_count(id) - 1
	if inventory[id] <= 0:
		inventory.erase(id)
		if equipped == id:
			equipped = ""
	say.emit("gift." + id, 3)
	Challenges.bump("gifts")
	add_fever(Balance.item(id).gift_fever)
	inventory_changed.emit()
	_refresh_all()
	return true

# =====================================================================
# Rebury (prestige reset)
# =====================================================================
# =====================================================================
# Minigames.
# Skill games (pool, dogfight) are FREE: they pay bones + Fever, never Marrow.
# Marrow wagers exist ONLY in card games (blackjack, hold'em: not built yet).
# The max bet is set by prestige rank. The bet leaves your Marrow when the hand
# starts, so quitting or closing the app mid-hand counts as a loss.
# =====================================================================
const MAX_BET_BY_RANK := [5, 10, 25, 50, 100]   # index = prestige rank 0..4
const MINIGAME_FEVER_WIN := 8.0
const MINIGAME_FEVER_LOSS := 3.0
const FREE_WIN_SECONDS := 60.0          # a win pays 60 s of current income
const FREE_WIN_MIN := 100.0

func max_bet() -> int:
	return mini(MAX_BET_BY_RANK[clampi(rank, 0, MAX_BET_BY_RANK.size() - 1)], marrow)

## Skill minigame start/end (no Marrow involved).
func start_minigame() -> void:
	minigame_active = true

## reward_mult scales the win payout (e.g. dogfight waves survived). Returns popup text.
func end_minigame(won: bool, reward_mult := 1.0) -> String:
	minigame_active = false
	if won:
		var b := maxf(FREE_WIN_MIN, income_per_sec() * FREE_WIN_SECONDS) * maxf(reward_mult, 0.0)
		add_bones(b)
		add_fever(MINIGAME_FEVER_WIN)
		return "+%s bones" % Fmt.num(b)
	add_fever(MINIGAME_FEVER_LOSS)
	return "No bones this time. She had fun though."

## Card games only (not built yet). Returns false if the bet is not allowed.
func start_wager(amount: int) -> bool:
	if amount < 1 or amount > max_bet():
		return false
	marrow -= amount
	minigame_active = true
	marrow_changed.emit()
	return true

func end_wager(won: bool, amount: int, payout_mult := 2.0) -> String:
	minigame_active = false
	if won:
		var back := int(roundf(amount * payout_mult))
		add_marrow(back)
		add_fever(MINIGAME_FEVER_WIN)
		return "+%d Marrow" % back
	add_fever(MINIGAME_FEVER_LOSS)
	return "You lost %d Marrow." % amount

## Card table settle: stake = everything you put in (bet + double), back = Marrow
## returned (stake included). Fever like a skill game: more for a net win.
func settle_wager(stake: int, back: int) -> String:
	minigame_active = false
	if back > 0:
		add_marrow(back)
	var net := back - stake
	if net > 0:
		add_fever(MINIGAME_FEVER_WIN)
		return "+%d Marrow" % net
	if net == 0:
		add_fever(MINIGAME_FEVER_LOSS * 0.5)
		return "Push. Your %d Marrow comes back." % stake
	add_fever(MINIGAME_FEVER_LOSS)
	return "-%d Marrow" % -net

func rebury_gain() -> int:
	var g := floorf(sqrt(run_bones / Balance.REBURY_DIVISOR))
	return int(floorf(g * costume_fx().get("marrow_mult", 1.0)))

func rebury() -> bool:
	var g := rebury_gain()
	if g < 1:
		return false
	add_marrow(g)
	rebury_count += 1
	# Every manager you had hired this run stays loyal: +1 tier (permanent).
	var promoted: Array = []
	for i in Balance.BUILDINGS.size():
		if managers[i] and loyalty[i] < Balance.LOYALTY_MAX:
			loyalty[i] = maxi(loyalty[i], 1) + 1   # hired = at least tier 1
			promoted.append(i)
	new_run(true)
	marrow_changed.emit()
	reburied.emit(g, promoted)
	say.emit("rebury", 3)
	_refresh_all()
	save_game()
	return true

# =====================================================================
# Save / load / offline
# =====================================================================
func to_dict() -> Dictionary:
	return {
		"v": SAVE_VERSION, "time": Time.get_unix_time_from_system(),
		"bones": bones, "run_bones": run_bones, "total_bones": total_bones,
		"marrow": marrow, "marrow_earned": marrow_earned, "schemes": schemes.keys(), "rank": rank, "rebury_count": rebury_count,
		"owned": owned, "managers": managers, "progress": progress, "running": running,
		"buff_mult": buff_mult, "buff_left": buff_left, "marrow_claimed": marrow_claimed,
		"loyalty": loyalty, "scenes_seen": scenes_seen, "level_xp": level_xp,
		"df_best_score": df_best_score, "df_best_wave": df_best_wave,
		"costumes_owned": costumes_owned, "costume": costume,
		"inventory": inventory, "equipped": equipped,
		"fever": fever, "fever_active": fever_active, "fever_left": fever_left,
		"fever_total": fever_total, "buy_mode_idx": buy_mode_idx,
		"challenges": Challenges.to_dict(),
		"table_away": table_away, "fast_table": fast_table, "df_assist": df_assist, "df_replays": df_replays, "sfx_on": sfx_on,
	}

## Seconds until a Hold'em player who went home broke comes back (0 = here).
func away_left(id: String) -> float:
	return maxf(0.0, float(table_away.get(id, 0.0)) - Time.get_unix_time_from_system())

func send_home(id: String) -> void:
	table_away[id] = Time.get_unix_time_from_system() + TABLE_AWAY_SECS

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Save file unreadable; starting fresh.")
		return
	from_dict(data)
	var away: float = Time.get_unix_time_from_system() - float(data.get("time", 0.0))
	grant_offline(away)

func from_dict(d: Dictionary) -> void:
	bones = float(d.get("bones", 0.0))
	run_bones = float(d.get("run_bones", 0.0))
	total_bones = float(d.get("total_bones", 0.0))
	marrow = int(d.get("marrow", 0))
	marrow_earned = maxi(int(d.get("marrow_earned", 0)), marrow)
	schemes = {}
	for sid in d.get("schemes", []):
		schemes[String(sid)] = true
	_recount_schemes()
	rank = int(d.get("rank", 0))
	rebury_count = int(d.get("rebury_count", 0))
	var n := Balance.BUILDINGS.size()
	for i in n:
		owned[i] = int(_arr(d, "owned", i, owned[i]))
		managers[i] = bool(_arr(d, "managers", i, false))
		progress[i] = float(_arr(d, "progress", i, 0.0))
		running[i] = bool(_arr(d, "running", i, false))
		buff_mult[i] = float(_arr(d, "buff_mult", i, 1.0))
		buff_left[i] = float(_arr(d, "buff_left", i, 0.0))
		marrow_claimed[i] = bool(_arr(d, "marrow_claimed", i, false))
		loyalty[i] = clampi(int(_arr(d, "loyalty", i, 0)), 0, Balance.LOYALTY_MAX)
		if managers[i] and loyalty[i] == 0:
			loyalty[i] = 1        # saves from before loyalty existed
			scenes_seen[i] = 1
		else:
			scenes_seen[i] = clampi(int(_arr(d, "scenes_seen", i, 0)), 0, loyalty[i])
	level_xp = float(d.get("level_xp", total_bones))
	df_best_score = int(d.get("df_best_score", 0))
	df_best_wave = int(d.get("df_best_wave", 0))
	costumes_owned = d.get("costumes_owned", ["grave_casual"])
	if not costumes_owned.has("grave_casual"):
		costumes_owned.append("grave_casual")
	costume = String(d.get("costume", "grave_casual"))
	if not costumes_owned.has(costume):
		costume = "grave_casual"
	inventory = {}
	for k in d.get("inventory", {}):
		if not Balance.item(k).is_empty():
			inventory[k] = int(d.inventory[k])
	equipped = String(d.get("equipped", ""))
	if item_count(equipped) <= 0:
		equipped = ""
	fever = float(d.get("fever", 0.0))
	fever_active = bool(d.get("fever_active", false))
	fever_left = float(d.get("fever_left", 0.0))
	fever_total = maxf(1.0, float(d.get("fever_total", Balance.FEVER_DURATION)))
	buy_mode_idx = clampi(int(d.get("buy_mode_idx", 0)), 0, BUY_MODES.size() - 1)
	Challenges.from_dict(d.get("challenges", {}))
	table_away = {}
	var ta = d.get("table_away", {})
	if ta is Dictionary:
		for k in ta:
			table_away[String(k)] = float(ta[k])
	fast_table = bool(d.get("fast_table", false))
	df_assist = bool(d.get("df_assist", true))
	df_replays = bool(d.get("df_replays", true))
	sfx_on = bool(d.get("sfx_on", true))

func _arr(d: Dictionary, key: String, i: int, fallback):
	var a = d.get(key, [])
	if a is Array and i < a.size():
		return a[i]
	return fallback

func grant_offline(seconds: float) -> void:
	if seconds < OFFLINE_MIN_SECONDS:
		return
	var amount := offline_rate() * seconds
	if amount > 0.0:
		add_bones(amount)
		pending_offline = Vector2(amount, seconds)   # UI may not exist yet at boot
		offline_earned.emit(amount, seconds)
		say.emit("welcome_back", 3)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			if autosave_enabled:
				save_game()
		NOTIFICATION_APPLICATION_PAUSED:
			if autosave_enabled:
				save_game()
			_paused_at = Time.get_unix_time_from_system()
		NOTIFICATION_APPLICATION_RESUMED:
			if _paused_at > 0.0:
				grant_offline(Time.get_unix_time_from_system() - _paused_at)
				_paused_at = 0.0

func wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
