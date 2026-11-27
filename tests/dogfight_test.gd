extends Node
## Dogfight tests: flight model, weapons, hazards, and full autopilot matches.
## Run: godot --headless --path . --quit-after 400000 res://tests/dogfight_test.tscn -- --fresh

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
	Challenges.enabled = false   # no auto-breaks while tests drive the game
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var df = main.get_node("%DogfightPage")
	df.set_process(false)

	# ---------------- flight model
	var p := DfPlane.new()
	p.setup("player", Vector3(0, 100, 0), 0.0)
	for k in 60:
		p.step(1.0 / 30.0)
	check(p.position.z < -50.0 and absf(p.position.x) < 1.0, "flies forward along -Z")
	p.drift = true
	p.turn = 1.0
	for k in 60:
		p.step(1.0 / 30.0)
	var slip := p.vel.normalized().angle_to(p.forward())
	check(p.speed < 110.0, "drift slows the jet below cruise (%.1f)" % p.speed)
	p.drift_time = 0.0      # no drift boost here: this checks the plain boost
	p.drift = false
	p.turn = 0.0
	p.boost = 50.0
	p.boost_in = true
	for k in 30:
		p.step(1.0 / 30.0)
	check(p.speed > 90.0 and p.boost < 50.0, "boost speeds up and drains the meter")
	print("drift slip angle seen: %.1f deg" % rad_to_deg(slip))

	# ---------------- sound effects load (placeholders from tools/make_sfx.py)
	var missing: Array = []
	for nm in ["gun", "enemy_gun", "laser_charge", "laser_fire", "explosion", "explosion_big", "boost_loop", "drift_boost", "roll", "dodge", "hoop", "hit", "bomb_drop", "warning", "card", "chips", "win", "lose", "tap", "buy", "crunch"]:
		if Sfx._stream(nm) == null:
			missing.append(nm)
	check(missing.is_empty(), "every sound effect loads (missing: %s)" % ", ".join(missing))
	check(ResourceLoader.exists(DfRender.BLAST_PATH), "explosion sheet exists")

	# ---------------- sky koi (slice 14): scenery above the clouds
	var kk := DfKoi.new()
	kk.build(5)
	var low := 9999.0
	for f in kk.fish:
		for kp in kk.spine(f, 10.0):
			low = minf(low, kp.y)
	check(kk.fish.size() == 6 and low > 335.0, "6 koi, all above the clouds (lowest %.0f m, clouds top out at 330)" % low)
	var sp0: PackedVector3Array = kk.spine(kk.fish[0], 0.0)
	var sp1: PackedVector3Array = kk.spine(kk.fish[0], 1.0)
	check(sp0[0].distance_to(sp1[0]) > 2.0 and sp0[0].distance_to(sp0[DfKoi.SEGS - 1]) > float(kk.fish[0].length) * 0.6, "koi swim (head moves) and are giant (body %.0f m)" % sp0[0].distance_to(sp0[DfKoi.SEGS - 1]))
	kk.step(1.0, "morning", [])   # calm: they keep swimming
	var kf0: Dictionary = kk.fish[0]
	var head0: Vector3 = kk.spine(kf0, 0.0)[0]
	kk.step(0.1, "morning", [{"pos": head0 + Vector3(80, -20, 0), "power": 2.6}])
	check(float(kf0.scare) > 0.5 and kf0.push_v.x < -50.0, "a laser blast next to a koi spooks it and pushes it away (scare %.2f)" % kf0.scare)
	var a0: float = kf0.ang
	kk.step(0.5, "morning", [])
	check(absf(float(kf0.ang) - a0) > float(kf0.speed) * 0.5 * 2.0, "a spooked koi swims much faster (%.3f rad in 0.5 s)" % absf(float(kf0.ang) - a0))
	for k in 40:
		kk.step(0.5, "storm", [])
	check(float(kk.fish[1].lift) > 150.0, "in the storm the koi climb away (lift %.0f m)" % kk.fish[1].lift)
	check(DfKoi.alpha_at(kf0, 3, 0.0) > 0.45 and DfKoi.alpha_at(kf0, 3, 0.0) < 0.9, "koi are semi-translucent")
	var cset := {}
	for i in DfKoi.SEGS:
		cset[DfKoi.color(kf0, i, 0.0).to_html()] = true
	check(cset.size() >= 2, "koi are multicolored (%d colors on one fish)" % cset.size())

	# ---------------- 360 flight (slice 13)
	var lp := DfPlane.new()
	lp.setup("player", Vector3(0, 300, 0), 0.0)
	lp.free = true
	lp.speed = 125.0
	var lf0 := lp.forward()
	var min_up := 1.0
	var max_fy := 0.0
	lp.pitch_in = 1.0
	var steps := int(TAU / DfPlane.FREE_PITCH_RATE * 30.0)
	for k in steps:
		lp.step(1.0 / 30.0)
		min_up = minf(min_up, lp.up().y)
		max_fy = maxf(max_fy, lp.forward().y)
	check(max_fy > 0.99 and min_up < -0.99, "full pull: straight up, then inverted (nose y %.2f, canopy y %.2f)" % [max_fy, min_up])
	check(lp.forward().dot(lf0) > 0.97 and lp.up().y > 0.97, "a full loop ends where it started (dot %.2f)" % lp.forward().dot(lf0))
	# half loop, let go: ASSIST rolls you upright (Immelmann)
	lp.basis = Basis.IDENTITY
	lp.pitch_in = 1.0
	for k in int(PI / DfPlane.FREE_PITCH_RATE * 30.0):
		lp.step(1.0 / 30.0)
	check(lp.up().y < -0.9, "top of the half loop: inverted (%.2f)" % lp.up().y)
	lp.pitch_in = 0.0
	for k in 75:
		lp.step(1.0 / 30.0)
	check(lp.up().y > 0.95 and absf(lp.forward().y) < 0.2, "ASSIST: let go inverted -> half roll upright, nose level (%.2f)" % lp.up().y)
	# ASSIST off: stays inverted
	lp.basis = Basis(Vector3(0, 0, -1), PI)
	lp.assist = false
	for k in 60:
		lp.step(1.0 / 30.0)
	check(lp.up().y < -0.95, "ASSIST off: inverted flight holds (%.2f)" % lp.up().y)
	# steering works upside down (the stick is in the jet's frame)
	var st := lp.steer_to(lp.position + Vector3(0, 100, -300))
	check(st.y < -0.3, "inverted: a target above you needs a push, not a pull (%.2f)" % st.y)
	lp.assist = true
	# barrel roll: one full turn, a sideways kick, then back to the same attitude
	lp.basis = Basis.IDENTITY
	lp.vel = lp.forward() * 125.0
	lp.roll_in = 1
	lp.step(1.0 / 30.0)
	check(lp.rolling() and lp.vel.x > 30.0, "barrel roll starts with a sideways kick (vx %.0f)" % lp.vel.x)
	var min_up_r := 1.0
	for k in 20:
		lp.step(1.0 / 30.0)
		min_up_r = minf(min_up_r, lp.up().y)
	check(not lp.rolling() and min_up_r < -0.9 and lp.up().y > 0.97, "the roll turns all the way over and ends level (%.2f)" % lp.up().y)
	lp.roll_in = 1
	lp.step(1.0 / 30.0)
	check(not lp.rolling(), "roll has a cooldown")
	# old code that writes yaw / pitch still works
	lp.yaw = 1.0
	lp.pitch = 0.3
	check(absf(lp.yaw - 1.0) < 0.001 and absf(lp.pitch - 0.3) < 0.001 and absf(lp.up().dot(lp.forward().cross(Vector3.UP).normalized())) < 0.001, "yaw/pitch setters give a level jet")

	# ---------------- T's jet: 3 boost stages (boost 1, boost 2, top speed)
	var q := DfPlane.new()
	q.setup("player", Vector3(0, 100, 0), 0.0)
	q.boost = 100.0
	q.boost_in = true
	var seen := {}
	var speeds := {}
	for k in 120:
		q.step(1.0 / 30.0)
		q.boost = 100.0
		seen[q.boost_stage()] = true
		speeds[q.boost_stage()] = q.speed
	check(seen.has(1) and seen.has(2) and seen.has(3), "holding BOOST walks through stages 1, 2, 3")
	check(speeds[3] > speeds[1] + 30.0, "top speed is faster than boost 1 (%.0f vs %.0f)" % [speeds[3], speeds[1]])
	q.boost_in = false
	q.step(1.0 / 30.0)
	check(q.boost_stage() == 0 and q.boost_time == 0.0, "letting go resets the stage")
	# drift boost: drift long enough, let go -> top speed for a moment + some meter back
	var dq := DfPlane.new()
	dq.setup("player", Vector3(0, 100, 0), 0.0)
	dq.boost = 30.0
	dq.drift = true
	dq.turn = 1.0
	for k in 15:     # 0.5 s: too short
		dq.step(1.0 / 30.0)
	dq.drift = false
	dq.step(1.0 / 30.0)
	check(dq.drift_boost_t == 0.0 and dq.boost == 30.0, "a short drift gives no drift boost")
	dq.drift = true
	for k in 40:     # 1.33 s: tier 1
		dq.step(1.0 / 30.0)
	check(dq.drift_tier() == 1, "1.1 s of drift charges tier 1")
	dq.drift = false
	dq.turn = 0.0
	dq.step(1.0 / 30.0)
	check(dq.drift_boost_t > 0.8 and dq.boost_stage() == 3, "letting go fires a top-speed drift boost")
	check(is_equal_approx(dq.boost, 42.0), "drift boost gives 12 boost back (%.1f)" % dq.boost)
	for k in 10:
		dq.step(1.0 / 30.0)
	check(dq.speed > 230.0, "the jet snaps to top speed (%.0f)" % dq.speed)
	dq.drift = true
	for k in 70:     # 2.33 s: tier 2
		dq.step(1.0 / 30.0)
	check(dq.drift_tier() == 2, "2.2 s of drift charges tier 2")
	dq.drift = false
	dq.step(1.0 / 30.0)
	check(dq.drift_boost_t > 1.3, "tier 2 drift boost lasts longer")
	# visor mask: T's visor pixels are baked with the marker alpha
	var vimg: Image = q.sprites().atlas.get_image()
	var vis := 0
	for y in range(0, vimg.get_height(), 1):
		for x in range(0, vimg.get_width(), 2):
			var a := vimg.get_pixel(x, y).a
			if a > 0.975 and a < 0.99:
				vis += 1
	check(vis > 100, "cyclops visor pixels marked for the red shimmer (%d)" % vis)

	# ---------------- start a real match
	main.start_dogfight(11)
	check(main.in_minigame and df.visible and Game.minigame_active, "dogfight starts in match mode")
	check(main.get_node("%DialogueBox").is_visible_in_tree(), "dialogue slot stays visible")
	var w: DfWorld = df.world
	check(w.ground_y(w.volcano.pos) > 100.0, "volcano cone is tall (%.0f)" % w.ground_y(w.volcano.pos))
	check(w.ground_y(Vector3(0, 0, 1100)) == 0.0, "open ocean is at 0")
	check(w.band_at(w.islands[0].pos) >= 3, "main island center is grass or rock")
	check(w.palms.size() > 60, "islands have palm trees (%d)" % w.palms.size())
	var spr: DfSprites = df.player.sprites()
	check(spr.frames.size() == 32 * 8, "jet baked to 32 headings x 8 heights (%d frames)" % spr.frames.size())
	var f0: Dictionary = spr.frame_for(0.0, deg_to_rad(18.0))
	check((f0.rect as Rect2).size.x >= 18.0, "rear view frame is wide enough (%s)" % str((f0.rect as Rect2).size))
	check(DfRender.spr.has("volcano") and DfRender.spr.has("palm"), "scenery sprites baked")
	df._update_camera(0.0)

	# ---------------- lock-on + big laser
	df.set_process(false)
	var tgt: DfPlane = DfPlane.new()
	tgt.setup("fighter", df.player.position + df.player.forward() * 300.0 + Vector3.UP * 5.0, df.player.yaw)
	df.enemies.append(tgt)
	df.laser_charge = 0.0
	df._laser_step(0.1)
	check(not df.laser_ready() and df.laser_target != null, "laser locks a target ahead but is not charged yet")
	df.laser_charge = 1.0
	df.controls.laser_queued = true
	df._laser_step(0.0)
	check(df.lasers.size() == 1 and df.laser_charge == 0.0, "LASER fires when charged + locked, charge resets")
	var mid: Vector3 = df.laser_point(df.lasers[0], 0.5)
	var straight: Vector3 = (df.player.position + tgt.position) * 0.5
	check(mid.distance_to(straight) > 10.0, "laser path bends (homing curve)")
	for k in 20:
		df._laser_step(1.0 / 30.0)
	check(not tgt.alive, "laser kills the locked jet")
	check(df.laser_point({"end": tgt.position, "curl": 0.3}, 1.0).distance_to(tgt.position) < 0.01, "beam ends on the target")
	df.enemies.erase(tgt)
	for k in 30:
		df._laser_step(1.0 / 30.0)
	check(df.lasers.is_empty(), "beam fades out")
	var ahead: Vector3 = df.render.project(df.player.position + df.player.forward() * 60.0 + Vector3.UP * 3.0)
	check(ahead.z > 0.0 and absf(ahead.x - df.render.anchor.x) < 2.0, "chase cam looks along the jet")
	# 360 renderer: a level jet's frame turn matches the old horizon roll; inverted camera
	var rr = df.render
	rr.set_camera_frame(Vector3(0, 100, 50), Vector3(0, 100, 0), Vector3(0.3, 1, 0).normalized())
	var lvl := Basis.from_euler(Vector3(0, 0.7, 0))
	var vv: Vector3 = (lvl.inverse() * (rr.cam_pos - Vector3(0, 100, 0))).normalized()
	check(absf(wrapf(rr._frame_turn(lvl, vv) - rr._screen_roll, -PI, PI)) < 0.02, "level jet: sprite turn = horizon roll")
	var inv := lvl * Basis(Vector3(0, 0, -1), PI)
	check(absf(absf(wrapf(rr._frame_turn(inv, vv) - rr._frame_turn(lvl, vv), -PI, PI)) - PI) < 0.05, "inverted jet: sprite turned 180 deg")
	rr.set_camera_frame(Vector3(0, 100, 50), Vector3(0, 100, 0), Vector3.DOWN)
	check(rr.cam_up.y < -0.99 and rr.project(Vector3(0, 120, 0)).y > rr.anchor.y, "camera upside down: things above you are low on screen")
	rr.set_camera_frame(Vector3(0, 100, 0), Vector3(0, 300, -0.0001), Vector3(0, 0, -1))
	check(rr.cam_fwd.y > 0.99 and is_finite(rr.cam_right.x), "camera straight up stays valid")
	# ring courses (slice 16n): bigger, moving, in order, 4 variations
	check(w.hoops.is_empty(), "the old static hoops are gone")
	var rc := DfRings.new()
	rc.setup(func(pp: Vector3) -> float: return w.ground_y(pp), 5)
	var ring_kinds := {}
	for rkind in DfRings.KINDS:
		rc.spawn(Vector3(0, 100, 0), Vector3.FORWARD, rkind)
		ring_kinds[rc.kind] = true
		var rp0: Vector3 = rc.rings[1].pos
		rc.tick(1.0, Vector3(0, 100, 0), Vector3.FORWARD)
		check(rc.rings[1].pos.distance_to(rp0) > 3.0, "%s rings move on their path (%.1f m in 1 s)" % [rkind, rc.rings[1].pos.distance_to(rp0)])
		var lowc := INF
		for rr2 in rc.rings:
			lowc = minf(lowc, rr2.pos.y - w.ground_y(rr2.pos))
		check(lowc > 15.0, "%s rings stay above the ground (%.0f m)" % [rkind, lowc])
	check(ring_kinds.size() == 4, "4 ring course variations")
	check(DfRings.RING_RADIUS > w.HOOP_RADIUS * 1.5, "rings are bigger than the old hoops")
	rc.spawn(Vector3(0, 100, 0), Vector3.FORWARD, "slalom")
	var rg1: Dictionary = rc.rings[1]
	check(not rc.crossed(rg1.pos - rg1.normal * 5.0, rg1.pos + rg1.normal * 5.0), "ring 2 does not count before ring 1")
	var rdone := false
	for i in DfRings.RINGS:
		var rgi: Dictionary = rc.rings[i]
		var rok := rc.crossed(rgi.pos - rgi.normal * 5.0, rgi.pos + rgi.normal * 5.0)
		check(rok, "ring %d in order is detected" % (i + 1))
		rdone = rc.pass_ring()
	check(rdone and rc.completed == 1 and rc.last_event == "done", "all rings = course done")
	rc.spawn(Vector3(0, 100, 0), Vector3.FORWARD, "loop")
	var rg0: Dictionary = rc.rings[0]
	check(not rc.crossed(rg0.pos - rg0.normal * 5.0 + Vector3.UP * 60.0, rg0.pos + rg0.normal * 5.0 + Vector3.UP * 60.0), "missing the ring is not a pass")
	rc.pass_ring()
	for k in 26:
		rc.tick(1.0, Vector3(0, 100, 0), Vector3.FORWARD)
	check(rc.next == 0 and not rc.rings[0].passed, "out of time: the course resets")

	# run the intro and wave 1 start
	for k in 100:
		df.sim_step(1.0 / 30.0)
	check(df.state == "wave" and df.wave == 1 and df.enemies.size() == 3, "wave 1 spawns 3 fighters")

	# ---------------- KO replay (slice 15)
	var live_player: DfPlane = df.player
	var live_enemies: Array = df.enemies
	var n_live: int = df.enemies.size()
	for k in 60:
		df.sim_step(1.0 / 30.0)
	check(df.replay.frames.size() >= 60, "the replay buffer records every step (%d frames)" % df.replay.frames.size())
	df._ko = {"kind": "wave", "t": df.sim_time - 0.6, "pos": df.player.position + df.player.forward() * 200.0, "victim": 0}
	var back_state: String = df.state
	df._begin_replay()
	check(df.state == "replay" and not df.hud.visible, "KO: the game freezes into the replay, HUD hidden")
	# every shot in the library frames the target from a sane distance (16g)
	var shots_ok := true
	var shot_log := ""
	for sk in ["side", "overhead", "into_frame", "front", "chase", "orbit", "low"]:
		df.replay._plan = [[sk, 10.0], [sk, 10.0], [sk, 10.0]]
		df.replay._fixed.clear()
		var sc: Array = df.replay.camera(df)
		var sv: Vector3 = df.replay.victim_pos(df)
		var sdist: float = (sc[0] as Vector3).distance_to(sv)
		shot_log += "%s %.0fm " % [sk, sdist]
		if not is_finite(sdist) or sdist < 40.0 or sdist > 450.0 or (sc[0] as Vector3).distance_to(sc[1]) < 1.0:
			shots_ok = false
	check(shots_ok, "every replay shot frames the target at a readable distance (%s)" % shot_log)
	df.replay._plan = []
	var ok_steps := 0
	var moved := false
	var p_start := Vector3.INF
	while df.replay.step(df, 1.0 / 30.0) and ok_steps < 600:
		if p_start == Vector3.INF:
			p_start = df.player.position
		var cam: Array = df.replay.camera(df)
		if not (cam[0] is Vector3 and is_finite(cam[0].x)):
			break
		ok_steps += 1
	moved = df.player.position.distance_to(p_start) > 1.0
	check(ok_steps > 60 and moved, "the replay plays the recorded jets back (%d frames)" % ok_steps)
	check(df.player != live_player, "during the replay the renderer draws ghost jets")
	df._letterbox(1.0)
	check(df._lb >= 1.0 and df._lb_label.visible, "letterbox bars + REPLAY tag are in during the replay")
	df._end_replay()
	check(df.state == back_state and df.player == live_player and df.enemies == live_enemies and df.enemies.size() == n_live and df.hud.visible, "after the replay the live match comes back exactly")
	df._letterbox(1.0)
	check(df._lb <= 0.0 and not df._lb_label.visible, "the bars go away again")
	Game.df_replays = false
	check(not df._ko_ready(), "KO REPLAY: OFF turns it off")
	Game.df_replays = true

	# ---------------- QUAD GUNSHIP boss (slice 16)
	check(df.wave_def(6).get("boss", false), "wave 6 is the boss wave")
	var bn0: int = df.enemies.size()
	df._spawn_boss()
	var bg: DfPlane = df.boss
	check(bg != null and bg.kind == "boss" and bg.hp == 1400.0 and df.enemies.size() == bn0 + 1, "the gunship spawns with 1400 hull")
	check(bg.sprites() != null, "the gunship art bakes")
	var bpos0: Vector3 = bg.position
	for k in 30:
		df._boss_step(bg, 1.0 / 30.0)
	check(bg.alive and bg.position.distance_to(bpos0) < 60.0 and absf(bg.position.y - df.BOSS_ALT) < 30.0, "it hovers near its orbit, not flying off like a jet")
	# beam test: 400 m in front of the boss, under it; lock lag = aim 1/3 s behind you
	var bphp: float = df.player.hp
	var bres := {}
	for spd in [125.0, 220.0, 255.0]:
		df.player.alive = true
		df.player.hp = 100.0
		df.state = "wave"
		var bm: Vector3 = df.boss_muzzle()
		var side := (bg.basis.x).normalized()
		df.player.position = bm + (-bg.basis.z) * 400.0 + Vector3.DOWN * 60.0
		df.player.vel = side * spd
		df.boss_st.phase = "fire"
		df.boss_st.charge = 1.0
		df.boss_st.t = 0.0
		df.boss_st.parts = []
		df.boss_st.beam_t = 0.0
		df.boss_st.min_d = INF
		df.boss_st.near = false
		df.boss_st.hit = false
		var lk: float = df.boss_muzzle().distance_to(df.player.position) / df.BOSS_BEAM_SPEED
		df.boss_st.aim = df.player.position + df.player.vel * lk - df.player.vel / df.BOSS_LOCK_FOLLOW   # the lock leads you, lagging 1/8 s
		for k in 60:                    # the full 2 s shot
			df.player.position += df.player.vel / 30.0
			df._boss_step(bg, 1.0 / 30.0)
		bres[spd] = [df.boss_st.hit, df.player.hp]
	check(bres[125.0][0] and bres[125.0][1] < 100.0, "the beam catches a cruising jet in a turn (hp %.0f)" % bres[125.0][1])
	check(bres[220.0][0], "boost stage 2 (220 m/s) is NOT enough: the beam tracks at %.0f" % df.BOSS_TRACK)
	# the 255 run swept the beam after a jet crossing it: the beam must be BENT, not a rod
	var bpts: PackedVector3Array = df.boss_beam_pts()
	var bend := 0.0
	if bpts.size() > 2:
		var c0 := bpts[0]
		var c1 := bpts[bpts.size() - 1]
		for bq in bpts:
			var bu := clampf((bq - c0).dot(c1 - c0) / (c1 - c0).length_squared(), 0.0, 1.0)
			bend = maxf(bend, bq.distance_to(c0 + (c1 - c0) * bu))
	check(bpts.size() > 5 and bend > 8.0, "a sweeping beam bends like a hose (%d points, bows %.0f m)" % [bpts.size(), bend])
	check(not bres[255.0][0] and bres[255.0][1] == 100.0, "top speed / drift boost across the beam dodges it")
	df.player.hp = 100.0
	df.player.roll_t = 0.3
	df.player.position = df.boss_muzzle() + (-bg.basis.z) * 300.0
	df.player.vel = Vector3.ZERO
	df.boss_st.aim = df.player.position
	df.boss_st.phase = "fire"
	df.boss_st.t = 0.0
	df.boss_st.parts = []
	df.boss_st.beam_t = 0.0
	for k in 8:                         # the light needs ~0.14 s to fly 300 m
		df.player.roll_t = 0.3
		df._boss_step(bg, 1.0 / 30.0)
	check(df.player.hp < 100.0, "a barrel roll does NOT dodge the beam")
	df.player.roll_t = 0.0
	check(not bg.damage(df.LASER_BOSS_DMG) and absf(bg.hp - (1400.0 - df.LASER_BOSS_DMG)) < 0.1, "your super laser takes a chunk, not an instant kill")
	check(absf(df.boss_lock_at() * df.BOSS_CHARGE - (df.BOSS_CHARGE - df.BOSS_WARN)) < 0.01, "the lock comes 2.8 s before the shot (react + a full tier-2 drift)")
	# rotors are weak spots; 2 down = phase 2 (faster cannon, same 2.4 s warning)
	bg.hp = 1400.0
	var rhp0: float = bg.hp
	df._boss_bullet(bg, df.boss_hub(0), 10.0)
	check(df.boss_st.rotors[0] == df.ROTOR_HP - 20.0 and absf(bg.hp - (rhp0 - 15.0)) < 0.01, "a bolt on a rotor: x2 to the rotor, x1.5 to the hull")
	var rhp1: float = bg.hp
	df._boss_bullet(bg, df.boss.hit_center(), 10.0)
	check(df.boss_st.rotors[0] == df.ROTOR_HP - 20.0 and absf(bg.hp - (rhp1 - 10.0)) < 0.01, "a bolt on the armour: x1, no rotor damage")
	df.boss_st.rotors[0] = 5.0
	df._boss_bullet(bg, df.boss_hub(0), 10.0)
	check(df.boss_rotors_down() == 1 and not df.boss_st.phase2 and bg.hp < rhp1 - 150.0, "ROTOR DOWN: the rotor is gone and the hull loses 150")
	df.boss_st.rotors[3] = 5.0
	df._boss_bullet(bg, df.boss_hub(3), 10.0)
	check(df.boss_st.phase2 and df.boss_charge_time() == df.BOSS_CHARGE2, "2 rotors down = PHASE 2, faster cannon")
	check(absf((1.0 - df.boss_lock_at()) * df.BOSS_CHARGE2 - df.BOSS_WARN) < 0.01, "phase 2 still warns 2.8 s before the shot")
	df.player.position = df.boss_hub(1) + (df.boss_hub(1) - bg.position).normalized() * 300.0
	df.player.basis = Basis.looking_at(df.boss_hub(1) - df.player.position, Vector3.UP)
	var gt = df._gun_target()
	check(gt != null and (gt.pos as Vector3).distance_to(df.boss_hub(1)) < 0.1, "nose near a live rotor: the guns aim at that rotor")
	# beam KO goes into the replay with the gunship and its beam
	df._ko_by = "beam"
	df.replay.record(df)
	var last: Dictionary = df.replay.frames[df.replay.frames.size() - 1]
	check(int(last.boss_id) == bg.get_instance_id() and String(last.boss_st.phase) != "", "the replay records the gunship and its cannon state")
	df._ko_by = ""
	var bscore: float = df.score
	var bdeb: int = df.debris.size()
	bg.damage(99999.0)
	df._kill_enemy(bg, "player")
	check(df.boss == null and df.score >= bscore + 2500.0 and df.debris.size() > bdeb, "BOSS DOWN: score, wreckage, boss cleared")
	df.enemies.erase(bg)
	df.debris.clear()
	df.player.hp = bphp
	df.player.alive = true
	df.state = "wave"

	# lights pierce fog (T 2026-11-26): solid things fade out at fog_end, lights do not
	var rnd = df.render
	check(rnd.light_end >= rnd.fog_end * 2.9, "lights reach ~3x past the fog (fog %.0f m, lights %.0f m)" % [rnd.fog_end, rnd.light_end])
	check(rnd._fade(rnd.fog_end * 1.5) == 0.0 and rnd._light_fade(rnd.fog_end * 1.5) > 0.95, "past the fog: a jet is gone, an explosion still burns at full strength")

	# replay clouds (T 2026-11-26): see-through, nearly clear where they cover the action
	rnd._rp_pts = [[Vector2(100, 100), 500.0]]
	var ca_over: float = rnd._replay_cloud_alpha(Vector2(100, 100), 200.0, Vector2(80, 50))
	var ca_side: float = rnd._replay_cloud_alpha(Vector2(400, 100), 200.0, Vector2(80, 50))
	var ca_back: float = rnd._replay_cloud_alpha(Vector2(100, 100), 800.0, Vector2(80, 50))
	check(ca_over < 0.15 and ca_side > 0.4 and ca_side < 0.5 and ca_back <= 0.6, "replay clouds: clear over the action %.2f, translucent %.2f, behind %.2f" % [ca_over, ca_side, ca_back])
	# replay: a sea stack in front of the KO is ghosted; one off to the side stays solid
	var st_was: String = df.state
	df.state = "replay"
	rnd.set_camera_frame(Vector3(0, 50, 0), Vector3(0, 50, -100), Vector3.UP, 60.0)
	var fc: Vector3 = rnd.project(Vector3(0, 50, -600))
	rnd._rp_pts = [[Vector2(fc.x, fc.y), fc.z]]
	var oa_front: float = rnd._replay_occluder_alpha(Vector3(0, 0, -300), 100.0, 50.0)
	var oa_side: float = rnd._replay_occluder_alpha(Vector3(400, 0, -300), 100.0, 50.0)
	var oa_behind: float = rnd._replay_occluder_alpha(Vector3(0, 0, -900), 100.0, 50.0)
	check(oa_front <= 0.31 and oa_side == 1.0 and oa_behind == 1.0, "replay: a stack in front of the KO ghosts (%.2f), others stay solid (%.2f, %.2f)" % [oa_front, oa_side, oa_behind])
	df.state = st_was
	rnd._rp_pts = []

	# replay shot library (16g): 3 random shots, no repeat back to back, framed so the jet is 8-12 px
	var rp2 := DfReplay.new()
	var plan_ok := true
	for k in 20:
		rp2._make_plan()
		var pl: Array = rp2._plan
		if pl.size() != 3 or pl[0][0] == pl[1][0] or pl[1][0] == pl[2][0] or not (pl[2][0] in DfReplay.SHOTS_KO):
			plan_ok = false
		var pxs: float = pl[0][1]
		var dd: float = rp2._dist_for(df, pxs, 60.0)
		var got: float = ((df.render.view_size.x * 0.5) / tan(deg_to_rad(60.0) * 0.5)) / dd * DfReplay.JET_M
		if absf(got - pxs) > 0.01 or pxs < 8.0 or pxs > 12.0:
			plan_ok = false
	check(plan_ok, "replay plans: 3 random shots, no back-to-back repeat, the jet framed at 8-12 px")
	# replay director (16h): events + more planes in frame score more, repeats cost points,
	# the plan stays within the budget. A hand-made 2 s recording: the victim flies past the
	# island with a wingman beside it; you are far behind.
	var rd := DfReplay.new()
	var vpos := Vector3(0, 120, -150)
	var mk_frames := func(with_wing: bool, with_blast: bool) -> Array:
		var fr: Array = []
		for k in 21:
			var tt := k * 0.1
			var vp: Vector3 = vpos + Vector3(-60.0 + 60.0 * tt, 0, 0)
			var en: Array = [{"id": 101, "st": {"position": vp, "basis": Basis.from_euler(Vector3(0, -PI / 2, 0)), "alive": true, "kind": "fighter"}}]
			if with_wing:
				en.append({"id": 102, "st": {"position": vp + Vector3(0, 6, 25), "basis": Basis.IDENTITY, "alive": true, "kind": "fighter"}})
			var bl: Array = []
			if with_blast:
				bl.append({"pos": vp + Vector3(10, 0, 0), "t": 0.3, "life": 1.0, "size": 2.0, "kind": "fire"})
			fr.append({"t": tt, "player": {"id": 1, "st": {"position": vp + Vector3(-900, 0, 0), "basis": Basis.IDENTITY, "alive": true, "kind": "player"}},
				"enemies": en, "blasts": bl, "lasers": [], "projectiles": [], "boss_st": {}})
		return fr
	rd.ko = {"kind": "wave", "t": 2.0, "pos": vpos + Vector3(60, 0, 0), "victim": 101}
	rd.frames = mk_frames.call(false, false)
	var s_alone: float = rd.score_shot(df, "side", 9.0, 1)
	rd.frames = mk_frames.call(true, false)
	var s_pair: float = rd.score_shot(df, "side", 9.0, 1)
	rd.frames = mk_frames.call(true, true)
	var s_blast: float = rd.score_shot(df, "side", 9.0, 1)
	check(s_pair > s_alone and s_blast > s_pair, "director: a 2nd plane in frame scores more (%.0f > %.0f), a blast more again (%.0f)" % [s_pair, s_alone, s_blast])
	DfReplay.history = []
	var h0: float = rd._history_penalty("side")
	DfReplay.history = ["side", "side", "front"]
	check(h0 == 0.0 and rd._history_penalty("side") > rd._history_penalty("front") and rd._history_penalty("front") > 0.0, "director: recently used shots lose points (side %.0f, front %.0f)" % [rd._history_penalty("side"), rd._history_penalty("front")])
	DfReplay.history = []
	var budget_ok := true
	var kinds_seen := {}
	for k in 12:
		rd._make_plan_scored(df)
		var pl2: Array = rd._plan
		var cost: int = DfReplay.SHOT_COST[pl2[0][0]] + DfReplay.SHOT_COST[pl2[1][0]] + DfReplay.SHOT_COST[pl2[2][0]]
		if pl2.size() != 3 or cost > DfReplay.BUDGET or not (pl2[2][0] in DfReplay.SHOTS_KO):
			budget_ok = false
		for pq in pl2:
			kinds_seen[pq[0]] = true
	check(budget_ok, "director: every plan stays within the budget (%d)" % DfReplay.BUDGET)
	check(kinds_seen.size() >= 4, "director: the history penalty rotates shots over 12 replays (%d kinds used)" % kinds_seen.size())
	DfReplay.history = []

	# weather ambient (16g): every preset has one; storm and night are darker than morning
	var amb_ok := true
	for pn in DfWeather.PRESETS:
		if not DfWeather.PRESETS[pn].has("ambient"):
			amb_ok = false
	var lum := func(c: Color) -> float: return (c.r + c.g + c.b) / 3.0
	check(amb_ok and lum.call(DfWeather.PRESETS.night.ambient) < 0.65 and lum.call(DfWeather.PRESETS.storm.ambient) < 0.65 and lum.call(DfWeather.PRESETS.morning.ambient) > 0.99, "weather ambient: beach colors dim in storm / at night")

	# barrel roll dodges a bolt; contrails follow the jets
	var php0: float = df.player.hp
	df.player.roll_t = 0.3
	df._hit_player(20.0)
	check(df.player.hp == php0, "barrel roll: the bolt misses")
	df._hit_player(5.0, false)
	check(df.player.hp < php0, "lava / asteroid still hurt during a roll")
	df.player.hp = php0
	df.player.roll_t = 0.0
	for k in 10:
		df.render._step_trails(1.0 / 30.0)
	check(df.render.trails.has(df.player.get_instance_id()) and df.render.trails[df.player.get_instance_id()].size() == 10, "contrails: the player leaves a trail")
	check(df.render.trails.size() >= 4, "every jet has a trail (%d)" % df.render.trails.size())

	# bullet kills an enemy
	var e: DfPlane = df.enemies[0]
	e.position = df.player.position + df.player.forward() * 80.0
	e.hp = 4.0
	df.projectiles.append({"p": df.player.position + df.player.forward() * 70.0, "v": df.player.forward() * 600.0, "life": 1.0, "kind": "bullet", "dmg": 5.0})
	var kills0: int = df.kills
	df.sim_step(1.0 / 30.0)
	check(df.kills == kills0 + 1, "bullet hit kills a weak enemy")
	check(df.takedowns >= 1, "kill counts as a KO")
	Engine.time_scale = 1.0

	# kamikaze hits the player
	df._spawn_enemy("kamikaze")
	var kz: DfPlane = df.enemies[-1]
	kz.position = df.player.position + Vector3(2, 0, 0)
	var hp0: float = df.player.hp
	df.sim_step(1.0 / 30.0)
	check(df.player.hp < hp0 and not df.enemies.has(kz), "kamikaze contact hurts you and dies")

	# bomb sinks a ship
	df._spawn_ship()
	var s: Dictionary = df.ships[-1]
	df.projectiles.append({"p": s.pos + Vector3.UP * 3.0, "v": Vector3.DOWN * 40.0, "life": 5.0, "kind": "bomb", "dmg": 90.0})
	for k in 10:
		df.sim_step(1.0 / 30.0)
	check(not s.alive, "bomb sinks a ship")

	# asteroid crater
	var palms0: int = w.palms_alive()
	var changed: int = w.carve(w.islands[0].pos, 300.0)
	check(changed > 1000 and w.palms_alive() < palms0, "asteroid paints a crater and flattens palms (%d px, palms %d -> %d)" % [changed, palms0, w.palms_alive()])
	# ---------------- asteroid show (slice 14d)
	df.debris.clear()
	df.shock = {}
	var ipt: Vector3 = df.world.islands[0].pos
	df.player.position = ipt + Vector3(600.0, 150.0, 0.0)
	df.player.roll_t = 0.0
	df._on_impact(Vector3(ipt.x, 0.0, ipt.z))
	Engine.time_scale = 1.0
	df._slowmo_until = 0
	check(df.debris.size() == df.DEBRIS_COUNT and df.shock.alive, "impact: %d burning rocks + a shockwave" % df.debris.size())
	var pv0: Vector3 = df.player.vel
	for k in 30:
		df._shock_step(1.0 / 30.0)
	check(df.shock.hit_player and (df.player.vel - pv0).length() > 40.0, "the shockwave reaches you 600 m out and shoves you (%.0f m/s)" % (df.player.vel - pv0).length())
	var dsteps := 0
	while not df.debris.is_empty() and dsteps < 600:
		df._debris_step(1.0 / 30.0)
		dsteps += 1
	check(df.debris.is_empty() and dsteps > 60, "the debris arcs up and comes down (%.1f s)" % (dsteps / 30.0))
	for k in 200:
		df._shock_step(1.0 / 30.0)
	check(not df.shock.alive, "the shockwave dies out at %.0f m" % df.SHOCK_MAX)
	df.player.hp = df.player.max_hp

	df._on_impact(w.islands[0].pos + Vector3(-90, 0, 30))
	Engine.time_scale = 1.0

	# crash into the sea ends the run
	df.player.position = Vector3(300, 0.5, 1000)
	df.sim_step(1.0 / 30.0)
	check(df.state == "crash", "touching water = crash")
	for k in 120:
		df.sim_step(1.0 / 30.0)
	check(df.state == "over", "crash leads to the end screen")
	check(main.get_node("%PopupLayer").visible, "result popup")
	check(not Game.minigame_active, "minigame flag cleared")
	main.get_node("%PopupButton").pressed.emit()
	await get_tree().process_frame
	check(not main.in_minigame and Engine.time_scale == 1.0, "BACK restores the screen and time scale")

	# ---------------- full autopilot matches
	var results: Array = []
	for m in 3:
		main.start_dogfight(100 + m)
		df.set_process(false)
		df.autopilot = true
		var t := 0.0
		var saw: Dictionary = {}
		var crater := false
		while df.state != "over" and t < 900.0:
			df.sim_step(1.0 / 30.0)
			df._update_camera(1.0 / 30.0)
			t += 1.0 / 30.0
			saw[df.weather.preset] = true
			if df.wave >= 5 and not df.weather.asteroid_active and df.waves_cleared >= 4:
				crater = true
		Engine.time_scale = 1.0
		results.append("seed %d: %.0fs, waves %d, kills %d, score %d, weather %s" % [100 + m, t, df.waves_cleared, df.kills, int(df.score), str(saw.keys())])
		check(t < 900.0 or df.state != "over", "match %d ends or runs cleanly" % m)
		if df.state != "over":
			df._crash()
			for k in 120:
				df.sim_step(1.0 / 30.0)
		main.get_node("%PopupButton").pressed.emit()
		await get_tree().process_frame
	for r in results:
		print(r)
	check(Game.df_best_wave >= 1, "autopilot clears at least one wave (best %d)" % Game.df_best_wave)

	# perf: one sim step with a busy wave
	main.start_dogfight(3)
	df.set_process(false)
	df.wave = 7
	df._next_wave()
	var t0 := Time.get_ticks_usec()
	for k in 60:
		df.sim_step(1.0 / 30.0)
	var per_step := (Time.get_ticks_usec() - t0) / 60.0 / 1000.0
	print("busy wave 8: %.2f ms per sim step (%d enemies, %d ships)" % [per_step, df.enemies.size(), df._ships_alive()])
	check(per_step < 12.0, "sim step fast enough for 30+ fps")
	df.stop()
	Engine.time_scale = 1.0

	# ---------------- slice 16k: T's iPhone notes
	# random weather: varies across matches, never repeats back to back, asteroid wave keeps "impact"
	var all_seen := {}
	var repeats := 0
	for sd in 8:
		df.start(200 + sd)
		df.set_process(false)
		for wi in 6:
			df._next_wave()
			all_seen[df._wave_def.preset] = true
		for k in range(1, df.weather_log.size()):
			if df.weather_log[k] == df.weather_log[k - 1] and df.weather_log[k] != "impact":
				repeats += 1
		check(df.weather_log[4] == "impact", "asteroid wave keeps the impact sky (%s)" % str(df.weather_log))
		check(df.wave_plan(6).title.begins_with("WAVE 6 · BOSS"), "boss wave keeps its title")
		df.stop()
	check(all_seen.size() >= 5, "weather is random: %d different skies over 8 matches (%s)" % [all_seen.size(), str(all_seen.keys())])
	check(repeats == 0, "the same weather never runs twice in a row (%d)" % repeats)
	df.start(1)
	df.set_process(false)
	df.demo = "beach"
	df._next_wave()
	check(df._wave_def.preset == "morning", "demos keep the fixed weather order")
	df.demo = ""
	df.stop()
	# gun cone wider than the idle reticle
	df.start(2)
	df.set_process(false)
	var cone_px: float = df.render.focal * df.SHRINK * tan(df.GUN_CONE)
	check(cone_px > df.idle_reticle_size() * 1.15, "auto-target cone (%.0f px) is wider than the reticle (%.0f px)" % [cone_px, df.idle_reticle_size()])
	check(df.GUN_CONE > deg_to_rad(11.5), "gun cone widened from 11 deg")
	# message timing: shorter hold, quick fade
	df._show_msg("TEST", 2.5, "sub")
	check(df._msg_t < 2.0 and df._msg_t >= 0.45, "messages hold shorter (%.2f s for a 2.5 s ask)" % df._msg_t)
	var mc: Color = df.center_msg.get_theme_color("font_color")
	check(absf(mc.r - 1.0) < 0.01 and absf(mc.g - 0.882) < 0.01 and absf(mc.b - 0.29) < 0.01, "dogfight text is yellow (%s)" % str(mc))
	check(df.center_msg.get_theme_constant("outline_size") >= 8, "dogfight text has a black outline")
	df.stop()
	# phones: no cinematic bars, the replay director judges the full frame
	Game.force_phone = true
	df.start(3)
	df.set_process(false)
	check(df.replay.full_frame, "phone: replay uses the full frame")
	df.state = "replay"
	df._lb_strip = 1.0
	df._letterbox(0.1)
	check(not df._lb_top.visible and not df._lb_caption.visible and df._lb_label.visible, "phone: no bars, no film caption, REPLAY tag shown")
	df.state = "wave"
	df.stop()
	Game.force_phone = false
	df.start(3)
	df.set_process(false)
	check(not df.replay.full_frame, "PC: replay keeps the 2.39:1 strip")
	df.size = Vector2(720, 1100)
	df.state = "replay"
	for k in 30:
		df._letterbox(0.1)
	check(df._lb_top.visible and df._lb_top.size.y > 100.0, "PC: the strip bars close (%.0f px)" % df._lb_top.size.y)
	df.state = "wave"
	df.stop()
	Engine.time_scale = 1.0

	# ---------------- slice 16m: boot weather, smooth blends, KO text, enemies left
	df.start(321)
	df.set_process(false)
	var boot_sky: String = df.weather.preset
	check(df._wave1_plan.get("preset", "") == boot_sky and df.weather.blend_progress() >= 1.0, "wave 1 weather is on screen at boot (%s)" % boot_sky)
	df._next_wave()
	check(df.wave == 1 and df.weather.preset == boot_sky and df.weather_log[0] == boot_sky, "wave 1 keeps the boot sky (no switch when the wave starts)")
	df.weather.set_preset("morning", true)
	df.weather.set_preset("storm")
	for k in 30:
		df.weather.tick(0.1)          # 3 s in
	check(df.weather.blend_progress() < 0.4, "weather blend is long (%.2f done after 3 s)" % df.weather.blend_progress())
	check(df.weather.rain_amt > 0.0 and df.weather.rain_amt < 0.5, "rain fades in (%.2f after 3 s)" % df.weather.rain_amt)
	check(not df.weather.thunder_on, "no thunder until the storm has built up")
	for k in 120:
		df.weather.tick(0.1)          # 15 s in
	check(df.weather.blend_progress() >= 1.0 and df.weather.rain_amt >= 1.0 and df.weather.thunder_on, "storm fully in after 15 s")
	df.weather.set_preset("morning")
	df.weather.tick(1.0)
	check(df.weather.rain_on and df.weather.rain_amt < 1.0, "rain fades out instead of stopping at once")
	df._update_hud(0.016)
	check(df.enemies_label.visible == (df.enemies_left() > 0), "enemies-left counter shows during a wave")
	check(df.enemies_label.text == "ENEMIES LEFT %d" % df.enemies_left(), "counter text (%s)" % df.enemies_label.text)
	var n0: int = df.enemies_left()
	for en in df.enemies:
		if en.alive:
			en.alive = false
			break
	df._update_hud(0.016)
	check(df.enemies_left() == n0 - 1 and df._left_pop > 0.0, "the counter drops and pops on a kill")
	df.stop()

	# ---------------- slice 16n: course clear -> cyan laser chain + lightning
	df.start(77)
	df.set_process(false)
	df.state = "wave"
	df.enemies.clear()
	var lineup: Array = []
	for k in 4:                       # 4 jets in a rough line ahead, 250 m apart
		var cen := DfPlane.new()
		cen.setup("fighter", df.player.position + df.player.forward() * (300.0 + 250.0 * k) + Vector3(30.0 * k, 0, 0), 0.0)
		df.enemies.append(cen)
		lineup.append(cen)
	var farj := DfPlane.new()          # too far from the chain: must not be hit
	farj.setup("fighter", df.player.position + df.player.forward() * 300.0 + Vector3(1500, 0, 0), 0.0)
	df.enemies.append(farj)
	df.rings.spawn(df.player.position, df.player.forward(), "slalom")
	for i in DfRings.RINGS:
		df.rings.pass_ring()
	df._supercharge()
	check(df.cyan_laser and df.laser_ready(), "course clear: laser supercharged (cyan, charged)")
	df._laser_step(0.0)
	check(df.laser_target != null, "cyan laser locks the nearest jet")
	check(df.chain_preview.size() == 4, "chain preview covers the 4 lined-up jets, not the far one (%d)" % df.chain_preview.size())
	check(df.controls.laser_cyan, "laser button turns cyan")
	df.fire_laser()
	check(not df.cyan_laser and df.lasers[0].get("cyan", false) and df.laser_burst_cyan, "the shot is cyan and spends the supercharge")
	var nstrikes := 0
	var narcs := 0
	var csc0: float = df.score
	for k in 60:
		df._laser_step(1.0 / 30.0)
		df._zaps_step(1.0 / 30.0)
		for z in df.zaps:
			if float(z.t) == 0.0 or float(z.t) <= 1.0 / 30.0 + 0.001:
				if z.kind == "strike":
					nstrikes += 1
				else:
					narcs += 1
	var ndead := 0
	for cen in lineup:
		if not cen.alive:
			ndead += 1
	check(ndead == 4, "the chain KOs all 4 jets (%d)" % ndead)
	check(farj.alive, "the far jet is out of chain range and survives")
	check(nstrikes >= 4, "lightning strikes every chained jet (%d)" % nstrikes)
	check(narcs >= 3, "cyan arcs jump jet to jet (%d)" % narcs)
	check(df.score - csc0 > 3.0 * df.CHAIN_SCORE, "chain combo scores (+%d)" % int(df.score - csc0))
	df.laser_charge = 1.0
	df._laser_step(0.0)
	check(df.chain_preview.is_empty(), "a normal laser shows no chain")
	df.stop()

	# ---------------- slice 16o: skinny, larger rings that launch you to the next one
	check(DfRings.RING_RADIUS >= 40.0, "rings are larger (hit radius %.0f m)" % DfRings.RING_RADIUS)
	df.autopilot = false
	df.start(91)
	df.set_process(false)
	df.state = "wave"
	df.enemies.clear()
	df.rings.spawn(df.player.position - df.player.forward() * 600.0, df.player.forward(), "slalom")
	var lr0: Dictionary = df.rings.rings[0]
	df.player.position = lr0.pos - lr0.normal * 30.0
	df.player._set_yp(atan2(-lr0.normal.x, -lr0.normal.z), 0.0)
	df.player.vel = df.player.forward() * 150.0
	df.player.speed = 150.0
	var lsteps := 0
	while df.rings.next == 0 and lsteps < 60:
		df.sim_step(1.0 / 30.0)
		lsteps += 1
	check(df.rings.next == 1 and df.player.launch_t > 0.0, "a ring pass launches the jet")
	for k in 9:
		df.sim_step(1.0 / 30.0)
	var to_next: Vector3 = (df.rings.rings[1].pos - df.player.position).normalized()
	check(df.player.forward().angle_to(to_next) < deg_to_rad(18.0), "after 0.3 s the nose points at the next ring (%.0f deg off)" % rad_to_deg(df.player.forward().angle_to(to_next)))
	check(df.player.speed >= 200.0, "launch speed (%.0f m/s)" % df.player.speed)
	var lst := 0
	while df.rings.next == 1 and lst < 45:
		df.sim_step(1.0 / 30.0)
		lst += 1
	check(df.rings.next == 2, "the launch carries you through the next ring (%.1f s)" % (lst / 30.0))
	df.stop()

	# ---------------- slice 16p: courses rarer in later waves (T picked option 3)
	check(df.course_gap(1) == 6.0 and df.course_gap(3) == 6.0, "waves 1-3: next course after 6 s")
	check(df.course_gap(4) == 13.0 and df.course_gap(6) == 27.0 and df.course_gap(12) == 40.0, "later waves: 13 s, 27 s, max 40 s")
	df.start(5)
	df.set_process(false)
	df.wave = 5
	df._next_wave()
	check(df.rings.respawn == 27.0, "wave 6 sets the course gap (%.0f s)" % df.rings.respawn)
	df.rings.spawn(df.player.position, df.player.forward(), "slalom")
	for i in DfRings.RINGS:
		df.rings.pass_ring()
	check(df.rings.cooldown == 27.0, "after a course in wave 6, the next one waits 27 s")
	df.stop()

	print("DOGFIGHT TESTS: %d passed, %d failed" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)
