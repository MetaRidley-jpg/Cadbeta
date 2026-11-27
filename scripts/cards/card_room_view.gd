extends Control
## The card room in 3D (Poker Night at the Inventory style): a first-person camera
## from your seat, with camera moves to whoever acts or talks.
## Everything is sprite stacking, but in PERSPECTIVE: every slice of a stack is a
## flat textured quad at its own height, projected through the camera. Between two
## slices, extra copies fill the gap so a stack never shows see-through layers.
## Characters are billboards (flat images facing the camera). Cards are textured quads
## lying on the felt. World units: meters. Table center = origin, +z toward you.

const TOP_Y := 0.76                  # felt height
const PX := 0.022                    # table strip: meters per pixel
const CHAIR_PX := 0.03
const CARD := Vector2(0.105, 0.147)  # big cards (1.6x real) so they read on a phone
const FELT_INSET := 5                # felt starts 5 strip px inside the table top
const CHAR_DIR := "res://art/table/chars/"
const FELT_PATH := "res://art/table/felt.png"

# Camera shots. pos, target, fov (deg). seatN = look at the manager in seat N.
const SHOTS := {
	"seat":   [Vector3(0.0, 1.5, 1.95), Vector3(0.0, 0.9, -0.1), 68.0],
	"hand":   [Vector3(0.0, 1.32, 1.3), Vector3(0.0, 0.74, 0.22), 54.0],
	"dealer": [Vector3(0.0, 1.22, 0.75), Vector3(0.0, 1.02, -0.95), 50.0],
	"seat0":  [Vector3(0.3, 1.25, 1.05), Vector3(-0.98, 0.98, 0.12), 50.0],
	"seat1":  [Vector3(-0.3, 1.25, 1.05), Vector3(0.98, 0.98, 0.12), 50.0],
	"result": [Vector3(0.0, 1.65, 2.05), Vector3(0.0, 0.86, -0.15), 68.0],
}
const SEAT_X := 0.98
const SEAT_Z := 0.12                  # managers sit a little toward you, like at a round of poker
const DEALER_POS := Vector3(0.0, 0.0, -0.98)

var page                              # the blackjack page (state + hands)
var atlas: CardAtlas
var shot := "seat"
var _shot_t := 0.0                    # > 0: temporary shot, then back to _base_shot
var _base_shot := "seat"
var cam_pos := Vector3(0, 1.5, 1.75)
var cam_tgt := Vector3(0, 0.74, -0.12)
var fov := 62.0
var _r := Vector3.RIGHT
var _u := Vector3.UP
var _f := Vector3.FORWARD
var _focal := 500.0
var _t := 0.0
var _tex := {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	atlas = CardAtlas.new()
	add_child(atlas)

## Camera control from the table logic. secs > 0: hold that shot, then go back.
func focus(name: String, secs := 0.0) -> void:
	if not SHOTS.has(name):
		return
	if secs > 0.0:
		shot = name
		_shot_t = secs
	else:
		_base_shot = name
		if _shot_t <= 0.0:
			shot = name

func snap() -> void:
	var s: Array = SHOTS[shot]
	cam_pos = s[0]
	cam_tgt = s[1]
	fov = s[2]

func _process(delta: float) -> void:
	_t += delta
	if _shot_t > 0.0:
		_shot_t -= delta
		if _shot_t <= 0.0:
			shot = _base_shot
	var s: Array = SHOTS[shot]
	var k := 1.0 - exp(-delta * 3.2)
	var sway := Vector3(sin(_t * 0.55) * 0.025, sin(_t * 0.8) * 0.012, 0.0)    # breathing camera
	cam_pos = cam_pos.lerp(s[0] + sway, k)
	cam_tgt = cam_tgt.lerp(s[1], k)
	fov = lerpf(fov, s[2], k)
	if is_visible_in_tree():
		queue_redraw()

# =====================================================================
# Projection
# =====================================================================
func _setup_cam() -> void:
	_f = (cam_tgt - cam_pos).normalized()
	_r = _f.cross(Vector3.UP).normalized()
	_u = _r.cross(_f)
	_focal = (size.y * 0.5) / tan(deg_to_rad(fov) * 0.5)

## Returns (screen x, screen y, depth). depth <= 0: behind the camera.
func project(p: Vector3) -> Vector3:
	var v := p - cam_pos
	var z := v.dot(_f)
	if z <= 0.01:
		return Vector3(0, 0, -1)
	return Vector3(size.x * 0.5 + v.dot(_r) * _focal / z, size.y * 0.5 - v.dot(_u) * _focal / z, z)

func _p2(p: Vector3) -> Vector2:
	var q := project(p)
	return Vector2(q.x, q.y)

## A flat textured rectangle on a horizontal plane, split into an n x n grid so the
## texture follows the perspective. c = center, ax/az = half-axes (world), uv = region.
## Sent as ONE triangle batch (was one draw call per grid cell).
func _quad(tex: Texture2D, c: Vector3, ax: Vector3, az: Vector3, uv: Rect2, mod := Color.WHITE, n := 4) -> void:
	if tex == null:
		return
	var g := n + 1
	var pts := PackedVector2Array()
	pts.resize(g * g)
	var uvs := PackedVector2Array()
	uvs.resize(g * g)
	for j in g:
		for i in g:
			var q := Vector2(float(i) / n, float(j) / n)
			var pr := project(c + ax * (q.x * 2.0 - 1.0) + az * (q.y * 2.0 - 1.0))
			if pr.z <= 0.0:
				return                     # a corner behind the camera: skip (as before)
			pts[j * g + i] = Vector2(pr.x, pr.y)
			uvs[j * g + i] = uv.position + uv.size * q
	var idx := PackedInt32Array()
	for j in n:
		for i in n:
			var v := j * g + i
			idx.append_array([v, v + 1, v + g + 1, v, v + g + 1, v + g])
	var cols := PackedColorArray()
	cols.resize(g * g)
	cols.fill(mod)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), tex.get_rid())

