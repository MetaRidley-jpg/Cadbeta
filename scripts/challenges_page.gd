extends VBoxContainer
## Challenges screen: header, the wall, and an info card for the selected window.
## main.gd opens it from the top bar button, or by itself when a window breaks.

signal back_pressed
signal view_art(reward_id: String)

const WallScript := preload("res://scripts/challenge_wall.gd")

var wall: Control
var _count: Label
var _bone_btn: Button
var _back_btn: Button
var _preview: Control
var _where: Label
var _name: Label
var _cond: Label
var _status: Label
var _action: Button
var _t := 0.0

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	add_child(head)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	var t := Label.new()
	t.text = "CHALLENGES"
	t.theme_type_variation = "NamePlate"
	tv.add_child(t)
	_count = Label.new()
	_count.theme_type_variation = "TitleLabel"
	tv.add_child(_count)
	_bone_btn = Button.new()
	_bone_btn.theme_type_variation = "GhostButton"
	_bone_btn.custom_minimum_size = Vector2(210, 56)
	_bone_btn.pressed.connect(_toggle_bone_mode)
	head.add_child(_bone_btn)
	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_back_btn.custom_minimum_size = Vector2(120, 56)
	_back_btn.pressed.connect(func(): back_pressed.emit())
	head.add_child(_back_btn)

	wall = WallScript.new()
	wall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(wall)
	wall.custom_minimum_size.y = wall.wall_height()
	wall.selected_changed.connect(func(_c): _refresh_info())
	wall.shatter_finished.connect(_on_shatter_finished)

	var card := PanelContainer.new()
	card.theme_type_variation = "CardHi"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(card)
	var h := HBoxContainer.new()
	card.add_child(h)
	_preview = Control.new()
	_preview.custom_minimum_size = Vector2(150, 150)
	_preview.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.draw.connect(_draw_preview)
	h.add_child(_preview)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	h.add_child(info)
	_where = _lbl(info, "NamePlate")
	_name = _lbl(info, "TitleLabel")
	_cond = _lbl(info, "SmallLabel")
	_status = _lbl(info, "AccentLabel")
	_action = Button.new()
	_action.custom_minimum_size = Vector2(0, 56)
	_action.pressed.connect(_on_action)
	info.add_child(_action)

	Challenges.cleared.connect(_on_cleared)
	Challenges.changed.connect(_refresh_header)

