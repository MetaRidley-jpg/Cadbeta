extends Node
## Hold'em real-time stress: plays through _process (timers, camera, quips) like a player,
## many seeds. Looks for stuck states, lost chips and slow frames.
## Run: godot --headless --path . res://tests/holdem_stress.tscn --quit-after 200000 -- --fresh
func _ready() -> void:
	Game.autosave_enabled = false
	Challenges.enabled = false
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.auto_open_challenges = false
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	var he := Holdem.new(3)
	for k in 20:
		he.strength([{"r": 1, "s": 0}, {"r": 13, "s": 1}], [{"r": 2, "s": 2}, {"r": 7, "s": 3}, {"r": 9, "s": 0}], 3, 140)
	print("strength(140 iters, 3 opp): %.1f ms" % ((Time.get_ticks_usec() - t0) / 20000.0))
	var seeds := int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 12
	var worst_frame := 0.0
	var problems := []
	for sd in range(int(OS.get_environment("SEED0")) if OS.get_environment("SEED0") != "" else 0, seeds):
		Game.marrow = 100
		Game.rank = 2
		Game.table_away = {}
		for i in Balance.BUILDINGS.size():
			Game.loyalty[i] = 0
		Game.loyalty[sd % 4] = 3
		Game.loyalty[(sd + 1) % 4 + 2] = 2
		if not main.start_holdem(100 + sd):
			problems.append("seed %d: did not open" % sd); continue
		var hp = main.holdem_page
		hp._set_buyin(10)
		hp.sit()
		hp.auto = true
		var hands := 0
		var last_state := ""
		var still := 0.0
		var sim_t := 0.0
		var it := 0
		while hands < 12 and sim_t < 600.0:
			var f0 := Time.get_ticks_usec()
			hp._process(1.0 / 30.0)
			main.holdem_page.table._process(1.0 / 30.0) if main.holdem_page.table.has_method("_process") else null
			var ms := (Time.get_ticks_usec() - f0) / 1000.0
			worst_frame = maxf(worst_frame, ms)
			sim_t += 1.0 / 30.0
			var sig: String = hp.state + hp._msg.text + str(hp._queue.size())
			if sig != last_state:
				last_state = sig; still = 0.0
			else:
				still += 1.0 / 30.0
			if hp.state == "result":
				hands += 1
				if hands >= 12:
					break
				hp.flags = {}
				hp.start_hand()
			elif hp.state == "busted":
				hands += 1
				if Game.marrow >= 3:
					hp._set_buyin(3); hp.sit()
				else:
					break
			elif hp.state == "closed":
				hands += 1
				break
			if still > 45.0:
				print("STUCK DUMP seed %d street %s cur_bet %d bets_made %d q_t %.2f queue %s" % [sd, hp.street, hp.cur_bet, hp.bets_made, hp._q_t, str(hp._queue.map(func(c): return str(c)))])
				for p in hp.players:
					print("   ", p.id, " stack=", p.stack, " bet=", p.bet, " contrib=", p.contrib, " acted=", p.acted, " folded=", p.folded, " allin=", p.allin, " last=", p.last, " hole=", p.hole.size())
				for k in 6:
					hp._process(1.0)
					print("   step ", k, ": state=", hp.state, " street=", hp.street, " q=", hp._queue.size(), " q_t=", hp._q_t, " msg=", hp._msg.text)
				problems.append("seed %d: stuck in '%s' for 45 s (queue %d, hand %d)" % [sd, hp.state, hp._queue.size(), hands])
				break
			it += 1
			if it % 60 == 0:
				await get_tree().process_frame
		if hp.state != "closed" and hp.state != "busted":
			hp.state = "result"
			hp.cash_out()
		print("seed %d: %d hands, end state %s, sim %.0f s" % [sd, hands, hp.state, sim_t])
		Game.table_away = {}
		await get_tree().process_frame
	print("worst logic frame: %.1f ms" % worst_frame)
	print("STRESS PROBLEMS: ", problems.size())
	for p in problems:
		print("  ", p)
	get_tree().quit()
