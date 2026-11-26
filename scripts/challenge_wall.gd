extends Control
## The challenge wall: 4 x 32 glass windows, swipe/drag or mouse wheel to pan,
## tap to select. A minimap strip on top shows the whole wall (tap or drag it to jump).
## Shatter: scroll to the window, crack, glass shards fly, the prize shows, then the
## left/right neighbours fade to red hints.

signal selected_changed(cell: Vector2i)
signal shatter_finished(id: String)
signal bone_target(cell: Vector2i)   # tap in Golden Bone mode

const MINI_H := 46.0
const GAP := 10.0
const GLASS_GOLD := Color("e8b33a")
const HINT_RED := Color(0.86, 0.1, 0.22)

var cell := 132.0
var pal: Dictionary = UiTheme.NORMAL
var selected := Vector2i(-1, -1)
var bone_mode := false
var unrevealed := {}           # panel ids broken in data but not yet shown (waiting to shatter)

var scroll_x := 0.0
var _vel := 0.0
var _target_x := -1.0          # auto-scroll goal (-1 = none)
var _touch := {}               # index -> position
var _press_pos := Vector2.ZERO
var _press_scroll := 0.0
var _dragging := false
var _mini_drag := false
var _t := 0.0

# shatter state
var _sh_id := ""
var _sh_cell := Vector2i(-1, -1)
var _sh_phase := ""            # "", "scroll", "crack", "fly"
var _sh_time := 0.0
var _impact := Vector2.ZERO
var _cracks: Array = []        # [PackedVector2Array]
var _shards: Array = []        # {pts, pos, vel, rot, spin, col}
var _flash := 0.0
var _hint_fade := {}           # Vector2i -> 0..1 (new hints fade in)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Challenges.changed.connect(queue_redraw)

func wall_height() -> float:
	return MINI_H + Challenges.rows * (cell + GAP) + GAP

func max_scroll() -> float:
	return maxf(0.0, GAP + Challenges.cols * (cell + GAP) - size.x)

func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(GAP + c.x * (cell + GAP) - scroll_x, MINI_H + GAP + c.y * (cell + GAP), cell, cell)

func cell_at(p: Vector2) -> Vector2i:
	var cx := int(floorf((p.x + scroll_x - GAP) / (cell + GAP)))
	var cy := int(floorf((p.y - MINI_H - GAP) / (cell + GAP)))
	if cx < 0 or cy < 0 or cx >= Challenges.cols or cy >= Challenges.rows:
		return Vector2i(-1, -1)
	if not cell_rect(Vector2i(cx, cy)).has_point(p):
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)

func scroll_to(c: Vector2i, instant := false) -> void:
	var x := clampf(GAP + c.x * (cell + GAP) + cell * 0.5 - size.x * 0.5, 0.0, max_scroll())
	if instant:
		scroll_x = x
		_target_x = -1.0
	else:
		_target_x = x
	_vel = 0.0

# =====================================================================
# Broken / hint, as SHOWN (windows waiting to shatter still look whole)
# =====================================================================
func shown_broken(c: Vector2i) -> bool:
	var id := Challenges.id_at(c.x, c.y)
	return id != "" and Challenges.done.has(id) and not unrevealed.has(id)

func shown_hint(c: Vector2i) -> bool:
	return not shown_broken(c) and (shown_broken(c + Vector2i.LEFT) or shown_broken(c + Vector2i.RIGHT))

# =====================================================================
# Shatter
# =====================================================================
func play_shatter(id: String) -> void:
	var p: Dictionary = Challenges.panels[id]
	_sh_id = id
	_sh_cell = Vector2i(int(p.col), int(p.row))
	unrevealed[id] = true
	select(_sh_cell)
	scroll_to(_sh_cell)
	_sh_phase = "scroll"
	_sh_time = 0.0

func is_shattering() -> bool:
	return _sh_phase != ""

func _start_crack() -> void:
	_sh_phase = "crack"
	_sh_time = 0.0
	var r := cell_rect(_sh_cell)
	_impact = r.position + r.size * Vector2(randf_range(0.35, 0.65), randf_range(0.35, 0.65))
	_cracks.clear()
	for k in 9:
		var a := TAU * k / 9.0 + randf_range(-0.25, 0.25)
		var line := PackedVector2Array([_impact - r.position])
		var p := _impact - r.position
		var steps := 4
		for s in steps:
			a += randf_range(-0.35, 0.35)
			p += Vector2(cos(a), sin(a)) * cell * randf_range(0.12, 0.2)
			line.append(p)
		_cracks.append(line)