func _lbl(parent: Node, v: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = v
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 100
	parent.add_child(l)
	return l

func set_palette(p: Dictionary) -> void:
	if wall:
		wall.pal = p

## Called each time the page is shown.
func open() -> void:
	wall.bone_mode = false
	for id in Challenges.pending:
		wall.unrevealed[id] = true
	_refresh_header()
	if wall.selected.x < 0:
		wall.select(_first_interesting())
	await get_tree().process_frame     # wall has its size now
	if not Challenges.pending.is_empty():
		_next_pending()
	else:
		wall.scroll_to(wall.selected, true)
	_refresh_info()

func _first_interesting() -> Vector2i:
	for x in Challenges.cols:
		for y in Challenges.rows:
			if wall.shown_hint(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(0, 0)

func is_busy() -> bool:
	return wall.is_shattering() or not Challenges.pending.is_empty()

func _next_pending() -> void:
	if wall.is_shattering():
		return
	var id := Challenges.take_pending()
	if id != "":
		wall.play_shatter(id)

func _on_cleared(id: String) -> void:
	if not is_visible_in_tree():
		return
	wall.unrevealed[id] = true
	wall.bone_mode = false
	_next_pending()

func _on_shatter_finished(id: String) -> void:
	var p: Dictionary = Challenges.panels[id]
	Game.say.emit("challenge_gold" if p.gold else "challenge", 4)
	_refresh_header()
	_refresh_info()
	if not Challenges.pending.is_empty():
		await get_tree().create_timer(0.6).timeout
		_next_pending()

func _toggle_bone_mode() -> void:
	wall.bone_mode = not wall.bone_mode
	_refresh_header()
	_refresh_info()

func _refresh_header() -> void:
	if _count == null:
		return
	_count.text = "%d / %d broken" % [Challenges.cleared_count(), Challenges.rows * Challenges.cols]
	_bone_btn.text = "CANCEL" if wall.bone_mode else "GOLDEN BONE x%d" % Challenges.golden_bones
	_bone_btn.disabled = Challenges.golden_bones <= 0 and not wall.bone_mode

func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		_preview.queue_redraw()
		_back_btn.disabled = wall.is_shattering()

# =====================================================================
# Info card
# =====================================================================
func _refresh_info() -> void:
	var c: Vector2i = wall.selected
	_action.visible = false
	if c.x < 0:
		_where.text = ""
		_name.text = "Tap a window."
		_cond.text = ""
		_status.text = ""
		return
	var id := Challenges.id_at(c.x, c.y)
	var p: Dictionary = Challenges.panels.get(id, {})
	_where.text = "WINDOW %d · ROW %d%s" % [c.x + 1, c.y + 1, "  · GOLD" if p.get("gold", false) else ""]
	if wall.shown_broken(c):
		var rw := Challenges.reward_of(id)
		_name.text = "Golden Bone" if p.gold else String(rw.get("name", "?"))
		_cond.text = String(p.text)
		_status.text = "Broken with a Golden Bone." if Challenges.done[id] == "bone" else ("Broken. +1 Golden Bone." if p.gold else "Broken. Prize unlocked.")
		_set_action_for(rw, String(p.get("reward", "")))
	elif wall.shown_hint(c):
		_name.text = "???" if id != "" else "Empty window"
		_cond.text = String(p.text) if id != "" else "Nothing designed here yet."
		_status.text = "Hint: meet this condition to break it." if id != "" else ""
	else:
		_name.text = "???"
		_cond.text = "Break a window next to this one to see what it asks for."
		_status.text = ""
	if wall.bone_mode:
		var why := Challenges.bone_block_reason(c.x, c.y)
		_action.visible = true
		_action.text = "BREAK IT (GOLDEN BONE)"
		_action.disabled = why != ""
		_status.text = why if why != "" else "Tap BREAK IT to use 1 Golden Bone here."

func _set_action_for(rw: Dictionary, rid: String) -> void:
	_action.disabled = false
	match String(rw.get("type", "")):
		"art":
			_action.visible = true
			_action.text = "VIEW ART"
		"tint":
			_action.visible = true
			_action.text = "REMOVE TINT" if Challenges.tint == rid else "WEAR TINT"
		"ship":
			_action.visible = true
			_action.text = "USE DEFAULT JET" if Challenges.ship == rid else "FLY THIS JET"
		"table":
			_action.visible = true
			_action.text = "USE DEFAULT TABLE" if Challenges.table == rid else "USE THIS TABLE"

func _on_action() -> void:
	var c: Vector2i = wall.selected
	if wall.bone_mode:
		if Challenges.use_golden_bone(c.x, c.y):
			wall.bone_mode = false
		_refresh_header()
		_refresh_info()
		return
	var id := Challenges.id_at(c.x, c.y)
	var rid := String(Challenges.panels.get(id, {}).get("reward", ""))
	var rw := Challenges.reward_of(id)
	match String(rw.get("type", "")):
		"art":
			view_art.emit(rid)
		"tint":
			Challenges.set_tint("" if Challenges.tint == rid else rid)
			if Challenges.tint != "":
				Game.say.emit("tint_wear", 3)
		"ship":
			Challenges.set_ship("" if Challenges.ship == rid else rid)
		"table":
			Challenges.set_table("" if Challenges.table == rid else rid)
	_refresh_info()

func _draw_preview() -> void:
	var r := Rect2(Vector2.ZERO, _preview.size)
	var pal: Dictionary = wall.pal
	_preview.draw_rect(r, pal.bg)
	var c: Vector2i = wall.selected
	if c.x < 0:
		return
	var id := Challenges.id_at(c.x, c.y)
	if id == "":
		return
	if wall.shown_broken(c):
		ChallengeIcons.draw_prize(_preview, Challenges.panels[id], r.grow(-16), pal, false, -0.7 + _t * 0.9)
	elif wall.shown_hint(c):
		ChallengeIcons.draw_prize(_preview, Challenges.panels[id], r.grow(-16), pal, true, -0.7)
