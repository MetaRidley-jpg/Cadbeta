class_name DfPilotPortrait
extends Control
## T's mute pilot (2026-11-28): "Pilot doom like reactions and he puts his glove on his ear when
## radio is coming in. Mute player." Sits in the old portrait slot beside the RADIO box.
## States (DfGame.pilot_state): idle, look_l, look_r, grin, ear, shock, ko; hurt 0..3 (hull).
## ART SLOTS: drop T's frames in art/pilot/ as  pilot_<state>_<hurt>.png  (or pilot_<state>.png
## for all hurt levels). Any size; drawn with hard pixels, fitted to the slot. Missing = the
## code placeholder below (48 x 56 px).
const DIR := "res://art/pilot/"
const W := 48
const H := 56
var game: Node                     # DfGame
var _tex := {}                     # key -> Texture2D (T's PNG or a placeholder)
var _key := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_d: float) -> void:
	var st := {"state": "idle", "hurt": 0}
	if game != null and game.has_method("pilot_state"):
		st = game.pilot_state()
	var k := "%s_%d" % [st.state, st.hurt]
	if k != _key:
		_key = k
		queue_redraw()

func _draw() -> void:
	if _key == "":
		return
	var t := _texture(_key)
	var sz := t.get_size()
	var sc := floorf(minf(size.x / sz.x, size.y / sz.y)) if minf(size.x / sz.x, size.y / sz.y) >= 1.0 else minf(size.x / sz.x, size.y / sz.y)
	var d := sz * sc
	draw_texture_rect(t, Rect2(((size - d) * 0.5).round(), d), false)

func _texture(k: String) -> Texture2D:
	if _tex.has(k):
		return _tex[k]
	var parts := k.rsplit("_", true, 1)
	var t: Texture2D = null
	for path in [DIR + "pilot_" + k + ".png", DIR + "pilot_" + parts[0] + ".png"]:
		if ResourceLoader.exists(path):
			t = load(path)
			break
	if t == null:
		t = ImageTexture.create_from_image(placeholder(parts[0], int(parts[1])))
	_tex[k] = t
	return t

# ------------------------------------------------------------------ placeholder pixel pilot
const BG := Color("1d1a26")
const RED := Color("b8302c")
const RED_D := Color("7a1e1e")
const RED_L := Color("d9503f")
const FIN := Color("e8e8ee")
const FIN_D := Color("a8a8b8")
const VISOR := Color("12161c")
const GLOW := Color("6cf2a0")
const SHOULDER := Color("6a2026")
const NAVY := Color("232c52")
const GLOVE := Color("8e8e98")
const INK := Color("0b0a10")

static func placeholder(state: String, hurt: int) -> Image:
	var im := Image.create(W, H, false, Image.FORMAT_RGBA8)
	im.fill(BG)
	var r := func(x0: int, y0: int, w: int, h: int, c: Color) -> void:
		im.fill_rect(Rect2i(x0, y0, w, h), c)
	# shoulders + armour
	r.call(6, 44, 36, 12, SHOULDER); r.call(6, 44, 36, 1, INK); r.call(4, 47, 6, 9, NAVY); r.call(38, 47, 6, 9, NAVY)
	r.call(20, 40, 8, 5, VISOR)                                  # neck
	# helmet: rounded red dome
	for y in range(8, 42):
		var hw := int(round(13.0 * sqrt(maxf(0.0, 1.0 - pow((y - 24.0) / 17.0, 2.0))))) + 1
		r.call(24 - hw, y, hw * 2, 1, RED if y < 30 else RED_D)
	r.call(14, 10, 6, 3, RED_L)                                  # shine
	# white fins (T's helmet horns)
	for k in 10:
		r.call(9 - k / 3, 6 + k, 3, 1, FIN); r.call(36 + k / 3, 6 + k, 3, 1, FIN)
	r.call(7, 15, 3, 3, FIN_D); r.call(38, 15, 3, 3, FIN_D)
	# visor
	r.call(14, 24, 20, 12, VISOR); r.call(14, 24, 20, 1, INK); r.call(15, 35, 18, 1, Color("2a3540"))
	var ex := 0
	if state == "look_l": ex = -3
	elif state == "look_r": ex = 3
	match state:
		"grin":                                                  # happy ^^ eyes
			for e in [18, 27]:
				im.set_pixel(e, 29, GLOW); im.set_pixel(e + 1, 28, GLOW); im.set_pixel(e + 2, 29, GLOW)
		"shock":
			r.call(17, 27, 4, 4, GLOW); r.call(27, 27, 4, 4, GLOW)
		"ko":
			for e in [18, 27]:
				for q in 3:
					im.set_pixel(e + q, 27 + q, GLOW); im.set_pixel(e + 2 - q, 27 + q, GLOW)
		_:
			r.call(17 + ex, 29, 4, 2, GLOW); r.call(27 + ex, 29, 4, 2, GLOW)
	if state == "ear":                                           # glove raised to the left ear
		r.call(4, 22, 9, 12, GLOVE); r.call(4, 22, 9, 1, INK); r.call(2, 30, 4, 14, NAVY)
		r.call(6, 24, 2, 2, GLOW)                                # the earpiece light
		r.call(17, 29, 4, 2, GLOW); r.call(27, 29, 4, 2, GLOW)
	# hurt: cracks on the visor and helmet, scorch marks
	if hurt >= 1:
		for q in 5: im.set_pixel(30 - q, 25 + q, Color("c8d0d8"))
	if hurt >= 2:
		for q in 6: im.set_pixel(16 + q, 33 - q / 2, Color("c8d0d8"))
		r.call(30, 12, 4, 3, INK); r.call(31, 13, 2, 1, RED_D)
	if hurt >= 3:
		r.call(12, 16, 3, 5, INK); r.call(34, 18, 4, 2, Color("ff8a3d"))
		for q in 8: im.set_pixel(22 + q / 2, 25 + q, Color("c8d0d8"))
	return im
