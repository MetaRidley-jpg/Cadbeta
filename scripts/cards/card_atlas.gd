class_name CardAtlas
extends SubViewport
## Paints all 52 faces + the back once into an offscreen atlas (14 x 4 cells).
## The card room uses this texture to lay cards flat on the felt in perspective.

const CELL := Vector2(128, 180)
const COLS := 14

var _painter: Control

func _ready() -> void:
	size = Vector2i(int(CELL.x) * COLS, int(CELL.y) * 4)
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_ONCE
	_painter = Control.new()
	_painter.size = Vector2(size)
	_painter.draw.connect(_paint)
	add_child(_painter)

func _paint() -> void:
	var f := _painter.get_theme_default_font()
	for s in 4:
		for r in range(1, 14):
			CardArt.face(_painter, Rect2(Vector2((r - 1) * CELL.x, s * CELL.y) + Vector2(4, 4), CELL - Vector2(8, 8)), {"r": r, "s": s}, f)
	CardArt.back(_painter, Rect2(Vector2(13 * CELL.x, 0) + Vector2(4, 4), CELL - Vector2(8, 8)))

## Normalized UV rect of a card (or the back when card is empty).
func uv(card: Dictionary) -> Rect2:
	var cell := Vector2(13, 0) if card.is_empty() else Vector2(int(card.r) - 1, int(card.s))
	var px := Rect2(cell * CELL + Vector2(4, 4), CELL - Vector2(8, 8))
	var tot := Vector2(size)
	return Rect2(px.position / tot, px.size / tot)