func _start_fly() -> void:
	_sh_phase = "fly"
	_sh_time = 0.0
	_flash = 1.0
	unrevealed.erase(_sh_id)
	var r := cell_rect(_sh_cell)
	var gold: bool = Challenges.panels[_sh_id].gold
	# rim points around the window, fan triangles from the impact, each split once
	var rim: Array = []
	var n := 9
	var start := randf()
	for k in n:
		rim.append(_perimeter(r, start + (float(k) + randf_range(-0.2, 0.2)) / n))
	_shards.clear()
	for k in n:
		var a: Vector2 = rim[k]
		var b: Vector2 = rim[(k + 1) % n]
		# chunky shards: split each fan wedge once across the middle
		var ma := _impact.lerp(a, randf_range(0.4, 0.6))
		var mb := _impact.lerp(b, randf_range(0.4, 0.6))
		for poly in [[_impact, ma, mb], [ma, a, b, mb]]:
			var c := Vector2.ZERO
			for q in poly:
				c += q
			c /= poly.size()
			var pts := PackedVector2Array()
			for q in poly:
				pts.append(q - c)
			var out := (c - _impact).normalized()
			_shards.append({"pts": pts, "pos": c, "vel": out * randf_range(240, 560) + Vector2(0, -randf_range(150, 420)),
				"rot": 0.0, "spin": randf_range(-8, 8), "col": _glass_color(gold).lightened(randf_range(0.0, 0.3))})
	for nb in [_sh_cell + Vector2i.LEFT, _sh_cell + Vector2i.RIGHT]:
		if nb.x >= 0 and nb.x < Challenges.cols and not shown_broken(nb):
			_hint_fade[nb] = 0.0

func _perimeter(r: Rect2, t: float) -> Vector2:
	t = fposmod(t, 1.0) * 4.0
	if t < 1.0: return r.position + Vector2(r.size.x * t, 0)
	if t < 2.0: return r.position + Vector2(r.size.x, r.size.y * (t - 1.0))
	if t < 3.0: return r.position + Vector2(r.size.x * (3.0 - t), r.size.y)
	return r.position + Vector2(0, r.size.y * (4.0 - t))

func _process(delta: float) -> void:
	_t += delta
	if _target_x >= 0.0:
		scroll_x = lerpf(scroll_x, _target_x, minf(1.0, delta * 9.0))
		if absf(scroll_x - _target_x) < 0.5:
			scroll_x = _target_x
			_target_x = -1.0
	elif not _dragging and absf(_vel) > 1.0:
		scroll_x = clampf(scroll_x + _vel * delta, 0.0, max_scroll())
		_vel = move_toward(_vel, 0.0, maxf(absf(_vel) * 3.5, 400.0) * delta)
	scroll_x = clampf(scroll_x, 0.0, max_scroll())
	for k in _hint_fade.keys():
		_hint_fade[k] = minf(1.0, _hint_fade[k] + delta * 1.6)
		if _hint_fade[k] >= 1.0 and _sh_phase == "":
			_hint_fade.erase(k)
	_flash = maxf(0.0, _flash - delta * 3.0)
	match _sh_phase:
		"scroll":
			_sh_time += delta
			if _target_x < 0.0 and _sh_time > 0.35:
				_start_crack()
		"crack":
			_sh_time += delta
			if _sh_time > 0.45:
				_start_fly()
		"fly":
			_sh_time += delta
			for s in _shards:
				s.vel.y += 1700.0 * delta
				s.pos += s.vel * delta
				s.rot += s.spin * delta
			if _sh_time > 1.1:
				_shards.clear()
				_sh_phase = ""
				var id := _sh_id
				_sh_id = ""
				shatter_finished.emit(id)
	queue_redraw()

