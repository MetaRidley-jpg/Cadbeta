extends Node
## Autoload "Challenges". The challenge wall (based on the Super Smash Bros. Brawl Challenges screen).
##
## - 4 rows x 32 columns = 128 glass windows. All start opaque.
## - Meet a hidden condition -> that window is queued to SHATTER. The UI takes the
##   player to the wall (not during a minigame) and plays the break.
## - A broken window turns its LEFT and RIGHT neighbours into red hints: the player
##   sees the prize silhouette and the exact condition.
## - Gold windows pay a GOLDEN BONE instead of a prize. A Golden Bone breaks any
##   window at once (even a blank one), except gold windows and empty ones.
## - Cells not listed in data/challenges.json are EMPTY windows (not designed yet).
## Rewards: art (zoom/pan viewer + credits), tint (color overlay on Cadavire, stacks
## with outfits), ship (dogfight jet), table (card-table skin).
## State is saved inside Game's save file ("challenges" key).

signal cleared(id: String)      # a window was broken (queued for the shatter animation)
signal changed                  # anything changed: redraw
signal cosmetic_changed         # tint / ship / table selection changed

const DATA_PATH := "res://data/challenges.json"
const DEFAULT_SHIP := "jet_player"
const DEFAULT_TABLE := {"felt": Color("1f6e46"), "rim": Color("5a3a22")}
const COUNTERS := ["pool_wins", "gifts", "fevers", "exquisite", "df_matches"]

var rows := 4
var cols := 32
var rewards := {}        # reward id -> dict
var panels := {}         # panel id -> dict (col, row, gold, cond, text, reward)
var grid := {}           # Vector2i(col, row) -> panel id

# ---- saved ----
var done := {}           # panel id -> "met" | "bone" (broken with a Golden Bone)
var pending: Array = []  # panel ids still waiting for their shatter animation
var golden_bones := 0
var stats := {}          # event counters (COUNTERS)
var owned := {}          # reward id -> true
var tint := ""           # reward ids ("" = default)
var ship := ""
var table := ""

var enabled := true      # tests switch the 2 s auto-check off
var _timer := 0.0

func _ready() -> void:
	_load_data()
	reset_state()
	call_deferred("_hook")

func _load_data() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		push_error("challenges.json unreadable")
		return
	rows = int(d.get("rows", 4))
	cols = int(d.get("cols", 32))
	rewards = d.get("rewards", {})
	for p in d.get("panels", []):
		var cell := Vector2i(int(p.col), int(p.row))
		if grid.has(cell):
			push_error("challenges.json: two panels on %s" % cell)
			continue
		p.gold = bool(p.get("gold", false))
		panels[p.id] = p
		grid[cell] = p.id

func reset_state() -> void:
	done = {}
	pending = []
	golden_bones = 0
	owned = {}
	tint = ""
	ship = ""
	table = ""
	stats = {}
	for k in COUNTERS:
		stats[k] = 0

func _hook() -> void:
	Game.fever_mode_changed.connect(func(active: bool):
		if active:
			bump("fevers"))
	Game.taste_test.connect(func(_i: int, quality: int, _eaten: float):
		if quality >= 3:
			bump("exquisite"))

func _process(delta: float) -> void:
	if not enabled:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 2.0
		check()

# =====================================================================
# Stats + conditions
# =====================================================================
func bump(key: String, n := 1) -> void:
	stats[key] = int(stats.get(key, 0)) + n
	if enabled:
		check()

func stat(key: String) -> float:
	match key:
		"total_bones": return Game.total_bones
		"owned_max": return float(Game.owned.max())
		"owned_min": return float(Game.owned.min())
		"managers": return float(Game.managers.count(true))
		"folds": return float(Game.rebury_count)
		"rank": return float(Game.rank)
		"level": return float(Game.level())
		"df_best_wave": return float(Game.df_best_wave)
		"df_best_score": return float(Game.df_best_score)
		"costumes": return float(Game.costumes_owned.size())
		"loyalty_max": return float(Game.loyalty.max())
		"cleared": return float(done.size())
	return float(stats.get(key, 0))

## Returns the ids broken by this check.
func check() -> Array:
	var new_ids: Array = []
	for id in panels:
		if done.has(id):
			continue
		var c: Dictionary = panels[id].cond
		if stat(String(c.stat)) >= float(c.value):
			_break(id, "met")
			new_ids.append(id)
	return new_ids

