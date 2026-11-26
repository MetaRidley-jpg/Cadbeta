extends Node
## Headless rule tests + a pacing bot.
## Run: godot --headless --path . res://tests/test_runner.tscn -- --fresh

var fails := 0
var passes := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
	else:
		fails += 1
		printerr("FAIL: ", msg)

func near(a: float, b: float, tol := 1e-6) -> bool:
	return absf(a - b) <= tol * maxf(1.0, maxf(absf(a), absf(b)))

func _ready() -> void:
	Game.autosave_enabled = false
	Challenges.enabled = false   # no auto-breaks while tests drive the game
	Game.set_process(false)          # we drive ticks by hand
	var said: Array = []
	Game.say.connect(func(c, p): said.append(c))

	# 1. fresh state
	Game.new_run(false)
	check(Game.owned[0] == 1 and Game.bones == 0.0, "fresh start: 1 broth, 0 bones")

	# 2. manual run
	Game.run(0)
	Game.tick(0.61)
	check(near(Game.bones, 1.0), "manual run pays 1 bone (got %s)" % Game.bones)
	check(not Game.running[0], "manual run stops after one cycle")

	# 3. buying math
	Game.bones = 10000.0
	var c1 := Game.cost_for(0, 1)
	check(near(c1, 4.0 * 1.07), "x1 cost = 4*1.07 (got %s)" % c1)
	Game.buy_mode_idx = 3
	var n := Game.max_affordable(0)
	check(Game.cost_for(0, n) <= Game.bones and Game.cost_for(0, n + 1) > Game.bones, "MAX affordable exact")
	var before_owned: int = Game.owned[0]
	Game.buy(0)
	check(Game.owned[0] == before_owned + n, "MAX buy adds n units")
	Game.buy_mode_idx = 0

	# 4. manager + income
	Game.bones = 1.0e6
	check(Game.hire_manager(0), "hire manager")
	Game.bones = 0.0
	var ips := Game.income_per_sec()
	for k in 100:
		Game.tick(0.1)
	check(absf(Game.bones - ips * 10.0) <= Game.revenue(0) + 1e-6, "manager income ~ ips*10 (%s vs %s)" % [Game.bones, ips * 10.0])

	# 5. speed milestone
	Game.new_run(false)
	var t0 := Game.cycle_time(0)
	Game.owned[0] = 25
	check(near(Game.cycle_time(0), t0 / 2.0), "25 owned halves cycle time")
	Game.owned[0] = 500
	check(Game.profit_steps(0) == 1, "500 owned = 1 profit step")

	# 6. fever
	Game.new_run(false)
	Game.add_fever(100.0)
	check(Game.fever_active, "fever starts at 100")
	check(near(Game.cost_mult(), Balance.FEVER_COST_MULT), "fever discount")
	check(Lines.resolve_key("idle") == "fever.idle", "fever uses fever.idle lines")
	for k in 1210:
		Game.tick(0.1)
	check(not Game.fever_active and Game.fever == 0.0, "fever ends after duration")
	# idle decay
	Game.fever = 50.0
	Game._idle_time = 999.0
	Game._taste_timer = 9999.0   # a random taste test adds fever; keep it out of this check
	Game.tick(10.0)
	check(Game.fever < 50.0, "fever decays while idle")
	Game._idle_time = 0.0
	var f0 := Game.fever
	Game.tick(1.0)
	check(Game.fever > f0, "fever rises while active")

	# 7. taste test
	Game.new_run(false)
	Game.owned[9] = 1
	Game.bones = 1.0e12
	var b0 := Game.bones
	said.clear()
	Game.do_taste_test(9)
	check(Game.bones < b0, "taste test eats bones")
	check(Game.buff_mult[9] >= 1.5, "high tier building gives good+ bone buff")
	check(said.size() > 0 and said[-1].begins_with("taste_"), "taste test speaks")
	Game._taste_timer = 9999.0
	for k in 70:
		Game.tick(1.0)
	check(Game.buff_mult[9] == 1.0, "taste buff expires")

	# 8. caveman costume
	Game.marrow = 1000
	check(Game.buy_costume("caveman"), "buy caveman")
	check(Game.costume == "caveman", "auto-wear after buy")
	Game.new_run(false)
	Game.do_taste_test(0)
	check(said[-1] == "taste_3", "caveman eats anything at max reaction")
	check(Lines.resolve_key("taste_3") == "caveman.taste_3", "caveman lines used")
	check(Lines.resolve_key("taste_0") == "taste_0", "fallback to base when no caveman key")
	var fv := Game.fever
	Game.add_fever(10.0)
	check(near(Game.fever - fv, 16.0), "caveman fever gain x1.6")
	check(not Game.buy_costume("regal_decay"), "regal locked by rank")
	Game.wear("grave_casual")

	# 9. items
	Game.new_run(false)
	Game.bones = 1.0e7
	check(Game.buy_item("knuckle_jar"), "buy item")
	var gm0 := Game.global_income_mult()
	check(Game.equip("knuckle_jar"), "equip item")
	check(near(Game.global_income_mult(), gm0 * 1.10), "equip +10% income")
	Game.fever = 0.0
	check(Game.gift("knuckle_jar"), "gift item")
	check(Game.equipped == "" and Game.item_count("knuckle_jar") == 0, "gift removes last copy + unequips")
	check(near(Game.fever, 18.0), "gift adds fever")
	check(Lines.resolve_key("gift.knuckle_jar") == "gift.knuckle_jar", "item-specific gift line")
	check(Lines.resolve_key("gift.unknown_thing") == "gift", "gift fallback")

	# 10. rank
	Game.new_run(false)
	Game.rank = 0
	for i in Balance.BUILDINGS.size():
		Game.owned[i] = 10
	Game.owned[0] = 9
	Game.bones = 1.0e30
	Game.buy(0)
	check(Game.rank == 1, "rank 1 at 10 of everything")
	Game.new_run(false)
	check(Game.rank == 1, "rank survives rebury")

	# 11. rebury
	Game.run_bones = 1.0e9
	var m0 := Game.marrow
	check(Game.rebury_gain() == 10, "rebury gain sqrt(1e9/1e7)=10")
	Game.rebury()
	check(Game.marrow == m0 + 10 and Game.bones == 0.0 and Game.owned[0] == 1, "rebury resets run, adds marrow")
	check(Game.costumes_owned.has("caveman"), "costumes persist")

	# 12. save round trip
	Game.bones = 12345.5
	Game.owned[3] = 7
	Game.managers[3] = true
	Game.inventory = {"dog_chew": 2}
	Game.equipped = "dog_chew"
	var txt := JSON.stringify(Game.to_dict())
	Game.new_run(false)
	Game.inventory = {}
	Game.from_dict(JSON.parse_string(txt))
	check(near(Game.bones, 12345.5) and Game.owned[3] == 7 and Game.managers[3], "save/load run state")
	check(Game.item_count("dog_chew") == 2 and Game.equipped == "dog_chew", "save/load items")
	check(typeof(Game.owned[3]) == TYPE_INT, "owned stays int after load")

	# 13. offline
	Game.pending_offline = Vector2.ZERO
	var rate := Game.offline_rate()
	var bb := Game.bones
	Game.grant_offline(3600.0)
	check(near(Game.bones - bb, rate * 3600.0), "offline earnings")
	check(Game.pending_offline.x > 0.0, "offline popup pending")

	# 14. every category the game emits has lines
	for cat in ["idle", "idle_away", "buy_new", "milestone", "manager", "taste_0", "taste_1",
			"taste_2", "taste_3", "fever_start", "fever_end", "costume_buy", "costume_wear",
			"equip", "gift", "rank_up", "rebury", "welcome_back"]:
		check(Lines.resolve_key(cat) != "", "lines exist for " + cat)
	for it in Balance.ITEMS:
		check(Lines.db.has("gift." + it.id), "gift line for " + it.id)

	# 14b. schemes + density
	Game.new_run(false)
	Game.owned[0] = 10
	var r0 := Game.revenue(0)
	Game.bones = 1.0e6
	check(Game.buy_scheme("broth_0"), "buy scheme")
	check(near(Game.revenue(0), r0 * 3.0), "scheme x3 building")
	check(not Game.buy_scheme("broth_0"), "scheme not buyable twice")
	var txt2 := JSON.stringify(Game.to_dict())
	Game.new_run(false)
	check(Game._scheme_count(0) == 0, "schemes reset on new run")
	Game.from_dict(JSON.parse_string(txt2))
	check(Game._scheme_count(0) == 1, "schemes load")
	# 14c. manager loyalty
	Game.new_run(false)
	Game.loyalty.fill(0)
	Game.scenes_seen.fill(0)
	var scenes: Array = []
	Game.manager_scene.connect(func(i, t): scenes.append([i, t]))
	Game.owned[2] = 10
	var r2 := Game.revenue(2)
	Game.bones = 1.0e9
	Game.hire_manager(2)
	check(Game.loyalty[2] == 1 and scenes[-1] == [2, 1], "first hire = tier 1 + scene 1")
	check(near(Game.revenue(2), r2), "tier 1 = x1")
	Game.run_bones = 1.0e9
	Game.rebury()
	check(Game.loyalty[2] == 2, "rebury promotes hired manager")
	check(Game.loyalty[3] == 0, "never-hired manager not promoted")
	Game.owned[2] = 10
	check(near(Game.revenue(2), r2 * 1.75), "tier 2 x1.75 works BEFORE rehire (permanent)")
	Game.bones = 1.0e9
	Game.hire_manager(2)
	check(scenes[-1] == [2, 2], "rehire plays scene 2")
	for k in 5:
		Game.run_bones = 1.0e9
		Game.rebury()
		Game.owned[2] = 1
		Game.bones = 1.0e9
		Game.hire_manager(2)
	check(Game.loyalty[2] == 5, "loyalty caps at 5")
	check(near(Game.loyalty_mult(2), 7.5), "tier 5 = x7.5")
	check(scenes[-1] == [2, 0], "after tier 5 scene: short rehire line")
	var txt3 := JSON.stringify(Game.to_dict())
	Game.loyalty.fill(0)
	Game.from_dict(JSON.parse_string(txt3))
	check(Game.loyalty[2] == 5 and Game.scenes_seen[2] == 5, "loyalty saves")
	Game.scene_active = true
	Game._taste_timer = 0.0
	var tb := Game.bones
	Game.tick(0.01)
	check(Game._taste_timer <= 0.0, "no taste tests during a scene")
	Game.scene_active = false

	# 14d. level meter
	Game.level_xp = 0.0
	check(Game.level() == 0, "level 0 at start")
	Game.add_bones(999.0)
	check(Game.level() == 9, "1000 bones = level 9 (3 per x10) got %d" % Game.level())
	var lx := Game.level_xp
	Game.run_bones = 1.0e9
	Game.rebury()
	check(near(Game.level_xp, lx), "level survives rebury")
	Game.endgame_reset_level()
	check(Game.level() == 0, "endgame reset clears level")

	# 14e. scene data is complete and valid
	var md = JSON.parse_string(FileAccess.get_file_as_string("res://data/manager_scenes.json"))
	for b in Balance.BUILDINGS:
		var e: Dictionary = md.get(b.id, {})
		check(e.get("tiers", []).size() == 5, "5 scenes for " + b.id)
		check(e.has("motive") and e.get("rehire", []).size() > 0, "motive + rehire for " + b.id)
		for tier_beats in e.get("tiers", []):
			var has_m := false
			for beat in tier_beats:
				check(beat[0] in ["m", "c", "p"] and String(beat[1]).length() > 0, "beat valid in " + b.id)
				has_m = has_m or beat[0] == "m"
			check(has_m, "manager speaks in each scene of " + b.id)
	check(Lines.resolve_key("scheme") != "", "scheme lines")

	# 15. number format
	check(Fmt.num(999.0) == "999", "fmt 999")
	check(Fmt.num(1234567.0) == "1.23 M", "fmt 1.23 M (got %s)" % Fmt.num(1234567.0))
	check(Fmt.num(12345.0) == "12,345", "fmt commas")
	check(Fmt.mult(1.75) == "1.75" and Fmt.mult(3.0) == "3" and Fmt.mult(7.5) == "7.5", "fmt mult")

	print("RULE TESTS: %d passed, %d failed" % [passes, fails])
	_pacing_bot()
	get_tree().quit(1 if fails > 0 else 0)

