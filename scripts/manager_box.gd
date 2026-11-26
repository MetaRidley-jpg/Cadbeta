extends PanelContainer
## The SECOND dialogue slot: a smaller box that slides in under the stage
## when you hire a manager. Plays a 3-way scene from data/manager_scenes.json:
##   m = manager (this box), c = Cadavire (main box), p = you (the reply button).

signal scene_finished(i: int, tier: int)

const PATH := "res://data/manager_scenes.json"
const CHARS_PER_SEC := 45.0

@onready var portrait: Control = %MgrPortrait
@onready var name_label: Label = %MgrName
@onready var tier_label: Label = %MgrTier
@onready var text_label: Label = %MgrText
@onready var reply: Button = %ReplyButton
@onready var skip: Button = %SkipButton

var db: Dictionary = {}
var main_box: Node
var playing := false
var index := -1
var tier := 0
var beats: Array = []
var k := 0
var _typing := false
var _shown := 0.0
var home_x := 12.0

func _ready() -> void:
	var res = load(PATH)
	db = res.data if res is JSON else JSON.parse_string(FileAccess.get_file_as_string(PATH))
	hide()
	reply.pressed.connect(_on_reply)
	skip.pressed.connect(finish)
	gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_complete_typing()
			accept_event())

static func scene_for(data: Dictionary, building_id: String, t: int) -> Array:
	var entry: Dictionary = data.get(building_id, {})
	if t <= 0:
		return entry.get("rehire", [])
	var tiers: Array = entry.get("tiers", [])
	return tiers[t - 1] if t - 1 < tiers.size() else []

func play(i: int, t: int, box: Node) -> bool:
	_quip_t = 0.0
	reply.visible = true
	skip.visible = true
	var b: Dictionary = Balance.BUILDINGS[i]
	beats = scene_for(db, b.id, t)
	if beats.is_empty():
		return false
	main_box = box
	index = i
	tier = t
	k = 0
	name_label.text = b.manager
	_refresh_tier_label()
	portrait.setup(b.id, b.manager)
	Game.scene_active = true
	main_box.lock(true)
	if not main_box.tapped.is_connected(_on_reply):
		main_box.tapped.connect(_on_reply)
	playing = true
	text_label.text = ""
	show()
	position.x = get_viewport_rect().size.x
	var tw := create_tween()
	tw.tween_property(self, "position:x", home_x, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_beat()
	return true

## Card table banter: one manager line in slot 2, no reply button, slides out by itself.
## Ignored while a real manager scene plays.
var _quip_t := 0.0

func quip(i: int, text: String, secs := 3.2) -> void:
	if playing:
		return
	var b: Dictionary = Balance.BUILDINGS[i]
	index = i
	name_label.text = b.manager
	_refresh_tier_label()
	portrait.setup(b.id, b.manager)
	text_label.text = text
	text_label.visible_characters = 0
	text_label.modulate.a = 1.0
	_shown = 0.0
	_typing = true
	reply.visible = false
	skip.visible = false
	_quip_t = secs + text.length() / CHARS_PER_SEC
	if not visible:
		show()
		position.x = get_viewport_rect().size.x
		var tw := create_tween()
		tw.tween_property(self, "position:x", home_x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _end_quip() -> void:
	_quip_t = 0.0
	var tw := create_tween()
	tw.tween_property(self, "position:x", -size.x - 20.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		hide()
		reply.visible = true
		skip.visible = true)

func _refresh_tier_label() -> void:
	var lv: int = Game.loyalty[index]
	var txt := "LOYALTY %d/%d  x%s" % [lv, Balance.LOYALTY_MAX, Fmt.mult(Game.loyalty_mult(index))]
	tier_label.text = txt

func _show_beat() -> void:
	if k >= beats.size():
		finish()
		return
	var beat: Array = beats[k]
	match beat[0]:
		"m":
			text_label.text = beat[1]
			text_label.visible_characters = 0
			text_label.modulate.a = 1.0
			_shown = 0.0
			_typing = true
		"c":
			main_box.show_scripted(beat[1], beat[2] if beat.size() > 2 else "neutral")
			text_label.modulate.a = 0.45   # manager listens
	_update_reply()

func _update_reply() -> void:
	var beat: Array = beats[k]
	if beat[0] == "p":
		reply.text = "YOU: " + beat[1]
	elif k + 1 < beats.size() and beats[k + 1][0] == "p":
		reply.text = "YOU: " + beats[k + 1][1]
	elif k + 1 >= beats.size():
		reply.text = "OK"
	else:
		reply.text = "NEXT"

func _complete_typing() -> void:
	if _typing:
		_typing = false
		text_label.visible_characters = -1

func _on_reply() -> void:
	if not playing:
		return
	if _typing or main_box.is_typing():
		_complete_typing()
		main_box.complete()
		return
	var beat: Array = beats[k]
	if beat[0] != "p" and k + 1 < beats.size() and beats[k + 1][0] == "p":
		k += 2   # you said your line by tapping it
	else:
		k += 1
	_show_beat()

func _process(delta: float) -> void:
	if _quip_t > 0.0 and not playing:
		_quip_t -= delta
		if _quip_t <= 0.0:
			_end_quip()
	if _typing:
		_shown += CHARS_PER_SEC * delta
		text_label.visible_characters = int(_shown)
		if _shown >= text_label.text.length():
			_complete_typing()

func finish() -> void:
	if not playing:
		return
	playing = false
	_typing = false
	Game.scene_active = false
	main_box.lock(false)
	var tw := create_tween()
	tw.tween_property(self, "position:x", -size.x - 20.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(hide)
	scene_finished.emit(index, tier)
