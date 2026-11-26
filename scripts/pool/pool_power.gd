extends Control
## Power strip: press, drag LEFT to pull the cue back, release to shoot.
## Releasing with almost no pull cancels.

signal pulled(power: float)
signal released(power: float)

var enabled := true
var power := 0.0
var shown_power := 0.0   # set by the game (e.g. her pull) when you are not dragging
var _start_x := 0.0
var _dragging := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = 72

func _gui_input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_dragging = true
			_start_x = e.position.x
			power = 0.0
		elif _dragging:
			_dragging = false
			var p := power
			power = 0.0
			released.emit(p)
		accept_event()
	elif e is InputEventMouseMotion and _dragging:
		power = clampf((_start_x - e.position.x) / maxf(120.0, size.x * 0.75), 0.0, 1.0)
		pulled.emit(power)
		accept_event()
	queue_redraw()

func cancel() -> void:
	_dragging = false
	power = 0.0
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg: StyleBoxFlat = get_theme_stylebox("panel", "Card")
	draw_style_box(bg, r)
	var accent := get_theme_color("font_color", "NamePlate")
	var muted := get_theme_color("font_color", "MutedLabel")
	var p := power if _dragging else shown_power
	if p > 0.0:
		var w := (size.x - 12.0) * p
		draw_rect(Rect2(Vector2(size.x - 6.0 - w, 6.0), Vector2(w, size.y - 12.0)), Color(accent, 0.85))
	var font := get_theme_default_font()
	var txt := "PULL LEFT  <<  RELEASE TO SHOOT" if enabled else "CADAVIRE'S TURN"
	if p > 0.0:
		txt = ("POWER %d%%" if enabled else "HER POWER %d%%") % int(p * 100.0)
	var fs := 20
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2((size.x - tw) / 2.0, size.y / 2.0 + 7.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		get_theme_color("font_color", "Label") if enabled else muted)