func _break(id: String, how: String) -> void:
	var p: Dictionary = panels[id]
	done[id] = how
	if p.gold:
		if how == "met":
			golden_bones += 1
	elif p.has("reward"):
		owned[p.reward] = true
	pending.append(id)
	cleared.emit(id)
	changed.emit()
	if Game.autosave_enabled:
		Game.save_game()

# =====================================================================
# Wall queries (UI)
# =====================================================================
func id_at(col: int, row: int) -> String:
	return grid.get(Vector2i(col, row), "")

func is_broken(col: int, row: int) -> bool:
	return done.has(id_at(col, row))

## Red hint: a LEFT or RIGHT neighbour is broken and this one is not.
func is_hint(col: int, row: int) -> bool:
	if is_broken(col, row):
		return false
	return is_broken(col - 1, row) or is_broken(col + 1, row)

func is_gold(col: int, row: int) -> bool:
	var id := id_at(col, row)
	return id != "" and panels[id].gold

func reward_of(id: String) -> Dictionary:
	if id == "" or not panels[id].has("reward"):
		return {}
	var r: Dictionary = rewards.get(panels[id].reward, {})
	return r

func cleared_count() -> int:
	return done.size()

func designed_count() -> int:
	return panels.size()

## "" if allowed, else the reason (shown to the player).
func bone_block_reason(col: int, row: int) -> String:
	var id := id_at(col, row)
	if golden_bones <= 0:
		return "You have no Golden Bones."
	if id == "":
		return "Nothing behind this glass yet."
	if done.has(id):
		return "Already broken."
	if panels[id].gold:
		return "Golden windows cannot be broken with a Golden Bone."
	return ""

func use_golden_bone(col: int, row: int) -> bool:
	if bone_block_reason(col, row) != "":
		return false
	golden_bones -= 1
	_break(id_at(col, row), "bone")
	return true

func take_pending() -> String:
	if pending.is_empty():
		return ""
	return pending.pop_front()

# =====================================================================
# Cosmetics
# =====================================================================
func owns(reward_id: String) -> bool:
	return owned.has(reward_id)

func owned_of_type(t: String) -> Array:
	var out: Array = []
	for rid in rewards:
		if rewards[rid].type == t and owned.has(rid):
			out.append(rid)
	return out

func set_tint(rid: String) -> void:
	if rid == "" or owns(rid):
		tint = rid
		cosmetic_changed.emit()
		changed.emit()

func set_ship(rid: String) -> void:
	if rid == "" or owns(rid):
		ship = rid
		cosmetic_changed.emit()
		changed.emit()

func set_table(rid: String) -> void:
	if rid == "" or owns(rid):
		table = rid
		cosmetic_changed.emit()
		changed.emit()

## Alpha 0 = no tint.
func tint_color() -> Color:
	if tint == "" or not rewards.has(tint):
		return Color(1, 1, 1, 0)
	return Color(String(rewards[tint].color))

func ship_strip() -> String:
	if ship == "" or not rewards.has(ship):
		return DEFAULT_SHIP
	return String(rewards[ship].strip)

func table_colors() -> Dictionary:
	if table == "" or not rewards.has(table):
		return DEFAULT_TABLE
	return {"felt": Color(String(rewards[table].felt)), "rim": Color(String(rewards[table].rim))}

# =====================================================================
# Save
# =====================================================================
func to_dict() -> Dictionary:
	return {"done": done, "pending": pending, "golden_bones": golden_bones, "stats": stats,
		"owned": owned.keys(), "tint": tint, "ship": ship, "table": table}

func from_dict(d: Dictionary) -> void:
	reset_state()
	for id in d.get("done", {}):
		if panels.has(id):
			done[id] = String(d.done[id])
	for id in d.get("pending", []):
		if done.has(id) and not pending.has(id):
			pending.append(id)
	golden_bones = maxi(0, int(d.get("golden_bones", 0)))
	for k in d.get("stats", {}):
		stats[k] = int(d.stats[k])
	for rid in d.get("owned", []):
		if rewards.has(rid):
			owned[rid] = true
	tint = String(d.get("tint", ""))
	ship = String(d.get("ship", ""))
	table = String(d.get("table", ""))
	if tint != "" and not owns(tint): tint = ""
	if ship != "" and not owns(ship): ship = ""
	if table != "" and not owns(table): table = ""
