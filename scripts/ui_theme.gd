class_name UiTheme
extends RefCounted
## Builds the whole UI Theme in code. Two palettes: NORMAL and FEVER.
## apply_palette() recolors every stylebox in place, so all screens switch at once.
## Placeholder look: Dreamcast orange + bone white on dark plum. Swap freely.

const NORMAL := {
	"bg": Color("15121a"), "panel": Color("1f1a25"), "card": Color("2a2431"),
	"card_hi": Color("372f40"), "text": Color("efe6d2"), "muted": Color("9c93a3"),
	"accent": Color("f26a1b"), "accent2": Color("43c6b8"), "ink": Color("1a1410"),
	"speech": Color("efe6d2"), "speech_ink": Color("231c26"), "good": Color("7bd88f"),
}
const FEVER := {
	"bg": Color("26081f"), "panel": Color("3a0d2f"), "card": Color("4a123d"),
	"card_hi": Color("5e1850"), "text": Color("ffe9f3"), "muted": Color("d79cc2"),
	"accent": Color("ff3d8b"), "accent2": Color("ffd23f"), "ink": Color("2a0618"),
	"speech": Color("ffd9ea"), "speech_ink": Color("3a0d2f"), "good": Color("ffd23f"),
}

var theme := Theme.new()
var pal: Dictionary = NORMAL
var _boxes := {}   # name -> StyleBoxFlat

