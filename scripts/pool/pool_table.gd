extends Control
## Draws the pool table and handles aiming (touch the table = aim at your finger).
## Art hooks later: felt/rail textures, ball sprites. Now: clean vector drawing.

const RAIL := 30.0          # rail width in table units
const POCKET_DRAW := 25.0
const BALL_COLORS := [Color("efe6d2"), Color("f2c230"), Color("2f5fd0"), Color("d63a2f"),
	Color("6b3fa0"), Color("f2771a"), Color("2e8b57"), Color("7a1f2b"), Color("151515")]

var game: Node              # pool_game.gd
var _scale := 1.0
var _origin := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)

func _layout() -> void:
	var tw := PoolSim.W + RAIL * 2.0
	var th := PoolSim.H + RAIL * 2.0
	_scale = minf(size.x / tw, size.y / th)
	_origin = (size - Vector2(tw, th) * _scale) / 2.0 + Vector2(RAIL, RAIL) * _scale

func to_screen(p: Vector2) -> Vector2:
	return _origin + p * _scale

func to_world(s: Vector2) -> Vector2:
	return (s - _origin) / _scale

func _gui_input(e: InputEvent) -> void:
	if game == null or not game.can_aim():
		return
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT)):
		var w := to_world(e.position)
		var cue: Vector2 = game.sim.pos[0]
		if w.distance_to(cue) > 4.0:
			game.set_aim((w - cue).normalized())
		accept_event()

func _process(_d: float) -> void:
	queue_redraw()

# ---------------------------------------------------------------- guide ray
## First thing the cue ball meets along dir: {point, ball (-1 = rail), ghost}
static func ray_guide(sim: PoolSim, dir: Vector2) -> Dictionary:
	var o: Vector2 = sim.pos[0]
	var best_t := INF
	var hit := -1
	for i in range(1, 16):
		if sim.down[i]:
			continue
		var oc: Vector2 = o - sim.pos[i]
		var b := dir.dot(oc)
		var c := oc.length_squared() - 4.0 * PoolSim.R * PoolSim.R
		var disc := b * b - c
		if disc < 0.0:
			continue
		var t := -b - sqrt(disc)
		if t > 0.0 and t < best_t:
			best_t = t
			hit = i
	var rail_t := INF
	if dir.x > 0.0001:
		rail_t = minf(rail_t, (PoolSim.W - PoolSim.R - o.x) / dir.x)
	elif dir.x < -0.0001:
		rail_t = minf(rail_t, (PoolSim.R - o.x) / dir.x)
	if dir.y > 0.0001:
		rail_t = minf(rail_t, (PoolSim.H - PoolSim.R - o.y) / dir.y)
	elif dir.y < -0.0001:
		rail_t = minf(rail_t, (PoolSim.R - o.y) / dir.y)
	if rail_t < best_t:
		return {"point": o + dir * rail_t, "ball": -1}
	return {"point": o + dir * best_t, "ball": hit}

# ---------------------------------------------------------------- drawing
func _draw() -> void:
	if game == null:
		return
	_layout()
	var sim: PoolSim = game.sim
	var fever: bool = Game.fever_active
	var rail_col := Color("3a2a22") if not fever else Color("4a1238")
	var rail_edge := Color("f26a1b") if not fever else Color("ff3d8b")
	var felt := Color("17544d") if not fever else Color("5e1450")
	var felt_dark := felt.darkened(0.18)
	var s := _scale
	var outer := Rect2(to_screen(Vector2(-RAIL, -RAIL)), Vector2(PoolSim.W + RAIL * 2, PoolSim.H + RAIL * 2) * s)
	var inner := Rect2(to_screen(Vector2.ZERO), Vector2(PoolSim.W, PoolSim.H) * s)
	var sb := StyleBoxFlat.new()
	sb.bg_color = rail_col
	sb.set_corner_radius_all(int(22 * s))
	sb.border_color = rail_edge
	sb.set_border_width_all(maxi(2, int(3 * s)))
	draw_style_box(sb, outer)
	draw_rect(inner, felt)
	draw_rect(inner.grow(-6 * s), felt_dark, false, 2.0)
	# head string + foot spot
	var hy := to_screen(Vector2(0, PoolSim.HEAD_SPOT.y)).y
	draw_line(Vector2(inner.position.x, hy), Vector2(inner.end.x, hy), Color(1, 1, 1, 0.08), 2.0)
	draw_circle(to_screen(PoolSim.FOOT_SPOT), 3.0 * s, Color(1, 1, 1, 0.15))
	# diamonds
	for k in range(1, 4):
		var x := PoolSim.W * k / 4.0
		for y in [-RAIL * 0.5, PoolSim.H + RAIL * 0.5]:
			draw_circle(to_screen(Vector2(x, y)), 3.0 * s, Color(1, 1, 1, 0.5))
	for k in [1, 2, 3, 5, 6, 7]:
		var y: float = PoolSim.H * k / 8.0
		for x in [-RAIL * 0.5, PoolSim.W + RAIL * 0.5]:
			draw_circle(to_screen(Vector2(x, y)), 3.0 * s, Color(1, 1, 1, 0.5))
	for pk in PoolSim.pockets():
		draw_circle(to_screen(pk), POCKET_DRAW * s, Color("0a0809"))
		draw_arc(to_screen(pk), POCKET_DRAW * s, 0, TAU, 24, rail_edge.darkened(0.3), 2.0)
	# balls
	for i in 16:
		if not sim.down[i]:
			_draw_ball(i, to_screen(sim.pos[i]), PoolSim.R * s)
	# guide + cue
	if game.show_cue():
		_draw_guide(sim, game.aim_dir, game.turn == PoolSim.Side.PLAYER)
		_draw_cue(sim, game.aim_dir, game.power)

