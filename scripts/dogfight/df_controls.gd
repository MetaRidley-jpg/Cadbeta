extends Control
## Multi-touch flight controls. Left side: floating stick (drag up = climb).
## Right side: BOOST (hold), DRIFT (hold), BOMB (tap), LASER (tap when charged + locked).
## PC: mouse works the same (touch emulation). Keyboard handled in df_game.gd.

const STICK_RADIUS := 95.0
const BUTTON_R := {"boost": 62.0, "drift": 50.0, "bomb": 44.0, "laser": 46.0}

var turn := 0.0
var pitch := 0.0
var boost := false
var drift := false
var bomb_queued := false
var laser_queued := false
var roll_queued := false    # double-tap the stick = barrel roll
var _last_stick_up := -10.0
var laser_charge := 0.0     # set by the game (0..1)
var laser_locked := false
var enabled := true

var _touches := {}          # index -> role
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _stick_index := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func button_centers() -> Dictionary:
	var s := size
	return {
		"boost": Vector2(s.x - 92.0, s.y - 110.0),
		"drift": Vector2(s.x - 228.0, s.y - 82.0),
		"bomb": Vector2(s.x - 92.0, s.y - 250.0),
		"laser": Vector2(s.x - 228.0, s.y - 214.0),
	}

func _role_at(p: Vector2) -> String:
	var bc := button_centers()
	for k in bc:
		if p.distance_to(bc[k]) < BUTTON_R[k] + 18.0:
			return k
	if p.x < size.x * 0.6 and p.y > size.y * 0.45:
		return "stick"
	return ""

func _input(e: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	if e is InputEventScreenTouch:
		var lp: Vector2 = e.position - global_position
		if e.pressed:
			if not Rect2(Vector2.ZERO, size).has_point(lp):
				return
			var role := _role_at(lp)
			if role == "":
				return
			_touches[e.index] = role
			match role:
				"stick":
					_stick_index = e.index
					_stick_origin = lp
					_stick_pos = lp
					var now := Time.get_ticks_msec() / 1000.0
					if now - _last_stick_up < 0.28:
						roll_queued = true          # second tap: barrel roll
				"boost":
					boost = true
				"drift":
					drift = true
				"bomb":
					bomb_queued = true
				"laser":
					laser_queued = true
			get_viewport().set_input_as_handled()
		elif _touches.has(e.index):
			var role: String = _touches[e.index]
			_touches.erase(e.index)
			match role:
				"stick":
					_stick_index = -1
					_last_stick_up = Time.get_ticks_msec() / 1000.0
					turn = 0.0
					pitch = 0.0
				"boost":
					boost = false
				"drift":
					drift = false
			get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag and e.index == _stick_index:
		_stick_pos = e.position - global_position
		var d := (_stick_pos - _stick_origin) / STICK_RADIUS
		if d.length() > 1.0:
			d = d.normalized()
		turn = d.x
		pitch = -d.y          # drag up = climb
		get_viewport().set_input_as_handled()
	queue_redraw()

func release_all() -> void:
	_touches.clear()
	_stick_index = -1
	turn = 0.0
	pitch = 0.0
	boost = false
	drift = false
	bomb_queued = false
	laser_queued = false
	roll_queued = false
	queue_redraw()

func _draw() -> void:
	if not enabled:
		return
	var font := get_theme_default_font()
	var white := Color(1, 1, 1, 0.85)
	var dim := Color(1, 1, 1, 0.22)
	if _stick_index >= 0:
		draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 40, white, 3.0)
		var k := _stick_origin + (_stick_pos - _stick_origin).limit_length(STICK_RADIUS)
		draw_circle(k, 34.0, Color(1, 1, 1, 0.5))
	else:
		var c := Vector2(size.x * 0.25, size.y - 120.0)
		draw_arc(c, STICK_RADIUS, 0, TAU, 40, dim, 2.0)
		draw_string(font, c + Vector2(-70, 6), "DRAG TO STEER", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, dim)
		draw_string(font, c + Vector2(-70, 28), "DOUBLE-TAP: ROLL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, dim)
	var bc := button_centers()
	var cols := {"boost": Color("f26a1b"), "drift": Color("43c6b8"), "bomb": Color("efe6d2"), "laser": Color("ff1f4b")}
	var ready := laser_charge >= 1.0
	var on := {"boost": boost, "drift": drift, "bomb": bomb_queued, "laser": ready and laser_locked}
	for k in bc:
		var col: Color = cols[k]
		draw_circle(bc[k], BUTTON_R[k], Color(col, 0.55 if on[k] else 0.22))
		draw_arc(bc[k], BUTTON_R[k], 0, TAU, 40, Color(col, 0.95), 3.0)
		if k == "laser":   # charge ring
			draw_arc(bc[k], BUTTON_R[k] + 7.0, -PI * 0.5, -PI * 0.5 + TAU * laser_charge, 40,
				Color(col, 1.0 if ready else 0.6), 5.0)
		var t: String = k.to_upper()
		if k == "laser" and ready:
			t = "FIRE!" if laser_locked else "READY"
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, bc[k] + Vector2(-tw / 2.0, 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, white)