## Most copies used to fill the gap between two slices. 1 copy per STACK_STEP px of rise.
const STACK_STEP := 1.0
const STACK_MAX_COPIES := 40

## A sprite stack in perspective. heights[k] = world height of slice k.
## dir = the way the art's "front" (image down) faces in the world.
## Perf (2026-11-26, iPhone crash): the whole stack is ONE triangle batch. Each slice's
## grid is projected twice (its own height and the next slice's), and the gap-filling
## copies are placed by 2D interpolation between the two (a vertical world line stays a
## straight screen line, so the copies still land on it). Before: up to 40 copies x 36
## cells = one draw call per cell, ~13,000 draw calls per frame for the table.
func _stack(name: String, base: Vector3, dir: Vector3, px: float, heights: Array, mod := Color.WHITE, grid := 3) -> void:
	var st := StackDraw.strip(name)
	if st.is_empty():
		return
	var n: int = st.n
	var tex: Texture2D = st.tex
	var tw: float = st.w * n
	var w: float = st.w
	var h: float = st.h
	var right := Vector3(dir.z, 0, -dir.x)
	var ax := right * w * px * 0.5
	var az := dir * h * px * 0.5
	var g := grid + 1
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var p0 := PackedVector2Array()
	var p1 := PackedVector2Array()
	p0.resize(g * g)
	p1.resize(g * g)
	var cell_idx := PackedInt32Array()
	for j in grid:
		for i in grid:
			var v := j * g + i
			cell_idx.append_array([v, v + 1, v + g + 1, v, v + g + 1, v + g])
	for k in n:
		var uv := Rect2(k * w / tw, 0.0, w / tw, 1.0)
		var y0: float = heights[k]
		var y1: float = heights[k + 1] if k + 1 < n else y0
		var ok := true
		for j in g:
			for i in g:
				var off := ax * (float(i) / grid * 2.0 - 1.0) + az * (float(j) / grid * 2.0 - 1.0)
				var a := project(base + off + Vector3(0, y0, 0))
				var b := project(base + off + Vector3(0, y1, 0))
				if a.z <= 0.0 or b.z <= 0.0:
					ok = false
					break
				p0[j * g + i] = Vector2(a.x, a.y)
				p1[j * g + i] = Vector2(b.x, b.y)
			if not ok:
				break
		if not ok:
			continue
		var rise := 0.0
		for v in g * g:
			rise = maxf(rise, absf(p0[v].y - p1[v].y))
		var copies := clampi(int(ceil(rise / STACK_STEP)), 1, STACK_MAX_COPIES)
		var slice_uv := PackedVector2Array()
		slice_uv.resize(g * g)
		for j in g:
			for i in g:
				slice_uv[j * g + i] = uv.position + uv.size * Vector2(float(i) / grid, float(j) / grid)
		for c in copies:
			var t := float(c) / copies
			var first := pts.size()
			for v in g * g:
				pts.append(p0[v].lerp(p1[v], t))
			uvs.append_array(slice_uv)
			for e in cell_idx:
				idx.append(first + e)
	if pts.is_empty():
		return
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(mod)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), tex.get_rid())