func _draw_ball(i: int, c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(r * 0.18, r * 0.22), r, Color(0, 0, 0, 0.35))   # shadow
	if i == 0:
		# cue ball = a little skull
		draw_circle(c, r, BALL_COLORS[0])
		var ink := Color("2a2026")
		draw_circle(c + Vector2(-0.36 * r, -0.12 * r), 0.2 * r, ink)
		draw_circle(c + Vector2(0.36 * r, -0.12 * r), 0.2 * r, ink)
		draw_line(c + Vector2(-0.12 * r, 0.42 * r), c + Vector2(0.12 * r, 0.42 * r), ink, maxf(1.0, r * 0.1))
	elif i == 8:
		draw_circle(c, r, BALL_COLORS[8])
		draw_circle(c, r * 0.42, Color.WHITE)
		draw_circle(c, r * 0.18, BALL_COLORS[8])
	elif i < 8:
		draw_circle(c, r, BALL_COLORS[i])
		draw_circle(c, r * 0.4, Color(1, 1, 1, 0.9))
	else:
		draw_circle(c, r, Color("f4f0e6"))
		var band := PackedVector2Array()
		var a := asin(0.58)
		for k in 9:
			var t := lerpf(-a, a, k / 8.0)
			band.append(c + Vector2(cos(t), sin(t)) * r)
		for k in 9:
			var t := lerpf(PI - a, PI + a, k / 8.0)
			band.append(c + Vector2(cos(t), sin(t)) * r)
		draw_colored_polygon(band, BALL_COLORS[i - 8])
		draw_circle(c, r * 0.36, Color(1, 1, 1, 0.9))
	draw_circle(c + Vector2(-0.38 * r, -0.4 * r), 0.24 * r, Color(1, 1, 1, 0.35))

func _draw_guide(sim: PoolSim, dir: Vector2, full: bool) -> void:
	var g := ray_guide(sim, dir)
	var cue: Vector2 = sim.pos[0]
	var line_col := Color(1, 1, 1, 0.75 if full else 0.35)
	draw_dashed_line(to_screen(cue), to_screen(g.point), line_col, 2.0, 8.0)
	draw_arc(to_screen(g.point), PoolSim.R * _scale, 0, TAU, 20, line_col, 2.0)
	if g.ball >= 0 and full:
		var bp: Vector2 = sim.pos[g.ball]
		var n: Vector2 = (bp - g.point).normalized()
		draw_line(to_screen(bp), to_screen(bp + n * 120.0), Color(1, 1, 1, 0.55), 2.0)
		var tangent := dir - n * dir.dot(n)
		if tangent.length() > 0.05:
			draw_line(to_screen(g.point), to_screen(g.point + tangent.normalized() * 70.0), Color(1, 1, 1, 0.3), 2.0)

func _draw_cue(sim: PoolSim, dir: Vector2, pull: float) -> void:
	var cue: Vector2 = sim.pos[0]
	var back := -dir
	var tip := cue + back * (PoolSim.R + 6.0 + pull * 110.0)
	var butt := tip + back * 360.0
	var side := dir.orthogonal()
	var poly := PackedVector2Array([
		to_screen(tip + side * 2.5), to_screen(tip - side * 2.5),
		to_screen(butt - side * 6.0), to_screen(butt + side * 6.0)])
	draw_colored_polygon(poly, Color("d8c3a0"))
	var wrap_a := tip + back * 250.0
	draw_colored_polygon(PackedVector2Array([to_screen(wrap_a + side * 5.0), to_screen(wrap_a - side * 5.0),
		to_screen(butt - side * 6.0), to_screen(butt + side * 6.0)]), Color("2a2026"))
	draw_line(to_screen(tip + side * 2.5), to_screen(tip - side * 2.5), Color("43c6b8"), 3.0)
