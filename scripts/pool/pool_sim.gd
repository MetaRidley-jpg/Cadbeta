class_name PoolSim
extends RefCounted
## Pool physics + 8-ball rules. Pure logic: no nodes, no drawing. Fully testable.
## Table is vertical: x 0..W, y 0..H. Rack at the top, cue ball at the bottom.
## Ball ids: 0 = cue, 1-7 solids (YOU), 8 = eight, 9-15 stripes (CADAVIRE).

const W := 500.0
const H := 1000.0
const R := 13.0                    # ball radius
const MAX_SPEED := 2500.0          # power 1.0
const FRICTION := 270.0            # speed lost per second (rolling)
const STOP_SPEED := 6.0
const BALL_E := 0.95               # ball-ball restitution
const RAIL_E := 0.76               # cushion restitution
const CORNER_MOUTH := 30.0         # no cushion this close to a corner
const SIDE_MOUTH := 23.0           # no cushion this close to a side pocket (along y)
const CORNER_CAPTURE := 29.0       # center this close to a corner = pocketed
const SIDE_CAPTURE := 25.0
const SUBSTEP := 1.0 / 240.0
const HEAD_SPOT := Vector2(W * 0.5, H * 0.78)
const FOOT_SPOT := Vector2(W * 0.5, H * 0.26)

enum Side { PLAYER, CADAVIRE }

var pos: Array = []        # Vector2 per ball id
var vel: Array = []        # Vector2 per ball id
var down: Array = []       # bool per ball id (pocketed)
var rng := RandomNumberGenerator.new()

# per-shot event log
var first_hit := -1
var pocketed_this_shot: Array = []
var shots_taken := 0

static func pockets() -> Array:
	return [Vector2(0, 0), Vector2(W, 0), Vector2(0, H * 0.5), Vector2(W, H * 0.5), Vector2(0, H), Vector2(W, H)]

static func group_of(id: int) -> int:
	if id >= 1 and id <= 7:
		return Side.PLAYER
	if id >= 9:
		return Side.CADAVIRE
	return -1

