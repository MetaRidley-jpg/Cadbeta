extends Node
## Pool tests: physics, rules, AI accuracy, and many full AI-vs-AI matches.
## Run: godot --headless --path . res://tests/pool_test.tscn -- --fresh

var fails := 0
var passes := 0
var MATCHES := 6
var foul_log := {}
var pot_tries := 0
var pot_made := 0

func check(c: bool, msg: String) -> void:
	if c:
		passes += 1
	else:
		fails += 1
		printerr("FAIL: ", msg)

func settle(sim: PoolSim, max_t := 30.0) -> float:
	var t := 0.0
	while sim.is_moving() and t < max_t:
		sim.step(1.0 / 60.0)
		t += 1.0 / 60.0
	return t

func clear_table(sim: PoolSim) -> void:
	for i in range(1, 16):
		sim.down[i] = true
	sim.shots_taken = 5   # not a break

func _ready() -> void:
	Game.autosave_enabled = false
	Challenges.enabled = false   # no auto-breaks while tests drive the game
	Game.set_process(false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--matches="):
			MATCHES = int(a.split("=")[1])
	var sim := PoolSim.new()

	# rack
	sim.rack(1)
	var ok_rack := true
	for i in 16:
		for j in range(i + 1, 16):
			if sim.pos[i].distance_to(sim.pos[j]) < 2.0 * PoolSim.R - 0.01:
				ok_rack = false
	check(ok_rack, "rack has no overlaps")
	check(sim.pos[8].distance_to(Vector2(PoolSim.W * 0.5, sim.pos[8].y)) < 0.01, "8 ball centered")

	# break spreads balls and everything stops
	sim.shoot(Vector2.UP, 1.0)
	var t := settle(sim)
	check(t < 25.0, "break settles (%.1fs)" % t)
	var bad := false
	for i in 16:
		if not sim.down[i]:
			var p: Vector2 = sim.pos[i]
			if is_nan(p.x) or p.x < -1 or p.x > PoolSim.W + 1 or p.y < -1 or p.y > PoolSim.H + 1:
				bad = true
	check(not bad, "no ball escapes the table after break")
	check(sim.first_hit != -1, "break hits the rack")

	# straight pot into top-left corner
	sim.rack(2)
	clear_table(sim)
	sim.down[3] = false
	sim.pos[3] = Vector2(150, 150)
	sim.pos[0] = Vector2(300, 300)
	sim.shoot(Vector2(-1, -1), 0.45)
	settle(sim)
	check(sim.down[3], "straight shot pots ball 3 in corner")
	check(sim.first_hit == 3, "first hit recorded")
	var j := sim.judge(PoolSim.Side.PLAYER, [3])
	check(j.keep_turn and not j.foul, "potting own ball keeps the turn")

	# side pocket
	sim.rack(3)
	clear_table(sim)
	sim.down[5] = false
	sim.pos[5] = Vector2(100, 500)
	sim.pos[0] = Vector2(300, 500)
	sim.shoot(Vector2.LEFT, 0.4)
	settle(sim)
	check(sim.down[5], "straight shot pots in side pocket")

	# cushion bounce: ball along rail midline does not vanish
	sim.rack(4)
	clear_table(sim)
	sim.pos[0] = Vector2(250, 700)
	sim.shoot(Vector2.RIGHT, 0.5)
	settle(sim)
	check(not sim.down[0] and sim.pos[0].x < PoolSim.W, "cue bounces off right cushion")

	# scratch rules
	sim.rack(5)
	clear_table(sim)
	sim.down[9] = false
	sim.pos[9] = Vector2(250, 400)
	sim.pos[0] = Vector2(60, 60)
	sim.shoot(Vector2(-1, -1), 0.5)
	settle(sim)
	j = sim.judge(PoolSim.Side.PLAYER, [1])
	check(j.foul and j.reason == "scratch" and not j.keep_turn, "scratch is a foul")
	sim.respot_cue()
	check(not sim.down[0], "cue respotted")

	# wrong ball first = foul
	sim.rack(6)
	clear_table(sim)
	sim.down[10] = false
	sim.down[2] = false
	sim.pos[10] = Vector2(250, 500)
	sim.pos[2] = Vector2(100, 200)
	sim.pos[0] = Vector2(250, 800)
	sim.shoot(Vector2.UP, 0.4)
	settle(sim)
	j = sim.judge(PoolSim.Side.PLAYER, [2])
	check(j.foul and j.reason == "wrong_ball", "hitting her ball first is a foul")

	# 8 ball early = loss, 8 ball when on it = win
	sim.rack(7)
	clear_table(sim)
	sim.down[8] = false
	sim.down[1] = false
	sim.pos[1] = Vector2(400, 900)
	sim.pos[8] = Vector2(150, 150)
	sim.pos[0] = Vector2(300, 300)
	sim.shoot(Vector2(-1, -1), 0.45)
	settle(sim)
	j = sim.judge(PoolSim.Side.PLAYER, [1])
	check(j.winner == PoolSim.Side.CADAVIRE and j.reason == "eight_loss", "early 8 = loss")
	sim.rack(8)
	clear_table(sim)
	sim.down[8] = false
	sim.pos[8] = Vector2(150, 150)
	sim.pos[0] = Vector2(300, 300)
	sim.shoot(Vector2(-1, -1), 0.45)
	settle(sim)
	j = sim.judge(PoolSim.Side.PLAYER, [8])
	check(j.winner == PoolSim.Side.PLAYER, "8 on the 8 = win")

	# AI with zero noise pots an easy ball
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var hits := 0
	for k in 20:
		sim.rack(100 + k)
		clear_table(sim)
		sim.down[12] = false
		sim.pos[12] = Vector2(rng.randf_range(80, 420), rng.randf_range(150, 600))
		sim.pos[0] = Vector2(rng.randf_range(80, 420), rng.randf_range(650, 900))
		sim.shots_taken = 1
		var shot := PoolAI.choose(sim, PoolSim.Side.CADAVIRE, {"aim_sigma": 0.0, "power_mult": 1.0}, rng)
		sim.shoot(shot.dir, shot.power)
		settle(sim)
		if sim.down[12] and not sim.down[0]:
			hits += 1
	check(hits >= 15, "perfect-aim AI pots most open shots (%d/20)" % hits)
	print("perfect AI open-shot rate: %d/20" % hits)

	# Full matches, AI vs AI, each profile
	for prof_name in ["normal", "precise", "SMASH"]:
		var prof: Dictionary = {"normal": {"aim_sigma": 0.9, "power_mult": 1.0}, "precise": {"aim_sigma": 0.45, "power_mult": 1.0},
			"SMASH": {"aim_sigma": 1.9, "power_mult": 1.45}}[prof_name]
		var results := {"p": 0, "c": 0, "stuck": 0}
		pot_tries = 0
		pot_made = 0
		var total_shots := 0
		var fouls := 0
		for m in MATCHES:
			var r := play_match(1000 + m, prof, rng)
			total_shots += r.shots
			fouls += r.fouls
			if r.winner == PoolSim.Side.PLAYER:
				results.p += 1
			elif r.winner == PoolSim.Side.CADAVIRE:
				results.c += 1
			else:
				results.stuck += 1
		print("%-8s pot rate %d%% (%d/%d)" % [prof_name, int(100.0 * pot_made / maxf(1, pot_tries)), pot_made, pot_tries])
		check(results.stuck == 0, "%s: every match ends (stuck %d)" % [prof_name, results.stuck])
		print("%-8s %d matches: breaker wins %d, other wins %d, avg shots %.1f, fouls/match %.1f" % [
			prof_name, MATCHES, results.p, results.c, total_shots / float(MATCHES), fouls / float(MATCHES)])

	print("foul reasons (reason/shot kind): ", foul_log)
	print("POOL TESTS: %d passed, %d failed" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)

## Both sides use the AI with the same profile. Returns {winner, shots, fouls}.
func play_match(seed_value: int, prof: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var sim := PoolSim.new()
	sim.rack(seed_value)
	var turn := PoolSim.Side.PLAYER
	var fouls := 0
	for shot_i in 300:
		var targets := sim.legal_targets(turn)
		var shot := PoolAI.choose(sim, turn, prof, rng)
		sim.shoot(shot.dir, shot.power)
		var t := settle(sim, 40.0)
		if t >= 40.0:
			return {"winner": -1, "shots": shot_i, "fouls": fouls}
		for i in 16:
			if not sim.down[i] and is_nan(sim.pos[i].x):
				return {"winner": -1, "shots": shot_i, "fouls": fouls}
		var j := sim.judge(turn, targets)
		if shot.kind == "pot":
			pot_tries += 1
			if sim.pocketed_this_shot.has(shot.target):
				pot_made += 1
		if j.foul:
			fouls += 1
			foul_log[j.reason + "/" + shot.kind] = foul_log.get(j.reason + "/" + shot.kind, 0) + 1
		if sim.down[0]:
			sim.respot_cue()
		if j.winner != -1:
			return {"winner": j.winner, "shots": shot_i + 1, "fouls": fouls}
		if not j.keep_turn:
			turn = PoolSim.Side.CADAVIRE if turn == PoolSim.Side.PLAYER else PoolSim.Side.PLAYER
	return {"winner": -1, "shots": 300, "fouls": fouls}