func _box(key: String, radius := 16, margin := 12.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	sb.anti_aliasing = true
	_boxes[key] = sb
	return sb

func build() -> Theme:
	theme.default_font_size = 24

	# ---- panels ----
	for v in ["Card", "TopBar", "Stage", "NavBar", "Dialogue", "RankBox", "ModalCard", "CardHi", "ManagerCard"]:
		theme.set_type_variation(v, "PanelContainer")
	theme.set_stylebox("panel", "Card", _box("card", 18, 12))
	theme.set_stylebox("panel", "CardHi", _box("card_hi", 18, 12))
	var top := _box("top", 0, 16)
	top.border_width_bottom = 4
	top.content_margin_top = 14
	theme.set_stylebox("panel", "TopBar", top)
	theme.set_stylebox("panel", "Stage", _box("stage", 0, 14))
	var nav := _box("nav", 0, 6)
	nav.border_width_top = 3
	theme.set_stylebox("panel", "NavBar", nav)
	var dlg := _box("dialogue", 22, 16)
	dlg.border_width_left = 5
	dlg.border_width_right = 5
	dlg.border_width_top = 5
	dlg.border_width_bottom = 5
	theme.set_stylebox("panel", "Dialogue", dlg)
	theme.set_stylebox("panel", "RankBox", _box("rank", 10, 8))
	var pop := _box("popup", 24, 28)
	pop.border_width_left = 4
	pop.border_width_right = 4
	pop.border_width_top = 4
	pop.border_width_bottom = 4
	pop.shadow_size = 24
	pop.shadow_color = Color(0, 0, 0, 0.6)
	theme.set_stylebox("panel", "ModalCard", pop)
	var mgr := _box("manager", 18, 12)
	mgr.border_width_left = 4
	mgr.border_width_right = 4
	mgr.border_width_top = 4
	mgr.border_width_bottom = 4
	mgr.shadow_size = 18
	mgr.shadow_color = Color(0, 0, 0, 0.55)
	theme.set_stylebox("panel", "ManagerCard", mgr)

	# ---- buttons ----
	theme.set_stylebox("normal", "Button", _box("btn", 14, 10))
	theme.set_stylebox("hover", "Button", _box("btn_hover", 14, 10))
	theme.set_stylebox("pressed", "Button", _box("btn_pressed", 14, 10))
	theme.set_stylebox("disabled", "Button", _box("btn_disabled", 14, 10))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_type_variation("GhostButton", "Button")
	for st in ["normal", "hover", "pressed", "disabled"]:
		var g := _box("ghost_" + st, 12, 6)
		g.border_width_left = 2
		g.border_width_right = 2
		g.border_width_top = 2
		g.border_width_bottom = 2
		theme.set_stylebox(st, "GhostButton", g)
	theme.set_font_size("font_size", "GhostButton", 18)
	theme.set_type_variation("NavButton", "Button")
	for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var nb := _box("nav_" + st, 12, 6)
		nb.border_width_bottom = 5 if st in ["pressed", "hover_pressed"] else 0
		theme.set_stylebox(st, "NavButton", nb)
	theme.set_stylebox("focus", "NavButton", StyleBoxEmpty.new())
	theme.set_font_size("font_size", "NavButton", 20)
	theme.set_type_variation("RunButton", "Button")
	for st in ["normal", "hover", "pressed", "disabled"]:
		var rb := _box("run_" + st, 20, 4)
		rb.border_width_bottom = 6 if st != "pressed" else 2
		theme.set_stylebox(st, "RunButton", rb)
	theme.set_font_size("font_size", "RunButton", 26)

	# ---- progress bars ----
	theme.set_stylebox("background", "ProgressBar", _box("bar_bg", 10, 0))
	theme.set_stylebox("fill", "ProgressBar", _box("bar_fill", 10, 0))
	theme.set_type_variation("FeverBar", "ProgressBar")
	theme.set_stylebox("background", "FeverBar", _box("fever_bg", 8, 0))
	theme.set_stylebox("fill", "FeverBar", _box("fever_fill", 8, 0))
	theme.set_type_variation("LevelBar", "ProgressBar")
	theme.set_stylebox("background", "LevelBar", _box("level_bg", 4, 0))
	theme.set_stylebox("fill", "LevelBar", _box("level_fill", 4, 0))

	# ---- labels ----
	for v in ["BigLabel", "SmallLabel", "TitleLabel", "MutedLabel", "SpeechLabel", "NamePlate", "AccentLabel", "ManagerName"]:
		theme.set_type_variation(v, "Label")
	theme.set_font_size("font_size", "BigLabel", 52)
	theme.set_font_size("font_size", "TitleLabel", 26)
	theme.set_font_size("font_size", "SmallLabel", 19)
	theme.set_font_size("font_size", "MutedLabel", 19)
	theme.set_font_size("font_size", "SpeechLabel", 25)
	theme.set_font_size("font_size", "NamePlate", 18)
	theme.set_font_size("font_size", "AccentLabel", 22)
	theme.set_font_size("font_size", "ManagerName", 21)
	theme.set_constant("outline_size", "BigLabel", 0)
	theme.set_font_size("normal_font_size", "RichTextLabel", 25)

	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("separation", "HBoxContainer", 10)
	apply_palette(NORMAL)
	return theme

func apply_palette(p: Dictionary) -> void:
	pal = p
	_boxes.card.bg_color = p.card
	_boxes.card_hi.bg_color = p.card_hi
	_boxes.top.bg_color = p.panel
	_boxes.top.border_color = p.accent
	_boxes.stage.bg_color = p.bg
	_boxes.nav.bg_color = p.panel
	_boxes.nav.border_color = p.card_hi
	_boxes.dialogue.bg_color = p.speech
	_boxes.dialogue.border_color = p.accent
	_boxes.manager.bg_color = p.panel
	_boxes.manager.border_color = p.accent2
	_boxes.level_bg.bg_color = p.bg
	_boxes.level_fill.bg_color = p.text
	_boxes.popup.bg_color = p.panel
	_boxes.popup.border_color = p.accent
	_boxes.btn.bg_color = p.accent
	_boxes.btn_hover.bg_color = p.accent.lightened(0.12)
	_boxes.btn_pressed.bg_color = p.accent.darkened(0.2)
	_boxes.btn_disabled.bg_color = p.card_hi
	for st in ["normal", "hover", "pressed", "disabled"]:
		var g: StyleBoxFlat = _boxes["ghost_" + st]
		g.bg_color = Color(p.accent2, 0.0 if st == "normal" else 0.18)
		g.border_color = p.muted if st == "disabled" else p.accent2
		var rb: StyleBoxFlat = _boxes["run_" + st]
		rb.bg_color = p.card_hi.lightened(0.08 if st == "hover" else 0.0)
		rb.border_color = p.accent2 if st != "disabled" else p.card
		if st == "disabled":
			rb.bg_color = p.card
	for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var nb: StyleBoxFlat = _boxes["nav_" + st]
		nb.bg_color = p.card if st in ["pressed", "hover_pressed"] else Color(0, 0, 0, 0)
		nb.border_color = p.accent
	_boxes.bar_bg.bg_color = p.bg
	_boxes.bar_fill.bg_color = p.accent2
	_boxes.fever_bg.bg_color = p.card
	_boxes.fever_fill.bg_color = p.accent

	theme.set_color("font_color", "Label", p.text)
	theme.set_color("font_color", "BigLabel", p.text)
	theme.set_color("font_color", "TitleLabel", p.text)
	theme.set_color("font_color", "SmallLabel", p.text)
	theme.set_color("font_color", "MutedLabel", p.muted)
	theme.set_color("font_color", "AccentLabel", p.accent2)
	theme.set_color("font_color", "SpeechLabel", p.speech_ink)
	theme.set_color("font_color", "NamePlate", p.accent)
	theme.set_color("font_color", "ManagerName", p.accent2)
	theme.set_color("default_color", "RichTextLabel", p.speech_ink)
	theme.set_color("font_color", "Button", p.ink)
	theme.set_color("font_hover_color", "Button", p.ink)
	theme.set_color("font_pressed_color", "Button", p.ink)
	theme.set_color("font_disabled_color", "Button", p.muted)
	theme.set_color("font_focus_color", "Button", p.ink)
	for v in ["GhostButton", "NavButton", "RunButton"]:
		theme.set_color("font_color", v, p.text)
		theme.set_color("font_hover_color", v, p.text)
		theme.set_color("font_pressed_color", v, p.accent if v == "NavButton" else p.text)
		theme.set_color("font_hover_pressed_color", v, p.accent if v == "NavButton" else p.text)
		theme.set_color("font_focus_color", v, p.text)
		theme.set_color("font_disabled_color", v, p.muted)
	for sb in _boxes.values():
		sb.emit_changed()
