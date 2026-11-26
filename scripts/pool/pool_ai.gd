class_name PoolAI
extends RefCounted
## Cadavire's shot picker. Ghost-ball method:
## for each legal ball x each pocket, find where the cue must touch the ball,
## check both paths are clear, score by cut angle and distance, add aim noise.

## Skill profile from what she wears / her mood.
## aim_sigma = aim error in degrees (std dev). power_mult scales her power.
static func profile() -> Dictionary:
	var p := {"aim_sigma": 0.9, "power_mult": 1.0, "name": "normal"}
	match Game.costume:
		"lab_coat":
			p = {"aim_sigma": 0.45, "power_mult": 1.0, "name": "precise"}
		"caveman":
			p = {"aim_sigma": 1.9, "power_mult": 1.45, "name": "SMASH"}
		"regal_decay":
			p = {"aim_sigma": 0.65, "power_mult": 1.0, "name": "regal"}
	if Game.fever_active:
		p.aim_sigma *= 1.5   # she is too excited to aim well
		p.power_mult *= 1.15
	return p

## Returns {dir: Vector2, power: float, kind: "pot"|"safety"|"break", target: int}
static func choose(sim: PoolSim, side: int, prof: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cue: Vector2 = sim.pos[0]
	if sim.shots_taken == 0:
		var apex := PoolSim.FOOT_SPOT
		return {"dir": (apex - cue).normalized().rotated(deg_to_rad(rng.randfn(0.0, 0.6))),
			"power": 1.0, "kind": "break", "target": -1}
	var targets := sim.legal_targets(side)
	var sigma_hint: float = prof.get("aim_sigma", 0.9)
	var best := {}
	var best_score := -1.0
	for t in targets:
		var b: Vector2 = sim.pos[t]
		for pk in PoolSim.pockets():
			var aim_pt := _pocket_aim(pk)
			var to_pocket: Vector2 = aim_pt - b
			var dist_bp := to_pocket.length()
			if dist_bp < 1.0:
				continue
			var dir_bp := to_pocket / dist_bp
			var ghost := b - dir_bp * 2.0 * PoolSim.R
			var aim: Vector2 = ghost - cue
			var dist_cg := aim.length()
			if dist_cg < 1.0:
				continue
			var aim_n := aim / dist_cg
			var cut := aim_n.dot(dir_bp)
			if cut < 0.5:
				continue   # too thin: her aim error would miss the ball completely
			# Clearance margin grows with distance and her aim error.
			var margin: float = 4.0 + dist_cg * tan(deg_to_rad(sigma_hint)) * 1.5
			if not _clear(sim, cue, ghost, [0, t], margin) or not _clear(sim, b, aim_pt, [0, t], 2.0):
				continue
			if not _ghost_free(sim, ghost, t):
				continue
			var v_obj := sqrt(2.0 * PoolSim.FRICTION * (dist_bp + 45.0))
			var v_contact := v_obj / (cut * (1.0 + PoolSim.BALL_E) * 0.5)
			var v_start := sqrt(v_contact * v_contact + 2.0 * PoolSim.FRICTION * dist_cg)
			var score := cut * cut * 1000.0 / (dist_cg + dist_bp * 1.6)
			# Scratch risk: where does the cue ball go after contact?
			var tangent := aim_n - dir_bp * cut
			if tangent.length() > 0.05:
				var v_after := v_contact * sqrt(maxf(0.0, 1.0 - cut * cut))
				var travel := minf(v_after * v_after / (2.0 * PoolSim.FRICTION), 1400.0)
				var end := ghost + tangent.normalized() * travel
				for pk2 in PoolSim.pockets():
					if _seg_dist(pk2, ghost, end) < 34.0:
						score *= 0.25
						break
			if score > best_score:
				best_score = score
				best = {"dir": aim_n, "power": v_start * 1.05 / PoolSim.MAX_SPEED,
					"kind": "pot", "target": t}
	if best.is_empty():
		# Safety: find ANY clear line into a legal ball (center or edges), softest first.
		var best_d := INF
		for t in targets:
			var c: Vector2 = sim.pos[t]
			var to_c: Vector2 = c - cue
			var side_v := to_c.normalized().orthogonal()
			for off in [0.0, 0.5, -0.5]:
				var tp: Vector2 = c + side_v * off * PoolSim.R
				if _clear(sim, cue, tp, [0, t], 2.0) and cue.distance_to(tp) < best_d:
					best_d = cue.distance_to(tp)
					best = {"dir": (tp - cue).normalized(), "power": 0.42, "kind": "safety", "target": t}
		if best.is_empty():
			best = _kick(sim, cue, targets)
		if best.is_empty():
			var near: int = targets[0] if not targets.is_empty() else 0
			best = {"dir": (sim.pos[near] - cue).normalized(), "power": 0.45, "kind": "safety", "target": near}
		sigma_hint *= 0.5   # safeties are easy, careful shots
	var sigma: float = sigma_hint
	best.dir = best.dir.rotated(deg_to_rad(rng.randfn(0.0, sigma)))
	best.power = clampf(best.power * prof.get("power_mult", 1.0), 0.12, 1.0)
	return best

## One-rail kick: mirror the target across each cushion and aim at the mirror.
static func _kick(sim: PoolSim, cue: Vector2, targets: Array) -> Dictionary:
	var r := PoolSim.R
	var best := {}
	var best_len := INF
	for t in targets:
		var c: Vector2 = sim.pos[t]
		var mirrors := [Vector2(2.0 * r - c.x, c.y), Vector2(2.0 * (PoolSim.W - r) - c.x, c.y),
			Vector2(c.x, 2.0 * r - c.y), Vector2(c.x, 2.0 * (PoolSim.H - r) - c.y)]
		for k in 4:
			var m: Vector2 = mirrors[k]
			var d := m - cue
			# where the path meets the cushion line
			var hit: Vector2
			if k < 2:
				var wall_x := r if k == 0 else PoolSim.W - r
				if absf(d.x) < 0.001:
					continue
				hit = cue + d * ((wall_x - cue.x) / d.x)
			else:
				var wall_y := r if k == 2 else PoolSim.H - r
				if absf(d.y) < 0.001:
					continue
				hit = cue + d * ((wall_y - cue.y) / d.y)
			# Reject cushion points near a pocket mouth (check the axis ALONG the cushion).
			if k < 2:
				if hit.y < 45 or hit.y > PoolSim.H - 45 or absf(hit.y - PoolSim.H * 0.5) < 40:
					continue
			elif hit.x < 45 or hit.x > PoolSim.W - 45:
				continue
			if not _clear(sim, cue, hit, [0], 2.0) or not _clear(sim, hit, c, [0, t], 2.0):
				continue
			var total := cue.distance_to(hit) + hit.distance_to(c)
			if total < best_len:
				best_len = total
				var v := sqrt(2.0 * PoolSim.FRICTION * (total + 150.0)) / PoolSim.RAIL_E
				best = {"dir": d.normalized(), "power": clampf(v / PoolSim.MAX_SPEED, 0.3, 0.8),
					"kind": "kick", "target": t}
	return best

## Aim a little inside the pocket so balls drop instead of rattling the jaw.
static func _pocket_aim(pk: Vector2) -> Vector2:
	var c := Vector2(PoolSim.W * 0.5, PoolSim.H * 0.5)
	if pk.y == PoolSim.H * 0.5:
		return pk + Vector2(-8.0 if pk.x == 0.0 else 8.0, 0.0)
	return pk + (pk - c).normalized() * 6.0

## True if no ball (except ignored ids) blocks the segment a->b.
static func _clear(sim: PoolSim, a: Vector2, b: Vector2, ignore: Array, margin := 0.0) -> bool:
	for i in 16:
		if sim.down[i] or ignore.has(i):
			continue
		if _seg_dist(sim.pos[i], a, b) < 2.0 * PoolSim.R + margin:
			return false
	return true

static func _ghost_free(sim: PoolSim, ghost: Vector2, target: int) -> bool:
	for i in range(1, 16):
		if i == target or sim.down[i]:
			continue
		if sim.pos[i].distance_to(ghost) < 2.0 * PoolSim.R - 0.5:
			return false
	return true

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)