func rack(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	pos.resize(16)
	vel.resize(16)
	down.resize(16)
	for i in 16:
		vel[i] = Vector2.ZERO
		down[i] = false
	pos[0] = HEAD_SPOT
	# Standard 8-ball rack: 8 in the middle, one solid + one stripe in back corners.
	var others: Array = [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]
	var solid_corner: int = rng.randi_range(1, 7)
	var stripe_corner: int = rng.randi_range(9, 15)
	others.erase(solid_corner)
	others.erase(stripe_corner)
	for k in range(others.size() - 1, 0, -1):   # shuffle with our rng
		var j := rng.randi_range(0, k)
		var t = others[k]
		others[k] = others[j]
		others[j] = t
	var slots: Array = []
	var gap := 0.4
	for row in 5:
		for j in row + 1:
			var x := W * 0.5 + (j - row * 0.5) * (2.0 * R + gap)
			var y := FOOT_SPOT.y - row * (2.0 * R + gap) * 0.866
			slots.append(Vector2(x, y))
	# slot 4 = middle of row 3 (8 ball); slots 10 and 14 = back corners
	var order: Array = []
	order.resize(15)
	order[4] = 8
	var back_left := 10
	var back_right := 14
	if rng.randf() < 0.5:
		order[back_left] = solid_corner
		order[back_right] = stripe_corner
	else:
		order[back_left] = stripe_corner
		order[back_right] = solid_corner
	var oi := 0
	for s in 15:
		if order[s] == null:
			order[s] = others[oi]
			oi += 1
	for s in 15:
		pos[order[s]] = slots[s]
	shots_taken = 0

func balls_left(side: int) -> int:
	var n := 0
	for i in range(1, 16):
		if not down[i] and group_of(i) == side:
			n += 1
	return n

func legal_targets(side: int) -> Array:
	var out: Array = []
	for i in range(1, 16):
		if not down[i] and group_of(i) == side:
			out.append(i)
	if out.is_empty() and not down[8]:
		out.append(8)
	return out

func is_moving() -> bool:
	for i in 16:
		if not down[i] and vel[i] != Vector2.ZERO:
			return true
	return false

func shoot(dir: Vector2, power: float) -> void:
	first_hit = -1
	pocketed_this_shot = []
	vel[0] = dir.normalized() * clampf(power, 0.0, 1.0) * MAX_SPEED
	shots_taken += 1

## Advance physics by dt seconds (internally in fixed substeps).
func step(dt: float) -> void:
	var t := dt
	while t > 0.0:
		var h := minf(SUBSTEP, t)
		_substep(h)
		t -= h

func _substep(h: float) -> void:
	for i in 16:
		if down[i] or vel[i] == Vector2.ZERO:
			continue
		pos[i] += vel[i] * h
		var sp: float = vel[i].length()
		sp -= FRICTION * h
		vel[i] = Vector2.ZERO if sp < STOP_SPEED else vel[i].normalized() * sp
	# ball-ball
	for i in 16:
		if down[i]:
			continue
		for j in range(i + 1, 16):
			if down[j]:
				continue
			var d: Vector2 = pos[j] - pos[i]
			var dist := d.length()
			if dist >= 2.0 * R or dist < 0.0001:
				continue
			var n := d / dist
			var overlap := 2.0 * R - dist
			pos[i] -= n * overlap * 0.5
			pos[j] += n * overlap * 0.5
			var vrel: float = (vel[i] - vel[j]).dot(n)
			if vrel > 0.0:
				var imp := (1.0 + BALL_E) * 0.5 * vrel
				vel[i] -= n * imp
				vel[j] += n * imp
				if first_hit == -1 and (i == 0 or j == 0):
					first_hit = j if i == 0 else i
	# rails + pockets
	for i in 16:
		if down[i]:
			continue
		var p: Vector2 = pos[i]
		if _in_pocket(p):
			_pocket(i)
			continue
		var in_corner_x := p.y < CORNER_MOUTH or p.y > H - CORNER_MOUTH
		var in_side := absf(p.y - H * 0.5) < SIDE_MOUTH
		var in_corner_y := p.x < CORNER_MOUTH or p.x > W - CORNER_MOUTH
		if not in_corner_x and not in_side:
			if p.x < R and vel[i].x < 0.0:
				p.x = R
				vel[i].x = -vel[i].x * RAIL_E
			elif p.x > W - R and vel[i].x > 0.0:
				p.x = W - R
				vel[i].x = -vel[i].x * RAIL_E
		if not in_corner_y:
			if p.y < R and vel[i].y < 0.0:
				p.y = R
				vel[i].y = -vel[i].y * RAIL_E
			elif p.y > H - R and vel[i].y > 0.0:
				p.y = H - R
				vel[i].y = -vel[i].y * RAIL_E
		pos[i] = p
		# fell through a mouth = pocketed
		if p.x < -R * 0.2 or p.x > W + R * 0.2 or p.y < -R * 0.2 or p.y > H + R * 0.2:
			_pocket(i)

func _in_pocket(p: Vector2) -> bool:
	var pk := pockets()
	for k in pk.size():
		var cap := SIDE_CAPTURE if (k == 2 or k == 3) else CORNER_CAPTURE
		if p.distance_to(pk[k]) < cap:
			return true
	return false

func _pocket(i: int) -> void:
	down[i] = true
	vel[i] = Vector2.ZERO
	pocketed_this_shot.append(i)

## Put the cue ball back after a scratch (nudged so it does not overlap).
func respot_cue() -> void:
	down[0] = false
	vel[0] = Vector2.ZERO
	var p := HEAD_SPOT
	for tries in 40:
		var ok := true
		for i in range(1, 16):
			if not down[i] and pos[i].distance_to(p) < 2.0 * R + 1.0:
				ok = false
				break
		if ok:
			break
		p = HEAD_SPOT + Vector2(rng.randf_range(-150, 150), rng.randf_range(-60, 120))
		p.x = clampf(p.x, R * 2, W - R * 2)
		p.y = clampf(p.y, H * 0.6, H - R * 2)
	pos[0] = p

## 8-ball result for the shot just finished. Call when nothing is moving.
## targets_at_start = legal_targets(shooter) taken BEFORE the shot.
## Returns {foul, reason, keep_turn, winner (-1 = none), potted_own}
func judge(shooter: int, targets_at_start: Array) -> Dictionary:
	var opp := Side.CADAVIRE if shooter == Side.PLAYER else Side.PLAYER
	var res := {"foul": false, "reason": "", "keep_turn": false, "winner": -1, "potted_own": 0}
	var scratched := pocketed_this_shot.has(0)
	if scratched:
		res.foul = true
		res.reason = "scratch"
	elif first_hit == -1:
		res.foul = true
		res.reason = "no_hit"
	elif not targets_at_start.has(first_hit) and not (shots_taken == 1 and first_hit != 8):
		# On the break any ball may be hit first (except leading with the 8 is still fine to ignore).
		res.foul = true
		res.reason = "wrong_ball"
	for b in pocketed_this_shot:
		if group_of(b) == shooter:
			res.potted_own += 1
	if pocketed_this_shot.has(8):
		var was_on_eight: bool = targets_at_start == [8]
		res.winner = shooter if (was_on_eight and not res.foul) else opp
		res.reason = "eight_win" if res.winner == shooter else "eight_loss"
		return res
	res.keep_turn = res.potted_own > 0 and not res.foul
	return res