# =====================================================================
# Input
# =====================================================================
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN or e.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			_target_x = -1.0
			scroll_x = clampf(scroll_x + cell * 0.8, 0.0, max_scroll())
			accept_event()
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			_target_x = -1.0
			scroll_x = clampf(scroll_x - cell * 0.8, 0.0, max_scroll())
			accept_event()
	elif e is InputEventScreenTouch:
		if e.pressed:
			_touch[e.index] = e.position
			if e.index == 0:
				_press_pos = e.position
				_press_scroll = scroll_x
				_dragging = false
				_vel = 0.0
				_target_x = -1.0
				_mini_drag = e.position.y < MINI_H
				if _mini_drag:
					_mini_jump(e.position.x)
		else:
			_touch.erase(e.index)
			if e.index == 0:
				if not _dragging and not _mini_drag and not is_shattering():
					var c := cell_at(e.position)
					if c.x >= 0:
						if bone_mode:
							bone_target.emit(c)
						select(c)
				_dragging = false
				_mini_drag = false
		accept_event()
	elif e is InputEventScreenDrag and e.index == 0:
		if _mini_drag:
			_mini_jump(e.position.x)
		else:
			if absf(e.position.x - _press_pos.x) > 14.0:
				_dragging = true
			if _dragging:
				scroll_x = clampf(_press_scroll - (e.position.x - _press_pos.x), 0.0, max_scroll())
				_vel = -e.velocity.x
		accept_event()

func _mini_jump(x: float) -> void:
	var m := _mini_rect()
	var t := clampf((x - m.position.x) / m.size.x, 0.0, 1.0)
	scroll_x = clampf(t * (max_scroll() + size.x) - size.x * 0.5, 0.0, max_scroll())
	_target_x = -1.0

func select(c: Vector2i) -> void:
	selected = c
	selected_changed.emit(c)
	queue_redraw()

# =====================================================================
# Drawing
# =====================================================================
func _mini_rect() -> Rect2:
	var w := minf(size.x - 2.0 * GAP, Challenges.cols * 19.0)
	return Rect2((size.x - w) * 0.5, 8.0, w, MINI_H - 18.0)

func _glass_color(gold: bool) -> Color:
	return GLASS_GOLD if gold else pal.card_hi.lightened(0.22)

