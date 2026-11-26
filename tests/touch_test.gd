extends Node
## Touch test: sends the same finger events a phone (or iPhone Safari) sends.
## Bug 2026-11-26: on the web build, lists did not scroll when the drag started on
## a card or a button. Also checks the Play home screen (app icons).
## Run: godot --headless --path . res://tests/touch_test.tscn --quit-after 3000 -- --fresh
var fails := 0
var passes := 0
var pressed_log: Array = []

func check(c: bool, msg: String) -> void:
	if c:
		passes += 1
	else:
		fails += 1
		printerr("FAIL: ", msg)

func frames(n := 2) -> void:
	for k in n:
		await get_tree().process_frame

func scr(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p

func touch(pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0; e.position = scr(pos); e.pressed = down
	Input.parse_input_event(e)

func tap(pos: Vector2) -> void:
	touch(pos, true); await frames(2); touch(pos, false); await frames(3)

func drag(from: Vector2, to: Vector2, steps := 12) -> void:
	touch(from, true)
	await frames(2)
	var prev := from
	var k := get_viewport().get_final_transform().get_scale()
	for s in range(1, steps + 1):
		var p := from.lerp(to, float(s) / steps)
		var e := InputEventScreenDrag.new()
		e.index = 0; e.position = scr(p); e.relative = (p - prev) * k; e.velocity = (p - prev) * k * 60
		Input.parse_input_event(e)
		prev = p
		await frames(1)
	touch(to, false)
	await frames(3)

func _ready() -> void:
	Challenges.enabled = false
	# a mid-game save so the long lists overflow the screen
	for i in Balance.BUILDINGS.size():
		Game.owned[i] = 25
	Game.bones = 1e30
	Game.marrow = 500
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(10)
	check(DisplayServer.is_touchscreen_available(), "touch input is on (emulated on desktop)")
	for b in main.find_children("*", "BaseButton", true, false):
		b.pressed.connect(func(): pressed_log.append(b.get_path()))
	# ---- every list page: a drag that starts on a card / button must scroll and press nothing
	var tested := 0
	for page_i in [0, 1, 2, 3, 5]:
		main.show_page(page_i)
		await frames(5)
		var sc: ScrollContainer = main.pages[page_i] if page_i != 0 else main.get_node("%BuildingsPage").get_node("Scroll")
		var vb := sc.get_v_scroll_bar()
		if vb.max_value <= vb.page + 120:
			continue  # this page fits on screen today
		tested += 1
		for want in ["PanelContainer", "BaseButton"]:
			sc.scroll_vertical = 0
			await frames(3)
			var ctl: Control = null
			for c in sc.find_children("*", want, true, false):
				if c.is_visible_in_tree() and sc.get_global_rect().encloses(c.get_global_rect()) and c.get_global_rect().position.y > sc.get_global_rect().position.y + 260 and c.get_global_rect().end.y < sc.get_global_rect().end.y - 140:
					ctl = c
					break
			if ctl == null:
				continue
			sc.scroll_vertical = 0
			await frames(2)
			pressed_log.clear()
			var start := ctl.get_global_rect().get_center()
			await drag(start, start - Vector2(0, 240))
			check(sc.scroll_vertical > 120, "page %d: drag on a %s scrolls (got %d)" % [page_i, want, sc.scroll_vertical])
			check(pressed_log.is_empty(), "page %d: drag on a %s presses nothing (%s)" % [page_i, want, str(pressed_log)])
	check(tested >= 2, "at least 2 list pages overflow and were drag-tested (%d)" % tested)
	# ---- Play home screen
	main.show_page(main.PAGE_PLAY)
	await frames(5)
	var pv := (main.pages[main.PAGE_PLAY] as ScrollContainer).get_v_scroll_bar()
	check(pv.max_value <= pv.page + 1, "Play home fits on one screen (content %d, screen %d)" % [pv.max_value, pv.page])
	var icons: Array = main.get_node("%PlayList").find_children("*", "PlayIcon", true, false)
	check(icons.size() == 6, "6 app icons (%d)" % icons.size())
	for ic in icons:
		check((ic as Control).size.x >= 150 and (ic as Control).size.y >= 190, "icon %s is a big touch target" % ic.title)
	check(main._play_widgets.pinball.disabled, "Pinball icon is locked (not built)")
	await tap(main._play_widgets.options.tile_rect().get_center() + main._play_widgets.options.global_position)
	check(main._play_widgets.opts.visible and not main._play_widgets.home.visible, "tap Options opens the options sheet")
	main._show_play_options(false)
	await frames(3)
	await tap(main._play_widgets.df_start.global_position + main._play_widgets.df_start.tile_rect().get_center())
	check(main.in_minigame and main.get_node("%DogfightPage").visible, "tap the Dogfight icon starts the dogfight")
	print("TOUCH TESTS: %d passed, %d failed" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)
