class_name PlayIcon
extends Button
## One "app icon" on the Play home screen (T: "condense play into an app icon screen").
## A flat Button (so tests and touch work like any button) that draws its own
## rounded tile, a game glyph, a label under the tile and an optional badge.
## Glyphs are drawn in code so the icons follow the game palette with no extra art.

const TILE := 150.0          # tile side in px (canvas 720 wide, 3 columns)
const LABEL_H := 38.0
const RADIUS := 26.0
const BANDS := 5          # chunky vertical gradient (30 px bands)

var kind := "pool"           # pool | dogfight | blackjack | holdem | pinball | options
var title := ""
var badge := ""              # small pill at the top right ("W6", "SOON")
var locked_text := ""        # non-empty = dim tile + lock + this text under the title

const COLORS := {
	"pool":      [Color("1f7a52"), Color("0f4a33")],
	"dogfight":  [Color("f08a3c"), Color("2b6f9e")],
	"blackjack": [Color("b3263a"), Color("5c0f1d")],
	"holdem":    [Color("2c8f86"), Color("173f4f")],
	"pinball":   [Color("7a4bc2"), Color("33215e")],
	"options":   [Color("6a6272"), Color("2f2a36")],
}

func setup(k: String, t: String) -> PlayIcon:
	kind = k
	title = t
	flat = true
	focus_mode = Control.FOCUS_NONE
	text = ""
	custom_minimum_size = Vector2(TILE + 20, TILE + LABEL_H + 26)
	button_down.connect(func(): _squash(0.9))
	button_up.connect(func(): _squash(1.0))
	resized.connect(func(): pivot_offset = Vector2(size.x * 0.5, 10 + TILE * 0.5))
	return self

func _squash(to: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(to, to), 0.08)

func set_state(b: String, locked: String) -> void:
	if b == badge and locked == locked_text:
		return
	badge = b
	locked_text = locked
	queue_redraw()

func tile_rect() -> Rect2:
	return Rect2(Vector2((size.x - TILE) * 0.5, 10), Vector2(TILE, TILE))

func _draw() -> void:
	var r := tile_rect()
	var dim := disabled or locked_text != ""
	var cols: Array = COLORS.get(kind, COLORS.options)
	# drop shadow + body: a chunky 5-band vertical gradient
	_rrect(Rect2(r.position + Vector2(0, 6), r.size), Color(0, 0, 0, 0.45))
	var bh := r.size.y / BANDS
	for i in BANDS:
		var col: Color = (cols[0] as Color).lerp(cols[1], float(i) / (BANDS - 1))
		var band := Rect2(r.position.x, r.position.y + bh * i, r.size.x, bh + (0.0 if i == BANDS - 1 else 1.0))
		_rrect(band, col, RADIUS, i == 0, i == BANDS - 1)
	draw_rect(Rect2(r.position + Vector2(RADIUS, 4), Vector2(r.size.x - RADIUS * 2, 3)), Color(1, 1, 1, 0.22))
	# glyph
	var c := r.get_center()
	var s := TILE
	match kind:
		"pool": _glyph_pool(c, s)
		"dogfight": _glyph_jet(c, s)
		"blackjack": _glyph_cards(c, s)
		"holdem": _glyph_chips(c, s)
		"pinball": _glyph_pinball(c, s)
		_: _glyph_gear(c, s)
	if dim:
		_rrect(r, Color(0, 0, 0, 0.55))
		if locked_text != "":
			_glyph_lock(c, s * 0.42)
	# badge
	if badge != "":
		var f := get_theme_font("font", "Label")
		var fs := 20
		var w := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 22
		var br := Rect2(Vector2(r.end.x - w + 10, r.position.y - 8), Vector2(w, 32))
		_rrect(br, Color("f26a1b") if kind != "pinball" else Color("4a4352"), 16.0)
		draw_string(f, br.position + Vector2(11, 23), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("1a1410") if kind != "pinball" else Color("efe6d2"))
	# label (+ lock text)
	var lf := get_theme_font("font", "Label")
	var col := get_theme_color("font_color", "Label")
	if dim:
		col = Color(col, 0.55)
	draw_string(lf, Vector2(0, r.end.y + 32), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, col)
	if locked_text != "":
		draw_string(lf, Vector2(0, r.end.y + 54), locked_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, Color(col, 0.9))

## Rounded rectangle. With `top` / `bottom` given, only those corners are rounded.
func _rrect(r: Rect2, col: Color, rad := RADIUS, top := true, bottom := true) -> void:
	if col.a <= 0.0:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.corner_radius_top_left = int(rad) if top else 0
	sb.corner_radius_top_right = int(rad) if top else 0
	sb.corner_radius_bottom_left = int(rad) if bottom else 0
	sb.corner_radius_bottom_right = int(rad) if bottom else 0
	sb.corner_detail = 5
	sb.anti_aliasing = false
	draw_style_box(sb, r)

# ---------------------------------------------------------------- glyphs
func _glyph_pool(c: Vector2, s: float) -> void:
	# cue stick
	draw_line(c + Vector2(-s * 0.44, s * 0.38), c + Vector2(-s * 0.12, s * 0.10), Color("e9c88a"), 7)
	draw_line(c + Vector2(-s * 0.14, s * 0.12), c + Vector2(-s * 0.08, s * 0.07), Color("efe6d2"), 7)
	# 8-ball
	draw_circle(c + Vector2(s * 0.06, -s * 0.02), s * 0.27, Color("120f14"), true, -1, false)
	draw_circle(c + Vector2(s * 0.02, -s * 0.07), s * 0.12, Color("efe6d2"), true, -1, false)
	var f := get_theme_font("font", "Label")
	draw_string(f, c + Vector2(s * 0.02 - 8, -s * 0.07 + 10), "8", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("120f14"))
	draw_circle(c + Vector2(s * 0.16, -s * 0.16), s * 0.04, Color(1, 1, 1, 0.5), true, -1, false)

