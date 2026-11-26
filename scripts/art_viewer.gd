extends Control
## Full-screen art viewer for Challenges art prizes.
## Full resolution. Pinch or mouse wheel = zoom (around the fingers / cursor),
## drag = pan, double tap = fit <-> 2x, X or Esc = close. Credits bar at the bottom.

signal closed

const MAX_ZOOM_OVER_FIT := 6.0

var tex: Texture2D
var title := ""
var credits := ""
var zoom := 1.0
var fit_zoom := 1.0
var offset := Vector2.ZERO        # image top-left on screen
var _touch := {}
var _pinch_d := 0.0
var _last_tap := -10.0
var _tap_start := Vector2.ZERO
var _moved := false
var _bar_top := 96.0
var _bar_bottom := 110.0

func open(path: String, t: String, c: String) -> void:
	title = t
	credits = c
	var img: Image = null
	if ResourceLoader.exists(path):
		img = (load(path) as Texture2D).get_image()
	if img == null:
		img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()            # smooth when zoomed out
	tex = ImageTexture.create_from_image(img)
	show()
	_fit.call_deferred()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(func():
		if visible and tex:
			_fit())
	hide()

func _view() -> Rect2:
	return Rect2(0, _bar_top, size.x, size.y - _bar_top - _bar_bottom)

func _fit() -> void:
	if tex == null:
		return
	var v := _view()
	fit_zoom = minf(v.size.x / tex.get_width(), v.size.y / tex.get_height())
	zoom = fit_zoom
	offset = v.position + (v.size - Vector2(tex.get_size()) * zoom) * 0.5
	queue_redraw()

func _zoom_at(p: Vector2, z: float) -> void:
	z = clampf(z, fit_zoom, fit_zoom * MAX_ZOOM_OVER_FIT)
	var img_p := (p - offset) / zoom
	zoom = z
	offset = p - img_p * zoom
	_clamp()

func _clamp() -> void:
	var v := _view()
	var s := Vector2(tex.get_size()) * zoom
	for ax in 2:
		if s[ax] <= v.size[ax]:
			offset[ax] = v.position[ax] + (v.size[ax] - s[ax]) * 0.5
		else:
			offset[ax] = clampf(offset[ax], v.position[ax] + v.size[ax] - s[ax], v.position[ax])
	queue_redraw()

func close() -> void:
	hide()
	_touch.clear()
	tex = null
	closed.emit()

func _unhandled_key_input(e: InputEvent) -> void:
	if visible and e.is_pressed() and (e as InputEventKey).keycode == KEY_ESCAPE:
		close()

func _gui_input(e: InputEvent) -> void:
	if tex == null:
		return
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(e.position, zoom * 1.15)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(e.position, zoom / 1.15)
		accept_event()
	elif e is InputEventMagnifyGesture:
		_zoom_at(e.position, zoom * e.factor)
	elif e is InputEventPanGesture:
		offset -= e.delta * 20.0
		_clamp()
	elif e is InputEventScreenTouch:
		if e.pressed:
			_touch[e.index] = e.position
			if _touch.size() == 1:
				_tap_start = e.position
				_moved = false
			_pinch_d = _pinch_dist()
		else:
			_touch.erase(e.index)
			_pinch_d = _pinch_dist()
			if _touch.is_empty() and not _moved:
				if e.position.y < _bar_top and e.position.x > size.x - 110:
					close()
					return
				var now := Time.get_ticks_msec() / 1000.0
				if now - _last_tap < 0.3:
					_zoom_at(e.position, fit_zoom * 2.0 if zoom < fit_zoom * 1.5 else fit_zoom)
					_last_tap = -10.0
				else:
					_last_tap = now
		accept_event()
	elif e is InputEventScreenDrag:
		var prev: Vector2 = _touch.get(e.index, e.position)
		_touch[e.index] = e.position
		if e.position.distance_to(_tap_start) > 10.0:
			_moved = true
		if _touch.size() >= 2:
			var d := _pinch_dist()
			if _pinch_d > 0.0 and d > 0.0:
				_zoom_at(_pinch_mid(), zoom * d / _pinch_d)
			_pinch_d = d
			offset += (e.position - prev) * 0.5
			_clamp()
		else:
			offset += e.position - prev
			_clamp()
		accept_event()

func _pinch_dist() -> float:
	if _touch.size() < 2:
		return 0.0
	var v: Array = _touch.values()
	return (v[0] as Vector2).distance_to(v[1])

func _pinch_mid() -> Vector2:
	var v: Array = _touch.values()
	return ((v[0] as Vector2) + (v[1] as Vector2)) * 0.5

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.04, 0.97))
	if tex == null:
		return
	# linear + mipmaps when zoomed out, nearest when zoomed in (crisp pixels)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if zoom >= 1.0 else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	draw_texture_rect(tex, Rect2(offset, Vector2(tex.get_size()) * zoom), false)
	var f := get_theme_default_font()
	var pal: Dictionary = UiTheme.NORMAL
	draw_rect(Rect2(0, 0, size.x, _bar_top), Color(pal.bg, 0.92))
	draw_string(f, Vector2(24, 58), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 150, 30, pal.text)
	draw_rect(Rect2(size.x - 92, 18, 66, 60), pal.accent)
	draw_string(f, Vector2(size.x - 72, 62), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, pal.ink)
	draw_rect(Rect2(0, size.y - _bar_bottom, size.x, _bar_bottom), Color(pal.bg, 0.92))
	draw_string(f, Vector2(24, size.y - _bar_bottom + 40), credits, HORIZONTAL_ALIGNMENT_LEFT, size.x - 48, 22, pal.muted)
	draw_string(f, Vector2(24, size.y - _bar_bottom + 78), "%d x %d  ·  %d%%  ·  pinch / wheel to zoom, drag to pan, double tap to fit" % [
		tex.get_width(), tex.get_height(), int(roundf(zoom * 100.0))], HORIZONTAL_ALIGNMENT_LEFT, size.x - 48, 18, pal.muted)
