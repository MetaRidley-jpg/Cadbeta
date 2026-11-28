class_name DfSheathMeter
extends Control
## T's laser meter (2026-11-28): his katana (art/blade/blade.png, from tools/blade/make_blade.py)
## in a dark red sheath (his sheath bar sketch). The hilt stays; the blade slides OUT of the
## sheath as the laser charges. Ready: a light band runs hilt -> tip (2 hard steps). Cyan
## (supercharged by a ring course): the blade is tinted cyan.
const BLADE := "res://art/blade/blade.png"
const HILT_W := 42.0               # blade.png: columns before the blade (pommel, grip, hex collar, guard)
const SHEATH := Color("6a1f22")
const SHEATH_D := Color("3d1114")
const SHEATH_CAP := Color("e68c3c")
const INK := Color("0b0a10")
var charge := 0.0                  # 0..1
var lit := false               # laser ready: the blade shimmers
var cyan := false
var _tex: Texture2D
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(BLADE):
		_tex = load(BLADE)
	elif FileAccess.file_exists(ProjectSettings.globalize_path(BLADE)):
		_tex = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(BLADE)))
	custom_minimum_size = Vector2(366, 52)   # 2x pixels
	size_flags_horizontal = Control.SIZE_SHRINK_END     # right side: clear of the ALT label

func set_values(c: float, r: bool, cy: bool) -> void:
	charge = clampf(c, 0.0, 1.0)
	lit = r
	cyan = cy

func _process(d: float) -> void:
	_t += d
	queue_redraw()

func _draw() -> void:
	if _tex == null:
		return
	var tw := _tex.get_width()
	var th := _tex.get_height()
	var sc := floorf(size.y / th) if size.y >= th else size.y / th
	sc = maxf(sc, 1.0)
	var o := Vector2(0, roundf((size.y - th * sc) * 0.5))
	var blade_w := tw - HILT_W
	# sheath behind the blade: dark red, black outline, orange end cap (T's sheath bar)
	var sh := Rect2(o + Vector2((HILT_W - 1) * sc, 5 * sc), Vector2((blade_w + 2) * sc, (th - 10) * sc))
	draw_rect(sh.grow(sc), INK)
	draw_rect(sh, SHEATH)
	draw_rect(Rect2(sh.position + Vector2(0, sh.size.y * 0.6), Vector2(sh.size.x, sh.size.y * 0.4)), SHEATH_D)
	draw_rect(Rect2(sh.end.x - 5 * sc, sh.position.y, 5 * sc, sh.size.y), SHEATH_CAP)
	for k in 6:                                                # the little slots along the sheath
		draw_rect(Rect2(sh.position + Vector2((40 + k * 6) * sc, 3 * sc), Vector2(2 * sc, 3 * sc)), INK)
	# hilt (always)
	draw_texture_rect_region(_tex, Rect2(o, Vector2(HILT_W, th) * sc), Rect2(0, 0, HILT_W, th))
	# blade: the drawn part (out of the sheath)
	var out_w := roundf(blade_w * charge)
	if out_w >= 1.0:
		var tint := Color(0.7, 1.15, 1.3) if cyan else Color.WHITE
		draw_texture_rect_region(_tex, Rect2(o + Vector2(HILT_W * sc, 0), Vector2(out_w, th) * sc), Rect2(HILT_W, 0, out_w, th), tint)
		if lit:                                                # shimmer: a light band hilt -> tip
			var head := fmod(_t * 0.9, 1.3) * blade_w - 10.0
			for band in [[3.0, 1.55], [7.0, 1.25]]:
				var x0 := clampf(head - band[0], 0.0, blade_w)
				var x1 := clampf(head + band[0], 0.0, blade_w)
				if x1 > x0:
					draw_texture_rect_region(_tex, Rect2(o + Vector2((HILT_W + x0) * sc, 0), Vector2(x1 - x0, th) * sc), Rect2(HILT_W + x0, 0, x1 - x0, th), tint * Color(band[1], band[1], band[1]))
