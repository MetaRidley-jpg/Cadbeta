extends Node
## Challenges wall rules + UI. Run: godot --headless --path . --quit-after 99999 res://tests/challenges_test.tscn -- --fresh

var fails := 0
var passes := 0

func check(c: bool, msg: String) -> void:
	if c:
		passes += 1
	else:
		fails += 1
		printerr("FAIL: ", msg)

func _ready() -> void:
	Game.autosave_enabled = false
	Challenges.enabled = false
	Challenges.reset_state()

	# ---- data ----
	check(Challenges.rows == 4 and Challenges.cols == 32, "wall is 4 x 32 = 128 windows")
	var golds := 0
	for id in Challenges.panels:
		var p: Dictionary = Challenges.panels[id]
		check(int(p.col) >= 0 and int(p.col) < 32 and int(p.row) >= 0 and int(p.row) < 4, "%s inside the wall" % id)
		if p.gold:
			golds += 1
			check(not p.has("reward"), "%s gold has no prize" % id)
		else:
			check(Challenges.rewards.has(p.reward), "%s prize exists" % id)
		check(String(p.text) != "", "%s has a condition text" % id)
	check(golds == 6, "6 gold windows (got %d)" % golds)
	for rid in Challenges.rewards:
		var r: Dictionary = Challenges.rewards[rid]
		match String(r.type):
			"art": check(ResourceLoader.exists(r.file), "art file %s" % r.file)
			"ship": check(ResourceLoader.exists("res://art/stacks/%s.png" % r.strip), "ship strip %s" % r.strip)
			"tint": check(Color.html_is_valid(String(r.color)), "tint color %s" % rid)
			"table": check(Color.html_is_valid(String(r.felt)) and Color.html_is_valid(String(r.rim)), "table colors %s" % rid)

	# ---- conditions ----
	check(Challenges.check().is_empty(), "fresh game breaks nothing")
	Game.total_bones = 1000.0
	var got := Challenges.check()
	check(got == ["c_first_k"], "1,000 total bones breaks c_first_k (got %s)" % [got])
	check(Challenges.owns("art_boneyard"), "art prize unlocked")
	check(Challenges.pending == ["c_first_k"], "broken window waits for its shatter")
	check(Challenges.take_pending() == "c_first_k" and Challenges.pending.is_empty(), "take_pending pops")
	check(Challenges.check().is_empty(), "no double break")

	# ---- hints: left and right only ----
	check(Challenges.is_hint(0, 1) and Challenges.is_hint(2, 1), "left + right neighbours are hints")
	check(not Challenges.is_hint(1, 0) and not Challenges.is_hint(1, 2), "up/down are not hints")
	check(not Challenges.is_hint(1, 1), "a broken window is not a hint")

	# ---- counters ----
	Challenges.enabled = true
	Challenges.bump("pool_wins")
	check(Challenges.done.has("c_pool_win") and Challenges.owns("table_midnight"), "pool win breaks c_pool_win")
	Challenges.bump("gifts", 2)
	check(not Challenges.done.has("c_gifts"), "2 gifts: not yet")
	Challenges.bump("gifts")
	check(Challenges.done.has("c_gifts"), "3 gifts breaks c_gifts")
	Challenges.enabled = false

	# ---- gold + Golden Bone ----
	check(Challenges.golden_bones == 0, "no bones yet")
	check(not Challenges.use_golden_bone(9, 1), "cannot use a bone you do not have")
	Game.rebury_count = 1
	Challenges.check()
	check(Challenges.done.has("g_fold") and Challenges.golden_bones == 1, "first Fold breaks gold window: +1 Golden Bone")
	check(Challenges.bone_block_reason(13, 2) != "", "gold windows cannot be boned")
	check(Challenges.bone_block_reason(0, 0) != "", "empty windows cannot be boned")
	check(Challenges.bone_block_reason(1, 1) != "", "broken windows cannot be boned")
	check(Challenges.use_golden_bone(17, 3), "bone breaks a far, blank window (c_df_score)")
	check(Challenges.done.get("c_df_score", "") == "bone" and Challenges.owns("ship_ghost"), "boned window pays its prize")
	check(Challenges.golden_bones == 0, "bone used up")

	# ---- cosmetics ----
	Challenges.set_ship("ship_crimson")
	check(Challenges.ship == "", "cannot fly a jet you do not own")
	Challenges.set_ship("ship_ghost")
	check(Challenges.ship_strip() == "jet_ghost", "alt jet selected")
	Challenges.set_table("table_midnight")
	check(Challenges.table_colors().felt == Color("1d2a5a"), "table skin selected")
	check(Challenges.tint_color().a == 0.0, "no tint = alpha 0")
	Game.costumes_owned = ["grave_casual", "hard_hat", "caveman"]
	Challenges.check()
	Challenges.set_tint("tint_bogiron")
	check(Challenges.tint_color() == Color("b0643a"), "tint selected")

	# ---- save round trip ----
	var d := Game.to_dict()
	var snap: Dictionary = JSON.parse_string(JSON.stringify(d))
	Challenges.reset_state()
	check(Challenges.done.is_empty(), "reset clears")
	Game.from_dict(snap)
	check(Challenges.done.has("c_df_score") and Challenges.done.c_df_score == "bone", "save keeps broken windows + how")
	check(Challenges.ship == "ship_ghost" and Challenges.table == "table_midnight" and Challenges.tint == "tint_bogiron", "save keeps cosmetics")
	check(Challenges.stats.gifts == 3, "save keeps counters")
	check(Challenges.pending.size() > 0, "save keeps windows still waiting to shatter")

	# ---- UI: open the wall, play every pending shatter, view art ----
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.auto_open_challenges = false
	await get_tree().process_frame
	await get_tree().process_frame
	main.open_challenges()
	check(main.challenges_open and main.challenges_page.visible and not main.get_node("%NavBar").visible, "wall opens full page")
	var page = main.challenges_page
	var t0 := Time.get_ticks_msec()
	while page.is_busy() and Time.get_ticks_msec() - t0 < 20000:
		page.wall._process(1.0 / 30.0)    # headless frames are tiny: push the animation
		await get_tree().process_frame
	check(Challenges.pending.is_empty() and not page.wall.is_shattering(), "all pending shatters played")
	check(page.wall.shown_broken(Vector2i(17, 3)), "boned window now shows open")
	page.wall.select(Vector2i(1, 1))
	page._refresh_info()
	check(page._action.visible and page._action.text == "VIEW ART", "art window offers VIEW ART")
	page._on_action()
	await get_tree().process_frame
	check(main.art_viewer.visible and main.art_viewer.tex != null, "art viewer opens")
	var z0: float = main.art_viewer.zoom
	main.art_viewer._zoom_at(Vector2(300, 600), z0 * 3.0)
	check(main.art_viewer.zoom > z0 * 2.5, "art viewer zooms")
	main.art_viewer.close()
	check(not main.art_viewer.visible, "art viewer closes")
	main.close_challenges()
	check(not main.challenges_open and main.get_node("%NavBar").visible, "BACK returns to the game")

	# dogfight uses the selected jet
	var p := DfPlane.new()
	p.kind = "player"
	check(p.sprites().frames.size() > 0, "alt jet bakes for the dogfight")

	print("CHALLENGES TESTS: %d passed, %d failed" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)