func _glyph_jet(c: Vector2, s: float) -> void:
	# sun + horizon
	draw_circle(c + Vector2(s * 0.22, -s * 0.22), s * 0.12, Color("ffd23f"), true, -1, false)
	draw_rect(Rect2(c.x - s * 0.5 + 6, c.y + s * 0.2, s - 12, s * 0.06), Color(1, 1, 1, 0.18))
	# T's jet from above: grey helmet nose, one red cyclops band, swept wings, burner
	var k := s * 0.36
	var body := PackedVector2Array([
		c + Vector2(0, -k), c + Vector2(k * 0.16, -k * 0.35), c + Vector2(k * 0.9, k * 0.35),
		c + Vector2(k * 0.9, k * 0.5), c + Vector2(k * 0.18, k * 0.38), c + Vector2(k * 0.34, k * 0.78),
		c + Vector2(-k * 0.34, k * 0.78), c + Vector2(-k * 0.18, k * 0.38), c + Vector2(-k * 0.9, k * 0.5),
		c + Vector2(-k * 0.9, k * 0.35), c + Vector2(-k * 0.16, -k * 0.35)])
	draw_colored_polygon(body, Color("2a2440"))
	draw_polyline(body + PackedVector2Array([body[0]]), Color("120f14"), 3)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k), c + Vector2(k * 0.16, -k * 0.35), c + Vector2(-k * 0.16, -k * 0.35)]), Color("b9b4c2"))
	draw_rect(Rect2(c + Vector2(-k * 0.15, -k * 0.38), Vector2(k * 0.3, k * 0.1)), Color("ff2a3a"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.2, k * 0.8), c + Vector2(k * 0.2, k * 0.8), c + Vector2(0, k * 1.15)]), Color("ff9a2e"))

func _card_at(c: Vector2, ang: float, rank: String, suit_col: Color, s: float) -> void:
	draw_set_transform(c, ang, Vector2.ONE)
	var w := s * 0.38
	var h := s * 0.54
	var r := Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f4ecda")
	sb.set_corner_radius_all(8)
	sb.border_color = Color("120f14")
	sb.set_border_width_all(3)
	sb.anti_aliasing = false
	draw_style_box(sb, r)
	var f := get_theme_font("font", "Label")
	draw_string(f, r.position + Vector2(8, 30), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, suit_col)
	draw_circle(Vector2(0, h * 0.12), w * 0.17, suit_col, true, -1, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _glyph_cards(c: Vector2, s: float) -> void:
	_card_at(c + Vector2(-s * 0.12, s * 0.02), -0.22, "K", Color("120f14"), s)
	_card_at(c + Vector2(s * 0.12, -s * 0.02), 0.18, "A", Color("c4182c"), s)

func _glyph_chips(c: Vector2, s: float) -> void:
	var cols := [Color("efe6d2"), Color("f26a1b"), Color("43c6b8"), Color("efe6d2"), Color("c4182c")]
	for i in cols.size():
		var y := c.y + s * 0.24 - i * s * 0.085
		var x := c.x - s * 0.06
		_ellipse(Vector2(x, y + 5), s * 0.24, s * 0.09, Color("120f14"))
		_ellipse(Vector2(x, y), s * 0.24, s * 0.09, cols[i])
	_card_at(c + Vector2(s * 0.24, -s * 0.12), 0.3, "Q", Color("c4182c"), s * 0.8)

func _glyph_pinball(c: Vector2, s: float) -> void:
	draw_line(c + Vector2(-s * 0.36, s * 0.22), c + Vector2(-s * 0.06, s * 0.34), Color("ffd23f"), 12)
	draw_line(c + Vector2(s * 0.36, s * 0.22), c + Vector2(s * 0.06, s * 0.34), Color("ffd23f"), 12)
	draw_circle(c + Vector2(0, -s * 0.12), s * 0.13, Color("d9d4e0"), true, -1, false)
	draw_circle(c + Vector2(-s * 0.04, -s * 0.16), s * 0.04, Color(1, 1, 1, 0.8), true, -1, false)
	for p in [Vector2(-0.28, -0.3), Vector2(0.28, -0.3)]:
		draw_circle(c + p * s, s * 0.07, Color("ff3d8b"), true, -1, false)

func _glyph_gear(c: Vector2, s: float) -> void:
	var col := Color("d9d4e0")
	for i in 8:
		var a := TAU * i / 8.0
		draw_set_transform(c, a, Vector2.ONE)
		draw_rect(Rect2(Vector2(-s * 0.07, -s * 0.36), Vector2(s * 0.14, s * 0.16)), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(c, s * 0.25, col, true, -1, false)
	draw_circle(c, s * 0.1, COLORS.options[1], true, -1, false)

func _glyph_lock(c: Vector2, s: float) -> void:
	draw_arc(c + Vector2(0, -s * 0.15), s * 0.28, PI, TAU, 12, Color("efe6d2"), 8)
	draw_rect(Rect2(c + Vector2(-s * 0.42, -s * 0.15), Vector2(s * 0.84, s * 0.62)), Color("efe6d2"))
	draw_circle(c + Vector2(0, s * 0.12), s * 0.09, Color("2f2a36"), true, -1, false)

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
