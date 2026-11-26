extends Node
## Autoload "Lines". Picks dialogue lines from data/dialogue.json.
## Lookup order: caveman.<key> > fever.<key> > <key>, and each also tries
## the parent key (gift.dog_chew -> gift).

const PATH := "res://data/dialogue.json"
const NO_REPEAT := 3

var db: Dictionary = {}
var _recent: Dictionary = {}   # key -> Array of recent indexes

func _ready() -> void:
	# load() makes Godot treat the file as a JSON resource, so exports include it.
	var res = load(PATH)
	var parsed = res.data if res is JSON else JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		db = parsed
	else:
		push_error("dialogue.json failed to parse")

func resolve_key(category: String) -> String:
	var prefixes: Array = []
	if Game.costume_fx().get("eat_anything", false):
		prefixes.append("caveman.")
	if Game.fever_active:
		prefixes.append("fever.")
	prefixes.append("")
	var keys: Array = [category]
	if category.contains("."):
		keys.append(category.get_slice(".", 0))
	for p in prefixes:
		for k in keys:
			if db.has(p + k) and db[p + k] is Array and not db[p + k].is_empty():
				return p + k
	return ""

## Returns {"t": text, "e": expression} or {} if nothing fits.
func pick(category: String) -> Dictionary:
	var key := resolve_key(category)
	if key == "":
		return {}
	var pool: Array = db[key]
	var recent: Array = _recent.get(key, [])
	var choices: Array = []
	for i in pool.size():
		if not recent.has(i):
			choices.append(i)
	if choices.is_empty():
		choices = range(pool.size())
	var idx: int = choices[Game.rng.randi_range(0, choices.size() - 1)]
	recent.append(idx)
	while recent.size() > mini(NO_REPEAT, pool.size() - 1):
		recent.pop_front()
	_recent[key] = recent
	var line: Dictionary = pool[idx]
	return {"t": String(line.get("t", "...")), "e": String(line.get("e", "neutral")), "key": key}