## A flat image standing up and facing the camera, bottom-centered on p.
func _billboard(tex: Texture2D, p: Vector3, height: float, mod := Color.WHITE) -> Rect2:
	if tex == null:
		return Rect2()
	var b := project(p)
	var t := project(p + Vector3(0, height, 0))
	if b.z <= 0.0 or t.z <= 0.0:
		return Rect2()
	var hpx := b.y - t.y
	var wpx := hpx * tex.get_width() / tex.get_height()
	var r := Rect2(Vector2(b.x - wpx * 0.5, t.y), Vector2(wpx, hpx))
	draw_texture_rect(tex, r, false, mod)
	return r

func _texture(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = null
	var raw := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(raw):
		var img := Image.load_from_file(raw)
		if img:
			t = ImageTexture.create_from_image(img)
	if t == null and ResourceLoader.exists(path):
		t = load(path)
	_tex[path] = t
	return t

# =====================================================================
# Card placement (world), used by the page for dealing and labels
# =====================================================================
func hand_spot(who: String) -> Vector3:
	match who:
		"p": return Vector3(0.0, TOP_Y, 0.4)
		"d": return Vector3(0.0, TOP_Y, -0.36)
		"s0": return Vector3(-0.52, TOP_Y, 0.02)
		"s1": return Vector3(0.52, TOP_Y, 0.02)
		"b": return Vector3(0.0, TOP_Y, -0.04)
		"p0": return Vector3(-0.25, TOP_Y, 0.4)     # split hands
		"p1": return Vector3(0.25, TOP_Y, 0.4)
	return Vector3(0, TOP_Y, 0)

func shoe_spot() -> Vector3:
	return Vector3(0.5, TOP_Y, -0.42)

func card_spot(who: String, i: int, n: int) -> Vector3:
	var base := hand_spot(who)
	var gap := CARD.x * (0.7 if who in ["p", "d"] else (1.08 if who == "b" else (0.42 if who in ["p0", "p1"] else 0.45)))
	var side := Vector3(1, 0, 0) if who in ["p", "d", "b", "p0", "p1"] else Vector3(0, 0, 1)
	return base + side * (i - (n - 1) * 0.5) * gap + Vector3(0, 0.0015 * i, 0)

# =====================================================================
# Draw
# =====================================================================
var draw_ms := 0.0           # last frame's room draw cost (debug / tests)

func _draw() -> void:
	if page == null:
		return
	var _t0 := Time.get_ticks_usec()
	_draw_room()
	draw_ms = (Time.get_ticks_usec() - _t0) / 1000.0

func _draw_room() -> void:
	_setup_cam()
	var tc := Challenges.table_colors()
	# room: warm lamp glow behind the table, dark floor
	draw_rect(Rect2(Vector2.ZERO, size), Color("120c18"))
	var lamp := _p2(Vector3(0, 2.2, -0.4))
	for k in 6:
		draw_circle(lamp, size.x * (0.9 - k * 0.13), Color(1.0, 0.75, 0.4, 0.035))
	var floor_c := _p2(Vector3(0, 0, 0))
	draw_circle(floor_c, size.x * 0.35, Color(0, 0, 0, 0.35))
	# 1. Cadavire behind the table
	_billboard(_texture(CHAR_DIR + "cadavire_dealer.png"), DEALER_POS + Vector3(0, 0.42, 0), 1.02)
	# 2. side seats: chair + manager (the near-side one last)
	var order := [0, 1]
	for si in order:
		var sx := -SEAT_X if si == 0 else SEAT_X
		var face := Vector3(1, 0, 0) if si == 0 else Vector3(-1, 0, 0)
		var chair_h: Array = []
		for k in 18:
			chair_h.append(k * 0.052)
		_stack("chair", Vector3(sx - face.x * 0.04, 0, SEAT_Z - 0.02), face, CHAIR_PX, chair_h, Color.WHITE, 2)
		if si < page.seats.size() and int(page.seats[si]) >= 0:
			var id: String = Balance.BUILDINGS[page.seats[si]].id
			_billboard(_texture(CHAR_DIR + id + ".png"), Vector3(sx, 0.5, SEAT_Z), 0.86)
	# 3. the table: pedestal + slab as a perspective sprite stack, felt on top
	var hts: Array = [0.0]
	for k in range(1, 7):
		hts.append(0.03 + (k - 1) * 0.125)     # pedestal slices up to ~0.66
	hts.append_array([0.70, 0.73, TOP_Y - 0.004])
	var rim_mod := Color.WHITE if Challenges.table == "" else Color(tc.rim).lightened(0.45)
	_stack("card_table", Vector3.ZERO, Vector3(0, 0, 1), PX, hts, rim_mod, 6)
	var felt := _texture(String(page.get("felt_path")) if page.get("felt_path") != null else FELT_PATH)
	var st := StackDraw.strip("card_table")
	if felt and not st.is_empty():
		var fc := Color(tc.felt).lightened(0.12)
		if Game.fever_active:
			fc = fc.lerp(Color("c0307a"), 0.45)
		var fw: float = (float(st.w) - FELT_INSET * 2) * PX * 0.5
		var fh: float = (float(st.h) - FELT_INSET * 2) * PX * 0.5
		_quad(felt, Vector3(0, TOP_Y, 0), Vector3(fw, 0, 0), Vector3(0, 0, fh), Rect2(0, 0, 1, 1), fc, 8)
	# 4. on the felt + 5. labels: each game draws its own (blackjack_page / holdem_page)
	page.draw_felt(self)
	page.draw_labels(self)

func _card_quad(tex: Texture2D, card: Dictionary, c: Vector3, yaw: float) -> void:
	var ax := Vector3(cos(yaw), 0, -sin(yaw)) * CARD.x * 0.5
	var az := Vector3(sin(yaw), 0, cos(yaw)) * CARD.y * 0.5
	# 1 mm dark edge under the card so it separates from the felt
	_quad(tex, c + Vector3(0.002, -0.001, 0.003), ax, az, atlas.uv({}), Color(0, 0, 0, 0.35), 1)
	_quad(tex, c, ax, az, atlas.uv(card), Color.WHITE, 2)

func _chips(c: Vector3, n: int) -> void:
	var cols := [Color("ff1f4b"), Color("efe6d2"), Color("43c6b8")]
	for k in mini(n, 14):
		var p := project(c + Vector3(0, k * 0.008, 0))
		if p.z <= 0.0:
			continue
		var r := 0.03 * _focal / p.z
		draw_set_transform(Vector2(p.x, p.y), 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, r + 2.0, Color("1a0f2e"))
		draw_circle(Vector2.ZERO, r, cols[k % 3])
		draw_arc(Vector2.ZERO, r * 0.65, 0.0, TAU, 16, Color(1, 1, 1, 0.6), 2.0)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	_text("%d" % n, _p2(c + Vector3(0, 0, 0.06)) + Vector2(0, 14), 16, Color.WHITE)

func _text(t: String, p: Vector2, sz: int, col: Color, shadow := true) -> void:
	var f := get_theme_default_font()
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var at := Vector2(clampf(p.x - w * 0.5, 8.0, size.x - w - 8.0), p.y + sz * 0.35)   # keep names on screen
	if shadow:
		draw_string(f, at + Vector2(2, 2), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.7))
	draw_string(f, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

## Shared helper for the games: a card flying from `from` to `to` (t = 0..1, eased, small arc).
func fly(from: Vector3, to: Vector3, t: float) -> Vector3:
	var k := 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)
	return from.lerp(to, k) + Vector3(0, sin(k * PI) * 0.06, 0)

## Big result banner across the lower part of the view.
func banner(text: String) -> void:
	var f := get_theme_default_font()
	var big := 40
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var rp := Vector2(size.x * 0.5 - w * 0.5, size.y * 0.74)
	draw_rect(Rect2(rp + Vector2(-18, -big), Vector2(w + 36, big + 18)), Color(0, 0, 0, 0.6))
	draw_string(f, rp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color("ffe14a"))

## Seat head position on screen (names, "!" marks). si 0 = left, 1 = right.
func seat_head(si: int) -> Vector2:
	return _p2(Vector3(-SEAT_X if si == 0 else SEAT_X, 1.42, SEAT_Z))