## Greedy bot: every 2s, buys the best affordable thing. Reports pacing.
func _pacing_bot() -> void:
	Game.new_run(false)
	Game.rank = 0
	Game.marrow = 0
	Game.marrow_earned = 0
	Game.loyalty.fill(0)
	Game.scenes_seen.fill(0)
	Game.wear("grave_casual")
	Game.buy_mode_idx = 0
	Game.rng.seed = 7
	var step := 0.25
	var t := 0.0
	var report_at := [60, 300, 600, 1200, 1800, 3600, 7200, 10800]
	var fevers := [0]
	Game.fever_mode_changed.connect(func(a): if a: fevers[0] += 1)
	var rank_times := {}
	Game.rank_changed.connect(func(r): rank_times[r] = int(t))
	while t < 10800.0:
		Game._idle_time = 0.0   # pretend the player is active
		for i in Balance.BUILDINGS.size():
			if Game.owned[i] > 0 and not Game.managers[i]:
				Game.run(i)
		Game.tick(step)
		t += step
		if int(t * 4) % 8 == 0:
			_bot_spend()
		if report_at.size() > 0 and t >= report_at[0]:
			report_at.pop_front()
			print("t=%5ds bones=%-10s ips=%-10s owned=%s mgr=%d rank=%d rebury=%d fevers=%d" % [
				int(t), Fmt.num(Game.bones), Fmt.num(Game.income_per_sec()), str(Game.owned),
				Game.managers.count(true), Game.rank, Game.rebury_gain(), fevers[0]])
	print("rank reached at seconds: ", rank_times)
	# Multi-run: 4 runs of 40 min, rebury between. Shows the loyalty speed-up.
	print("--- multi-run (40 min each, rebury between) ---")
	Game.new_run(false)
	Game.loyalty.fill(0)
	Game.scenes_seen.fill(0)
	for run_i in 5:
		var rt := 0.0
		while rt < 2400.0:
			Game._idle_time = 0.0
			for i in Balance.BUILDINGS.size():
				if Game.owned[i] > 0 and not Game.managers[i]:
					Game.run(i)
			Game.tick(step)
			rt += step
			if int(rt * 4) % 8 == 0:
				_bot_spend()
		print("run %d @40min: ips=%-10s bones=%-10s loyalty=%s marrow_gain=%d" % [run_i + 1, Fmt.num(Game.income_per_sec()), Fmt.num(Game.run_bones), str(Game.loyalty), Game.rebury_gain()])
		Game.rebury()

func _bot_spend() -> void:
	var ns := Game.next_scheme()
	while not ns.is_empty() and Game.bones >= Game.scheme_price(ns):
		Game.buy_scheme(ns.id)
		ns = Game.next_scheme()
	for _k in 50:
		var best := -1
		var best_score := 0.0
		var best_is_mgr := false
		for i in Balance.BUILDINGS.size():
			if Game.owned[i] > 0 and not Game.managers[i] and Game.bones >= Game.manager_cost(i):
				Game.hire_manager(i)
			var cost := Game.cost_for(i, 1)
			if cost > Game.bones:
				continue
			# value: added income per cost (+ unlock bonus)
			var b: Dictionary = Balance.BUILDINGS[i]
			var gain: float = b.revenue / Game.cycle_time(i)
			var score := gain / cost
			if Game.owned[i] == 0:
				score *= 4.0
			var nm := Game.next_milestone(i)
			if nm - Game.owned[i] <= 3:
				score *= 3.0
			if score > best_score:
				best_score = score
				best = i
		if best < 0:
			return
		Game.buy(best)
