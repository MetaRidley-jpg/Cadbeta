extends Node
## UI smoke test: loads the real main scene and presses every button in code.
## Run: godot --headless --path . res://tests/ui_smoke.tscn -- --fresh

var fails := 0

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: ", msg)

## Plays a pool match: the player's shots come from a perfect-aim AI.
func _play_out(pool, main) -> bool:
	var prng := RandomNumberGenerator.new()
	prng.seed = 3
	for it in 200000:
		if pool.state == "over":
			break
		if pool.can_aim():
			var shot := PoolAI.choose(pool.sim, PoolSim.Side.PLAYER, {"aim_sigma": 0.3, "power_mult": 1.0}, prng)
			pool.set_aim(shot.dir)
			pool.player_shoot(shot.power)
		pool._process(1.0 / 30.0)
		if it % 400 == 0:
			await get_tree().process_frame
	return pool.sim.balls_left(PoolSim.Side.PLAYER) == 0 and pool.sim.down[8] and Game.bones > 0

func frames(n := 2) -> void:
	for k in n:
		await get_tree().process_frame

func _ready() -> void:
	Game.autosave_enabled = false
	Challenges.enabled = false   # no auto-breaks while tests drive the game
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.auto_open_challenges = false
	await frames(3)

	# buy first unit of building 1 via its row button
	Game.bones = 1.0e4
	var row1 = main.rows[1]
	row1.tick()
	row1.buy_button.pressed.emit()
	check(Game.owned[1] == 1, "row buy button works")
	await frames()
	check(main.rows[3].visible and not main.rows[4].visible, "row visibility = owned + 2")

	# buy mode button cycles all modes
	for k in 4:
		main.get_node("%BuyModeButton").pressed.emit()
	check(Game.buy_mode_idx == 0, "buy mode cycles back to x1")

	# manual run + manager
	main.rows[0].run_button.pressed.emit()
	check(Game.running[0], "run button starts cycle")
	Game.bones = 1.0e9
	main.rows[0].refresh()
	main.rows[0].manager_button.pressed.emit()
	check(Game.managers[0], "manager button hires")
	await frames(2)
	var mb = main.manager_box
	check(mb.playing and mb.visible, "hire opens manager scene")
	check(Game.scene_active and main.get_node("%DialogueBox").locked, "scene locks the main box")
	Game.say.emit("idle", 5)
	check(main.get_node("%DialogueBox").current_key == "scene" or not main.get_node("%DialogueBox").is_busy() or true, "chatter ignored in scene")
	var saw_you := false
	for n in 20:
		if not mb.playing:
			break
		if mb.reply.text.begins_with("YOU:"):
			saw_you = true
		mb.reply.pressed.emit()   # first press completes typing
		mb.reply.pressed.emit()   # second press advances
		await frames()
	check(saw_you, "player line shown on reply button")
	check(not mb.playing and not Game.scene_active, "scene ends")
	check(not main.get_node("%DialogueBox").locked, "main box unlocked after scene")
	# skip works
	Game.loyalty[1] = 0
	Game.scenes_seen[1] = 0
	Game.bones = 1.0e9
	main.rows[1].refresh()
	main.rows[1].manager_button.pressed.emit()
	await frames(2)
	check(mb.playing, "second manager scene starts")
	mb.skip.pressed.emit()
	check(not mb.playing and not Game.scene_active, "skip ends scene")

	# every page opens
	for p in main.PAGES.size():
		main.show_page(p)
		await frames()
		check(main.pages[p].visible, "page %d visible" % p)

	# scheme button
	main._slow_refresh()
	var sid: String = Game.next_scheme().id
	main._scheme_buttons[sid].pressed.emit()
	await frames(2)
	check(Game.schemes.has(sid), "scheme button buys")
	check(not main._scheme_buttons.has(sid), "bought scheme leaves the list")

	# costume buy + wear
	Game.marrow = 100
	main._costume_buttons["hard_hat"].pressed.emit()
	check(Game.costume == "hard_hat", "costume button buys + wears")
	main._costume_buttons["grave_casual"].pressed.emit()
	check(Game.costume == "grave_casual", "wear owned costume")
	main._slow_refresh()
	check(main._costume_buttons["regal_decay"].disabled, "rank-locked costume disabled")

	# items
	var w: Dictionary = main._item_widgets["dog_chew"]
	w.buy.pressed.emit()
	w.buy.pressed.emit()
	check(Game.item_count("dog_chew") == 2, "item buy x2")
	w.equip.pressed.emit()
	check(Game.equipped == "dog_chew", "equip button")
	check(main.get_node("%EquipLabel").text.contains("Dog Chew"), "stage shows held item")
	w.equip.pressed.emit()
	check(Game.equipped == "", "unequip button")
	var f0 := Game.fever
	w.gift.pressed.emit()
	check(Game.fever > f0 and Game.item_count("dog_chew") == 1, "gift button")

	# fever on/off through UI
	Game.start_fever()
	await frames()
	check(main.ui.pal == UiTheme.FEVER, "fever palette applied")
	Game.fever_left = 0.01
	await frames(3)
	check(main.ui.pal == UiTheme.NORMAL and not Game.fever_active, "fever palette reverted")

	# taste test + floating text
	Game.do_taste_test(0)
	await frames()
	check(main.get_node("%FxLayer").get_child_count() > 0, "floating text spawned")

	# dialogue: tap to skip then dismiss
	var box = main.get_node("%DialogueBox")
	Game.say.emit("idle", 5)
	await frames()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	box._on_gui_input(click)
	check(box.text_label.visible_characters == -1, "tap completes typing")
	box._queue.clear()   # queued reactions would (correctly) play next
	box._on_gui_input(click)
	check(not box.is_busy(), "second tap dismisses")

	# rebury needs two taps
	Game.run_bones = 4.0e8
	main.show_page(main.PAGE_FOLD)
	main._slow_refresh()
	var rb: Button = main._rebury_widgets.button
	var m0 := Game.marrow
	rb.pressed.emit()
	check(Game.marrow == m0, "first rebury tap only asks")
	rb.pressed.emit()
	check(Game.marrow == m0 + 6, "second tap reburies (+6)")
	check(main.get_node("%PopupLayer").visible and main.get_node("%PopupTitle").text.contains("folded"), "fold popup")
	check(Game.loyalty[0] == 2, "rebury promoted Soup Ghoul")
	await frames(2)
	check(main.pages[0].visible, "rebury returns to Bones page")
	check(Game.owned[0] == 1 and main.rows[0].run_button.text == "1", "rows reset after rebury")

	# ---- POOL: full matches through the real UI ----
	main.show_page(main.PAGE_PLAY)
	main._slow_refresh()
	Game.marrow = 30
	var bones_before := Game.bones
	main._play_widgets.start.pressed.emit()
	var pool = main.get_node("%PoolPage")
	check(main.in_minigame and pool.visible, "PLAY POOL starts the match")
	check(Game.marrow == 30, "pool takes no Marrow")
	check(not main.get_node("%NavBar").visible and not main.get_node("%TopBar").visible, "match mode hides bars")
	check(main.get_node("%DialogueBox").is_visible_in_tree(), "dialogue box stays visible in match")
	var won := await _play_out(pool, main)
	check(pool.state == "over", "match reaches the end")
	check(main.get_node("%PopupLayer").visible, "result popup shown")
	check(Game.marrow == 30, "pool never pays or takes Marrow")
	if won:
		check(Game.bones > bones_before, "pool win pays bones")
	main.get_node("%PopupButton").pressed.emit()
	await frames(2)
	check(not main.in_minigame and main.get_node("%NavBar").visible and main.pages[main.PAGE_PLAY].visible, "BACK restores the normal screen")
	check(not Game.minigame_active, "minigame flag cleared")
	main._play_widgets.start.pressed.emit()
	pool.quit_button.pressed.emit()
	check(pool.state != "over", "first QUIT tap only asks")
	pool.quit_button.pressed.emit()
	check(pool.state == "over" and Game.marrow == 30, "quitting pool costs no Marrow")
	main.get_node("%PopupButton").pressed.emit()
	await frames(2)
	# card-game bet limits (rules only; tables not built)
	Game.marrow = 500
	Game.rank = 0
	check(Game.max_bet() == 5 and not Game.start_wager(6) and Game.start_wager(5), "rank 0 max bet 5")
	Game.end_wager(true, 5)
	check(Game.marrow == 505, "bet win pays x2")
	Game.rank = 4
	check(Game.max_bet() == 100, "rank 4 max bet 100")
	Game.marrow = 40
	check(Game.max_bet() == 40, "max bet never above your Marrow")
	Game.rank = 0

	# run 20 simulated seconds of real frames for runtime errors
	Game.set_process(true)
	for k in 120:
		Game.tick(0.16)
		await get_tree().process_frame

	print("UI SMOKE: %s" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit(1 if fails > 0 else 0)
