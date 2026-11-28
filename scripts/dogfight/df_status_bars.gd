class_name DfStatusBars
extends Control
## T's HUD (2026-11-28, his Figma sheet): three rows with icons.
##   orange outline triangle  SHIELD  thin bar, orange; grey = empty
##   3 green dots             HULL    thick bar, green (red under 30%); grey = damage just taken
##                                    (the ghost holds, then drains); black = lost
##   blue down triangle       BOOST   10 segments, blue with a lighter centre band; black = empty
## Colours = T's swatch row.
const C_GREEN := Color("5bba90")
const C_RED := Color("e03c3c")
const C_ORANGE := Color("e68c3c")
const C_GREY := Color("92919b")
const C_BLACK := Color("222222")
const C_BLUE := Color("3d8ff0")
const C_BLUE_HI := Color("52b4f8")
const ICON_W := 26.0
const ROW_H := [10.0, 17.0, 8.0]
const GAP := 4.0
const PLATE := Color(0.05, 0.05, 0.08, 0.6)   # dark backing: the bars stay readable over a busy sky
const LOW := 0.3

var shield := 1.0       # 0..1
var hull := 1.0         # 0..1
var ghost := 1.0        # 0..1 (>= hull)
var boost := 1.0        # 0..1

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, ROW_H[0] + ROW_H[1] + ROW_H[2] + GAP * 2.0)

func set_values(s: float, h: float, g: float, b: float) -> void:
	if is_equal_approx(s, shield) and is_equal_approx(h, hull) and is_equal_approx(g, ghost) and is_equal_approx(b, boost):
		return
	shield = clampf(s, 0.0, 1.0)
	hull = clampf(h, 0.0, 1.0)
	ghost = clampf(maxf(g, h), 0.0, 1.0)
	boost = clampf(b, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2(-4, -3), size + Vector2(8, 6)), PLATE)
	var w := size.x - ICON_W
	var y := 0.0
	# shield
	var r0 := Rect2(ICON_W, y, w, ROW_H[0])
	draw_rect(r0, C_GREY)
	draw_rect(Rect2(r0.position, Vector2(roundf(w * shield), r0.size.y)), C_ORANGE)
	_tri(Vector2(ICON_W * 0.42, y + ROW_H[0] * 0.5 + 1.0), 8.0, C_ORANGE, false, true)
	y += ROW_H[0] + GAP
	# hull
	var r1 := Rect2(ICON_W, y, w, ROW_H[1])
	draw_rect(r1, C_BLACK)
	draw_rect(Rect2(r1.position, Vector2(roundf(w * ghost), r1.size.y)), C_GREY)
	draw_rect(Rect2(r1.position, Vector2(roundf(w * hull), r1.size.y)), C_RED if hull < LOW else C_GREEN)
	var hc := Vector2(ICON_W * 0.42, y + ROW_H[1] * 0.5)
	for d in [Vector2(0, -4.5), Vector2(-5, 4), Vector2(5, 4)]:
		draw_rect(Rect2((hc + d - Vector2(2.5, 2.5)).round(), Vector2(5, 5)), C_GREEN)
	y += ROW_H[1] + GAP
	# boost: 10 segments
	var seg_gap := 3.0
	var sw := (w - seg_gap * 9.0) / 10.0
	var lit := int(roundf(boost * 10.0))
	for i in 10:
		var rs := Rect2(roundf(ICON_W + i * (sw + seg_gap)), y, roundf(sw), ROW_H[2])
		if i < lit:
			draw_rect(rs, C_BLUE)
			draw_rect(Rect2(rs.position + Vector2(rs.size.x * 0.25, 0), Vector2(roundf(rs.size.x * 0.5), rs.size.y)), C_BLUE_HI)   # chunky centre band
		else:
			draw_rect(rs, C_BLACK)
	_tri(Vector2(ICON_W * 0.42, y + ROW_H[2] * 0.5), 7.0, C_BLUE, true, false)

func _tri(c: Vector2, r: float, col: Color, filled: bool, up: bool) -> void:
	var s := -1.0 if up else 1.0
	var pts := PackedVector2Array([c + Vector2(0, s * r), c + Vector2(-r, -s * r * 0.75), c + Vector2(r, -s * r * 0.75)])
	if filled:
		draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		draw_polyline(pts, col, 2.0)
