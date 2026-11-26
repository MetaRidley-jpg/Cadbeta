extends Control
## Cadavire portrait slot.
## Art lookup (first file found wins):
##   res://art/cadavire/<costume>/<expression>_fever.png   (only in Fever)
##   res://art/cadavire/<costume>/<expression>.png
##   res://art/cadavire/<costume>/neutral(.png|_fever.png)
##   ...then the same for grave_casual, then a drawn placeholder.
## Expressions: neutral shy smug excited flustered hungry disgusted feral

var expression := "neutral"
var override_costume := ""   # e.g. "pilot" during the dogfight (art: art/cadavire/pilot/...)
var _tex: Texture2D
var _t := 0.0
var _bounce := 0.0
var _shake := 0.0

const TINT_SHADER := preload("res://shaders/tint_overlay.gdshader")
const TINT_AMOUNT := 0.7

func _ready() -> void:
	var m := ShaderMaterial.new()
	m.shader = TINT_SHADER
	material = m
	Challenges.cosmetic_changed.connect(_apply_tint)
	_apply_tint()
	Game.costume_changed.connect(_reload)
	Game.fever_mode_changed.connect(func(_a): _reload())
	_reload()

## Challenges tint prize: overlay color on top of the outfit (no tint = amount 0).
func _apply_tint() -> void:
	var c := Challenges.tint_color()
	(material as ShaderMaterial).set_shader_parameter("tint", Color(c, 1.0))
	(material as ShaderMaterial).set_shader_parameter("amount", TINT_AMOUNT if c.a > 0.0 else 0.0)
	queue_redraw()

func set_expression(e: String) -> void:
	expression = e
	_bounce = 1.0
	_reload()

func set_override(c: String) -> void:
	override_costume = c
	_reload()

func shake() -> void:
	_shake = 0.6

func _reload() -> void:
	_tex = find_art(override_costume if override_costume != "" else Game.costume, expression, Game.fever_active)
	queue_redraw()

static func find_art(costume: String, expr: String, fever: bool) -> Texture2D:
	var base := "res://art/cadavire/"
	var tries: Array = []
	for c in [costume, "grave_casual"]:
		for e in [expr, "neutral"]:
			if fever:
				tries.append("%s%s/%s_fever.png" % [base, c, e])
			tries.append("%s%s/%s.png" % [base, c, e])
	for p in tries:
		if ResourceLoader.exists(p):
			return load(p)
	return null

func _process(delta: float) -> void:
	_t += delta
	_bounce = move_toward(_bounce, 0.0, delta * 3.0)
	_shake = move_toward(_shake, 0.0, delta)
	queue_redraw()

func _draw() -> void:
	var accent := get_theme_color("font_color", "NamePlate")
	var muted := get_theme_color("font_color", "MutedLabel")
	var text_col := get_theme_color("font_color", "Label")
	var card: StyleBoxFlat = get_theme_stylebox("panel", "Card")
	var hi: StyleBoxFlat = get_theme_stylebox("panel", "CardHi")
	var bob := sin(_t * 2.0) * 4.0 - sin(_bounce * PI) * 14.0
	var sx := sin(_t * 70.0) * _shake * 10.0
	var off := Vector2(sx, bob)

	# frame
	var frame := Rect2(Vector2.ZERO, size)
	draw_style_box(card, frame)
	if Game.fever_active:
		var glow := Color(accent, 0.35 + 0.25 * sin(_t * 6.0))
		draw_rect(frame.grow(-3), glow, false, 6.0)

	if _tex:
		var ts := _tex.get_size()
		var s := minf(size.x / ts.x, size.y / ts.y)
		var dst := Rect2((size - ts * s) / 2.0 + off, ts * s)
		draw_texture_rect(_tex, dst, false)
		return

	# ---- placeholder silhouette (replace with real art) ----
	var w := size.x
	var h := size.y
	var body_col: Color = hi.bg_color.lightened(0.06)
	var cx := w * 0.5 + off.x
	var head_c := Vector2(cx, h * 0.36 + off.y)
	var head_r := w * 0.24
	var shoulders := PackedVector2Array([
		Vector2(cx - w * 0.36, h), Vector2(cx - w * 0.22, h * 0.62 + off.y),
		Vector2(cx + w * 0.22, h * 0.62 + off.y), Vector2(cx + w * 0.36, h)])
	draw_colored_polygon(shoulders, body_col)
	draw_circle(head_c, head_r, body_col)
	# stitch across the cheek: she's a zombie
	var st := head_c + Vector2(head_r * 0.35, head_r * 0.35)
	draw_line(st + Vector2(-14, 0), st + Vector2(14, 0), accent, 3.0)
	for k in 3:
		var x := -10 + k * 10
		draw_line(st + Vector2(x, -6), st + Vector2(x, 6), accent, 2.0)
	# eyes change with expression
	var eye_y := head_c.y - head_r * 0.05
	var eye_dx := head_r * 0.38
	var look := Vector2(0, 5) if expression in ["shy", "flustered"] else Vector2.ZERO
	var eye_r := 9.0 if expression in ["excited", "feral", "hungry"] else 6.5
	for sgn in [-1, 1]:
		var ep := Vector2(head_c.x + eye_dx * sgn, eye_y) + look
		if expression == "disgusted":
			draw_line(ep + Vector2(-8, 0), ep + Vector2(8, 0), text_col, 4.0)
		else:
			draw_circle(ep, eye_r, text_col)
	if expression in ["shy", "flustered"]:
		for sgn in [-1, 1]:
			draw_circle(Vector2(head_c.x + eye_dx * 1.25 * sgn, eye_y + 22), 10.0, Color(accent, 0.45))

	var font := get_theme_default_font()
	var cname: String = "Ace Pilot" if override_costume == "pilot" else Balance.costume(Game.costume).name
	var label := "%s / %s%s" % [cname, expression, "  FEVER" if Game.fever_active else ""]
	draw_string(font, Vector2(12, h - 14), label, HORIZONTAL_ALIGNMENT_LEFT, w - 24, 15, muted)
	draw_string(font, Vector2(12, 26), "ART SLOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, muted)
