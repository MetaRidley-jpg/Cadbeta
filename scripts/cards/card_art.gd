class_name CardArt
extends RefCounted
## Card faces and backs drawn in code (suits as shapes, no font glyphs needed).
## Used once to paint the card atlas (CardAtlas), so the 3D card room can lay
## cards on the felt as textured quads.

static func round_rect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	ci.draw_rect(Rect2(r.position + Vector2(rad, 0), Vector2(r.size.x - rad * 2, r.size.y)), col)
	ci.draw_rect(Rect2(r.position + Vector2(0, rad), Vector2(r.size.x, r.size.y - rad * 2)), col)
	for cx in [r.position.x + rad, r.end.x - rad]:
		for cy in [r.position.y + rad, r.end.y - rad]:
			ci.draw_circle(Vector2(cx, cy), rad, col)

static func face(ci: CanvasItem, r: Rect2, c: Dictionary, font: Font) -> void:
	round_rect(ci, r, r.size.x * 0.09, Color(0.1, 0.06, 0.18))
	round_rect(ci, r.grow(-3), r.size.x * 0.08, Color(1.0, 0.97, 0.9))
	var ink := Color("d81e3c") if Blackjack.is_red(c) else Color("1a0f2e")
	var sz := int(r.size.y * 0.2)
	var t := Blackjack.rank_text(c)
	ci.draw_string(font, r.position + Vector2(r.size.x * 0.1, sz * 1.05), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, ink)
	suit(ci, r.position + Vector2(r.size.x * 0.2, sz * 1.6), sz * 0.32, int(c.s), ink)
	# big rank + suit in the middle so the card reads at a glance from your seat
	var big := int(r.size.y * 0.3)
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	ci.draw_string(font, Vector2(r.get_center().x - w * 0.5 + r.size.x * 0.1, r.get_center().y + big * 0.15), t, HORIZONTAL_ALIGNMENT_LEFT, -1, big, ink)
	suit(ci, r.get_center() + Vector2(0, r.size.y * 0.27), r.size.x * 0.15, int(c.s), ink)

static func back(ci: CanvasItem, r: Rect2) -> void:
	round_rect(ci, r, r.size.x * 0.09, Color("1a0f2e"))
	round_rect(ci, r.grow(-3), r.size.x * 0.08, Color("5c2a7a"))
	round_rect(ci, r.grow(-9), r.size.x * 0.06, Color("7b3aa0"))
	ChallengeIcons.draw_bone(ci, r.get_center(), r.size.x * 0.62, Color("efe6d2"), -0.9)

## 0 spade, 1 heart, 2 club, 3 diamond.
static func suit(ci: CanvasItem, c: Vector2, r: float, s: int, col: Color) -> void:
	match s:
		1:
			ci.draw_circle(c + Vector2(-r * 0.5, -r * 0.25), r * 0.55, col)
			ci.draw_circle(c + Vector2(r * 0.5, -r * 0.25), r * 0.55, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.02, -r * 0.05), c + Vector2(r * 1.02, -r * 0.05), c + Vector2(0, r * 1.0)]), col)
		0:
			ci.draw_circle(c + Vector2(-r * 0.5, r * 0.2), r * 0.55, col)
			ci.draw_circle(c + Vector2(r * 0.5, r * 0.2), r * 0.55, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.02, r * 0.05), c + Vector2(r * 1.02, r * 0.05), c + Vector2(0, -r * 1.0)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.3), c + Vector2(-r * 0.4, r * 1.0), c + Vector2(r * 0.4, r * 1.0)]), col)
		2:
			ci.draw_circle(c + Vector2(0, -r * 0.45), r * 0.45, col)
			ci.draw_circle(c + Vector2(-r * 0.5, r * 0.15), r * 0.45, col)
			ci.draw_circle(c + Vector2(r * 0.5, r * 0.15), r * 0.45, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0), c + Vector2(-r * 0.4, r * 1.0), c + Vector2(r * 0.4, r * 1.0)]), col)
		3:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.75, 0), c + Vector2(0, r), c + Vector2(-r * 0.75, 0)]), col)