func _draw() -> void:
	# minimap
	var m := _mini_rect()
	var cw := m.size.x / Challenges.cols
	var ch := m.size.y / Challenges.rows
	draw_rect(m.grow(3), pal.bg)
	for x in Challenges.cols:
		for y in Challenges.rows:
			var c := Vector2i(x, y)
			var col: Color = pal.card_hi
			if shown_broken(c):
				col = pal.accent2
			elif shown_hint(c):
				col = HINT_RED
			elif Challenges.is_gold(x, y):
				col = GLASS_GOLD.darkened(0.25)
			draw_rect(Rect2(m.position + Vector2(x * cw + 1, y * ch + 1), Vector2(cw - 2, ch - 2)), col)
	var total := max_scroll() + size.x
	var vx := m.position.x + scroll_x / total * m.size.x
	var vw := size.x / total * m.size.x
	draw_rect(Rect2(vx, m.position.y - 3, vw, m.size.y + 6), pal.text, false, 2.0)

	# windows
	var first := maxi(0, int((scroll_x - GAP) / (cell + GAP)))
	var last := mini(Challenges.cols - 1, int((scroll_x + size.x) / (cell + GAP)) + 1)
	for x in range(first, last + 1):
		for y in Challenges.rows:
			_draw_window(Vector2i(x, y))
	# shards on top
	for s in _shards:
		var a := clampf(1.0 - (_sh_time - 0.6) / 0.5, 0.0, 1.0)
		draw_set_transform(s.pos, s.rot, Vector2.ONE)
		draw_colored_polygon(s.pts, Color(s.col, 0.92 * a))
		var outline: PackedVector2Array = s.pts.duplicate()
		outline.append(s.pts[0])
		draw_polyline(outline, Color(1, 1, 1, 0.7 * a), 2.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_window(c: Vector2i) -> void:
	var r := cell_rect(c)
	var id := Challenges.id_at(c.x, c.y)
	var gold: bool = id != "" and Challenges.panels[id].gold
	var sel := c == selected
	# recessed frame
	draw_rect(r.grow(4), pal.bg.darkened(0.35))
	draw_rect(r, pal.bg.lerp(pal.card, 0.5))
	var hint := shown_hint(c)
	var hint_a: float = _hint_fade.get(c, 1.0)
	if shown_broken(c):
		_draw_open(r, id)
	elif hint:
		# behind red glass: the prize silhouette
		draw_rect(r, pal.bg.lerp(pal.card, 0.5))
		if id != "":
			ChallengeIcons.draw_prize(self, Challenges.panels[id], r.grow(-r.size.x * 0.16), pal, true)
		else:
			_draw_center_text(r, "—", Color(1, 1, 1, 0.35), 34)
		var hg := _glass_color(gold).lerp(HINT_RED, hint_a)
		draw_rect(r, Color(hg, lerpf(1.0, 0.5, hint_a)))
		_draw_sheen(r, 0.12)
	else:
		_draw_glass(r, gold)
		if c == _sh_cell and _sh_phase == "crack":
			var k := clampf(_sh_time / 0.3, 0.0, 1.0)
			for line in _cracks:
				var n := maxi(2, int(ceilf(line.size() * k)))
				var pts := PackedVector2Array()
				for i in n:
					pts.append(r.position + line[i])
				draw_polyline(pts, Color(1, 1, 1, 0.9), 2.0)
			var jit := Vector2(sin(_t * 90.0), cos(_t * 77.0)) * 2.0
			draw_rect(Rect2(r.position + jit, r.size), Color(1, 1, 1, 0.08 * k))
	if c == _sh_cell and _flash > 0.0:
		draw_rect(r.grow(6), Color(1, 1, 1, _flash * 0.85))
	if bone_mode and Challenges.bone_block_reason(c.x, c.y) == "":
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_rect(r.grow(2), Color(GLASS_GOLD, 0.5 + 0.5 * pulse), false, 3.0)
	if sel:
		draw_rect(r.grow(5), pal.accent2, false, 4.0)

func _draw_glass(r: Rect2, gold: bool) -> void:
	var base := _glass_color(gold)
	# vertical gradient in 6 bands (pixel-flat, retro)
	for i in 6:
		var t := i / 5.0
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y * i / 6.0, r.size.x, r.size.y / 6.0 + 1.0),
			base.lightened(0.18 * (1.0 - t)).darkened(0.18 * t))
	_draw_sheen(r, 0.22 if gold else 0.16)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(1, 1, 1, 0.35))
	if gold:
		ChallengeIcons.draw_bone(self, r.get_center(), r.size.x * 0.34, Color(1, 0.95, 0.7, 0.35), -0.6)

func _draw_sheen(r: Rect2, a: float) -> void:
	var s := r.size
	var p := r.position
	draw_colored_polygon(PackedVector2Array([p + Vector2(s.x * 0.15, 0), p + Vector2(s.x * 0.42, 0),
		p + Vector2(0, s.y * 0.42), p + Vector2(0, s.y * 0.15)]), Color(1, 1, 1, a))
	draw_colored_polygon(PackedVector2Array([p + Vector2(s.x * 0.55, 0), p + Vector2(s.x * 0.62, 0),
		p + Vector2(0, s.y * 0.62), p + Vector2(0, s.y * 0.55)]), Color(1, 1, 1, a * 0.7))

func _draw_open(r: Rect2, id: String) -> void:
	var p: Dictionary = Challenges.panels[id]
	draw_rect(r, pal.card)
	ChallengeIcons.draw_prize(self, p, r.grow(-r.size.x * 0.14), pal, false)
	# jagged glass left in the frame
	var g := Color(_glass_color(p.gold), 0.75)
	var q := r.position
	var s := r.size.x
	draw_colored_polygon(PackedVector2Array([q, q + Vector2(s * 0.22, 0), q + Vector2(s * 0.08, s * 0.1), q + Vector2(0, s * 0.2)]), g)
	draw_colored_polygon(PackedVector2Array([q + Vector2(s, s), q + Vector2(s * 0.8, s), q + Vector2(s * 0.92, s * 0.9), q + Vector2(s, s * 0.74)]), g)
	if Challenges.done.get(id, "") == "bone":
		ChallengeIcons.draw_bone(self, q + Vector2(s - 18, 18), 22.0, GLASS_GOLD, -0.6)

func _draw_center_text(r: Rect2, text: String, col: Color, sz: int) -> void:
	var f := get_theme_default_font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string(f, Vector2(r.get_center().x - w * 0.5, r.get_center().y + sz * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
