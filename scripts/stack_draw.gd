class_name StackDraw
extends RefCounted
## Live sprite-stack drawing for the UI (danielwh2/sprite-stacking method):
## slices drawn ground-first, every slice rotated by the same angle, squashed in
## screen space, and lifted one step. One outline around the finished stack:
## a white silhouette strip drawn 4x offset in the outline color before the slices.
## The canvas item that draws must use NEAREST texture filtering.

const OUTLINE := Color("1a0f2e")
static var _cache := {}   # name -> {tex, sil, n, w, h}

static func strip(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var path := "res://art/stacks/%s.png" % name
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		return {}
	var img: Image = null
	if FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		img = Image.load_from_file(ProjectSettings.globalize_path(path))   # dev: no re-import needed
	if img == null:
		img = (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/stacks/%s.json" % name))
	var sil := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				sil.set_pixel(x, y, Color.WHITE)
	var n := int(meta.slices)
	var d := {"tex": ImageTexture.create_from_image(img), "sil": ImageTexture.create_from_image(sil),
		"n": n, "w": img.get_width() / n, "h": img.get_height()}
	_cache[name] = d
	return d

## center = where the ground slice sits. px = screen pixels per art pixel.
## silhouette: draw a flat shape in `mod` (hint windows).
static func draw(ci: CanvasItem, name: String, center: Vector2, angle: float, px: float,
		squash := 0.62, lift := 0.85, mod := Color.WHITE, silhouette := false) -> void:
	var s := strip(name)
	if s.is_empty():
		return
	var n: int = s.n
	var w: float = s.w
	var h: float = s.h
	var dst := Rect2(-w * 0.5, -h * 0.5, w, h)
	var passes: Array = []
	if not silhouette:
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			passes.append([s.sil, o * px, Color(OUTLINE, mod.a)])
	passes.append([s.sil if silhouette else s.tex, Vector2.ZERO, mod])
	var rot := Transform2D(angle, Vector2(px, px), 0.0, Vector2.ZERO)
	for p in passes:
		for k in n:
			var at: Vector2 = center + p[1] + Vector2(0, -k * px * lift)
			var t := Transform2D(0.0, Vector2(1.0, squash), 0.0, at) * rot
			ci.draw_set_transform_matrix(t)
			ci.draw_texture_rect_region(p[0], dst, Rect2(k * w, 0, w, h), p[2])
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

## Rough on-screen size (for fitting into a box).
static func extent_px(name: String, px: float) -> float:
	var s := strip(name)
	if s.is_empty():
		return 0.0
	return maxf(s.w, s.h) * px + s.n * px
