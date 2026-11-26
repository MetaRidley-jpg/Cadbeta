extends PanelContainer
## The ONE dialogue slot. Every screen shows Cadavire's lines here.
## Rule: never add a second dialogue box. Minigames reuse this same slot.

signal line_started(expression: String)
signal line_finished
signal tapped

const CHARS_PER_SEC := 42.0

@onready var text_label: Label = %Text
@onready var hint: Label = %Hint

var current_key := ""
var _priority := -1
var _typing := false
var _hold := 0.0
var _shown := 0.0
var _queue: Array = []
var locked := false   # a manager scene owns the box

## Scene mode: ignore normal chatter; lines stay until the scene moves on.
func lock(on: bool) -> void:
	locked = on
	_queue.clear()
	if on:
		_typing = false
		_hold = 0.0
		text_label.visible_characters = -1
		_set_dim(true)   # old line fades until she speaks in the scene
	else:
		_done()

func show_scripted(text: String, expression: String) -> void:
	show_line({"t": text, "e": expression, "key": "scene"}, 99)

func is_typing() -> bool:
	return _typing

func complete() -> void:
	if _typing:
		_finish_typing()

func _ready() -> void:
	Game.say.connect(_on_say)
	gui_input.connect(_on_gui_input)
	_set_dim(true)

func _on_say(category: String, priority: int) -> void:
	if locked:
		return
	var line := Lines.pick(category)
	if line.is_empty():
		return
	var busy := _typing or _hold > 0.0
	if busy and priority < _priority:
		if priority >= 1 and _queue.size() < 2:
			_queue.append([line, priority])
		return
	show_line(line, priority)

func show_line(line: Dictionary, priority: int) -> void:
	_priority = priority
	current_key = line.get("key", "")
	text_label.text = line.t
	text_label.visible_characters = 0
	_shown = 0.0
	_typing = true
	_hold = 0.0
	_set_dim(false)
	line_started.emit(line.e)

func is_busy() -> bool:
	return _typing or _hold > 0.0

func _process(delta: float) -> void:
	if _typing:
		_shown += CHARS_PER_SEC * delta * (1.6 if Game.fever_active else 1.0)
		text_label.visible_characters = int(_shown)
		if _shown >= text_label.text.length():
			_finish_typing()
	elif _hold > 0.0:
		_hold -= delta
		if _hold <= 0.0:
			_done()

func _finish_typing() -> void:
	_typing = false
	text_label.visible_characters = -1
	_hold = INF if locked else clampf(text_label.text.length() / 14.0, 3.5, 9.0)

func _done() -> void:
	_hold = 0.0
	_priority = -1
	if not _queue.is_empty():
		var q: Array = _queue.pop_front()
		show_line(q[0], q[1])
		return
	_set_dim(true)
	line_finished.emit()

func _on_gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if _typing:
			_finish_typing()
		elif locked:
			tapped.emit()
		elif _hold > 0.0:
			_done()
		accept_event()

func _set_dim(dim: bool) -> void:
	# The box never hides: the slot stays reserved. It only dims when quiet.
	modulate.a = 0.82 if dim else 1.0
	hint.visible = not dim
