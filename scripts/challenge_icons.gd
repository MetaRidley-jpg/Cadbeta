class_name ChallengeIcons
extends RefCounted
## Prize icons for the challenge wall and the info card (drawn in code; no image files).
## silhouette = true: one flat dark shape (hint windows show only the outline of the prize).

const SIL := Color(0.05, 0.02, 0.08, 0.85)

static func draw_prize(ci: CanvasItem, panel: Dictionary, r: Rect2, pal: Dictionary, silhouette: bool, turn := -0.7) -> void:
	if panel.get("gold", false):
		draw_bone(ci, r.get_center(), r.size.x * 0.46, SIL if silhouette else Color("f5c542"), -0.6, not silhouette)
		return
	var rw: Dictionary = Challenges.rewards.get(panel.get("reward", ""), {})
	match String(rw.get("type", "")):
		"art": _art(ci, r, rw, silhouette)
		"tint": _tint(ci, r, Color(String(rw.color)), silhouette)
		"ship": _ship(ci, r, String(rw.strip), silhouette, turn)
		"table": _table(ci, r, Color(String(rw.felt)), Color(String(rw.rim)), silhouette)

static func draw_bone(ci: CanvasItem, c: Vector2, length: float, col: Color, angle := 0.0, shade := false) -> void:
	var d := Vector2(cos(angle), sin(angle))
	var n := Vector2(-d.y, d.x)
	var half := length * 0.5
	var knob := length * 0.16
	var shaft := length * 0.13
	ci.draw_colored_polygon(PackedVector2Array([c - d * half + n * shaft, c + d * half + n * shaft,
		c + d * half - n * shaft, c - d * half - n * shaft]), col)
	for e in [-1.0, 1.0]:
		for s in [-1.0, 1.0]:
			ci.draw_circle(c + d * half * e + n * knob * 0.75 * s, knob, col)
	if shade:
		var hl := col.lightened(0.45)
		ci.draw_line(c - d * half * 0.7 - n * shaft * 0.4, c + d * half * 0.7 - n * shaft * 0.4, hl, maxf(2.0, length * 0.04))

static func _art(ci: CanvasItem, r: Rect2, rw: Dictionary, sil: bool) -> void:
	var f := r.grow(-r.size.x * 0.04)
	f.size.y *= 0.86
	f.position.y += r.size.y * 0.07
	if sil:
		ci.draw_rect(f, SIL)
		return
	ci.draw_rect(f, Color("c8a040"))
	var inner := f.grow(-f.size.x * 0.09)
	ci.draw_rect(inner, Color("ffb070"))
	ci.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y * 0.62), Vector2(inner.size.x, inner.size.y * 0.38)), Color("1d4fa0"))
	ci.draw_circle(inner.position + inner.size * Vector2(0.5, 0.55), inner.size.x * 0.2, Color("ff6a00"))
	ci.draw_colored_polygon(PackedVector2Array([inner.position + inner.size * Vector2(0.05, 0.62),
		inner.position + inner.size * Vector2(0.3, 0.3), inner.position + inner.size * Vector2(0.55, 0.62)]), Color("5c3a63"))
	ci.draw_rect(f, Color("6e4a2e"), false, 2.0)

static func _tint(ci: CanvasItem, r: Rect2, col: Color, sil: bool) -> void:
	var rad := r.size.x * 0.27
	var c := r.get_center() + Vector2(0, r.size.y * 0.14)
	var top := c + Vector2(0, -rad * 2.2)
	var fill := SIL if sil else col
	ci.draw_colored_polygon(PackedVector2Array([top, c + Vector2(rad * 0.9, -rad * 0.45), c + Vector2(-rad * 0.9, -rad * 0.45)]), fill)
	ci.draw_circle(c, rad, fill)
	if not sil:
		ci.draw_circle(c + Vector2(-rad * 0.38, -rad * 0.25), rad * 0.24, col.lightened(0.6))
		ci.draw_circle(c + Vector2(rad * 0.3, rad * 0.35), rad * 0.18, col.darkened(0.25))

static func _ship(ci: CanvasItem, r: Rect2, strip: String, sil: bool, turn: float) -> void:
	var px := maxf(1.0, floorf(r.size.x / maxf(1.0, StackDraw.extent_px(strip, 1.0)) * 1.25))
	StackDraw.draw(ci, strip, r.get_center() + Vector2(0, r.size.y * 0.14), turn, px, 0.62, 0.85,
		SIL if sil else Color.WHITE, sil)

static func _table(ci: CanvasItem, r: Rect2, felt: Color, rim: Color, sil: bool) -> void:
	var t := Rect2(r.position + Vector2(0, r.size.y * 0.2), Vector2(r.size.x, r.size.y * 0.6))
	if sil:
		_round(ci, t, SIL)
		return
	_round(ci, t, rim)
	_round(ci, t.grow(-r.size.x * 0.07), felt)
	var card := Rect2(t.get_center() + Vector2(-r.size.x * 0.17, -r.size.y * 0.14), Vector2(r.size.x * 0.18, r.size.y * 0.25))
	ci.draw_rect(card, Color("fff6e4"))
	ci.draw_rect(Rect2(card.position + Vector2(r.size.x * 0.14, r.size.y * 0.02), card.size), Color("fff6e4"))
	ci.draw_rect(Rect2(card.position + Vector2(r.size.x * 0.14, r.size.y * 0.02), card.size), Color("ff1f4b"), false, 2.0)

static func _round(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var rad := r.size.y * 0.5
	ci.draw_rect(Rect2(r.position + Vector2(rad, 0), Vector2(r.size.x - rad * 2.0, r.size.y)), col)
	ci.draw_circle(r.position + Vector2(rad, rad), rad, col)
	ci.draw_circle(r.position + Vector2(r.size.x - rad, rad), rad, col)
