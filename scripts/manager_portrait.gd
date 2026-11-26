extends Control
## Manager portrait. Art: res://art/managers/<building_id>.png (square). Else: initials placeholder.

var _tex: Texture2D
var _initials := ""

func setup(building_id: String, manager_name: String) -> void:
	var p := "res://art/managers/%s.png" % building_id
	_tex = load(p) if ResourceLoader.exists(p) else null
	var parts := manager_name.replace("(", "").replace(")", "").split(" ", false)
	_initials = ""
	for w in parts:
		if _initials.length() < 2 and w[0] == w[0].to_upper() and w[0] != w[0].to_lower():
			_initials += w[0]
	queue_redraw()

func _draw() -> void:
	var card: StyleBoxFlat = get_theme_stylebox("panel", "CardHi")
	draw_style_box(card, Rect2(Vector2.ZERO, size))
	if _tex:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
		return
	var accent := get_theme_color("font_color", "AccentLabel")
	draw_circle(size / 2.0, size.x * 0.36, Color(accent, 0.25))
	var font := get_theme_default_font()
	var fs := 40
	var tw := font.get_string_size(_initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2((size.x - tw) / 2.0, size.y / 2.0 + fs * 0.35), _initials,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, accent)
