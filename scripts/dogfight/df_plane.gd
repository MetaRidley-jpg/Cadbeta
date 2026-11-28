class_name DfPlane
extends RefCounted
## Arcade JET (player and AI). Drawn by DfRender from baked pixel-stack sprites. Forward = -Z.
## Inputs (set every frame): turn (-1 left .. 1 right), pitch (-1 dive .. 1 climb), boost, drift.
## Orientation is a full Basis (-Z = nose, +Y = canopy). AI jets fly "classic" (heading +
## pitch, max 68 deg). The player flies FREE: full 360 loops and rolls, inputs act in the
## jet's own frame (pull = toward the canopy). ASSIST levels the wings when you stop pulling.

const KINDS := {
	"player":   {"speed": 125.0, "boost_speed": 215.0, "turn": 1.15, "hp": 100.0, "radius": 7.0},
	"fighter":  {"speed": 118.0, "boost_speed": 118.0, "turn": 0.95, "hp": 30.0, "radius": 7.5},
	"kamikaze": {"speed": 150.0, "boost_speed": 150.0, "turn": 0.85, "hp": 18.0, "radius": 7.0},
	# QUAD GUNSHIP boss: hovers; moved by DfGame._boss_step, not by step()/ai_think()
	"boss":     {"speed": 0.0, "boost_speed": 0.0, "turn": 0.6, "hp": 1400.0, "radius": 40.0},   # covers the rotor hubs
}
const JET_M_PER_PX := 0.6      # 1 model pixel = 0.6 m: ~14 m wingspan
const DRIFT_TURN_MULT := 2.3
const DRIFT_SPEED := 95.0
const DRIFT_GRIP := 1.6        # how fast velocity follows the nose while drifting (per s)
const GRIP := 9.0
const PITCH_RATE := 1.0
const MAX_PITCH := deg_to_rad(68.0)
const FREE_PITCH_RATE := 1.55   # rad/s: a full loop at full pull is about 4 s
const LEVEL_RATE := 2.2         # assist: roll back to wings level (rad/s)
const LEVEL_PITCH := 0.35       # assist: nose back to the horizon (rad/s)
const ROLL_TIME := 0.5          # barrel roll: one full turn about the nose
const ROLL_DODGE := 55.0        # m/s sideways kick at the start of a roll
const ROLL_COOLDOWN := 1.2
const ACCEL := 70.0
const BOOST_DRAIN := 26.0      # boost meter per second while boosting
## Player boost has 3 stages by how long BOOST is held (T's sheet: boost 1, boost 2, top speed).
const BOOST_STAGE_TIME := [0.0, 1.0, 2.2]        # seconds held to reach stage 1, 2, 3
const BOOST_STAGE_SPEED := [0.0, 185.0, 220.0, 255.0]
## T (2026-11-28): "when boosting let speed hold over longer when letting go of the button".
## Let go of BOOST: the speed you reached HOLDS for BOOST_HOLD[stage] s, then COASTS down to
## cruise at COAST_DECEL (normal ACCEL is 70). Top speed -> cruise: ~4.9 s (was ~1.9 s).
## Drift (a brake) and climbing still slow you at once.
const BOOST_HOLD := [0.0, 0.4, 0.8, 1.2]
const COAST_DECEL := 35.0
## Drift boost (player): drift long enough, let go, and you shoot out at TOP SPEED for a
## moment and get some boost meter back. Two tiers by how long you held the drift.
const DRIFT_TIERS := [1.1, 2.2]              # drift seconds for tier 1 / tier 2
const DRIFT_BOOST_TIME := [0.0, 0.9, 1.4]    # seconds of top speed after release
const DRIFT_BOOST_REFILL := [0.0, 12.0, 20.0]

var position := Vector3.ZERO
var visible := true
var kind := "player"
var basis := Basis.IDENTITY
var free := false              # player: full 360 flight
# Ring launch (T: the rings "launch you to the next one and change your yaw"): for launch_t
# seconds the jet flies straight along launch_dir at >= launch_speed while its nose (yaw and
# pitch) swings onto that line. Steering input still applies on top.
const LAUNCH_TURN := 14.0
var launch_dir := Vector3.ZERO
var launch_t := 0.0
var launch_speed := 0.0

func launch(dir: Vector3, time := 0.55, min_speed := 210.0) -> void:
	if dir.length() < 0.01:
		return
	launch_dir = dir.normalized()
	launch_t = time
	launch_speed = min_speed
	speed = maxf(speed, min_speed)
var assist := true             # free flight: auto wings-level when you let go
var yaw: float:                # heading (compat: read/write as before; writing clears roll)
	get:
		var f := -basis.z
		return atan2(-f.x, -f.z)
	set(v):
		_set_yp(v, pitch)
var pitch: float:
	get:
		return asin(clampf(-basis.z.y, -1.0, 1.0))
	set(v):
		_set_yp(yaw, v)
var roll_vis := 0.0            # cosmetic bank into turns (on top of the real attitude)
var roll_t := 0.0              # > 0: barrel roll running
var roll_dir := 1.0
var roll_cd := 0.0
var roll_in := 0               # set by input: -1 / +1 = start a barrel roll that way
var speed_cap := INF           # scripted demos only: hold the jet slow (cinematic)
var speed := 70.0
var vel := Vector3.ZERO
var hp := 100.0
var max_hp := 100.0
var radius := 6.0
var boost := 0.0               # 0..100 meter (player)
var alive := true
var boosting := false
var boost_time := 0.0          # seconds BOOST has been held without a break
var drift_time := 0.0          # seconds the current drift has lasted
var drift_boost_t := 0.0       # > 0: drift boost running (top speed, no meter cost)
var drift_boost_fired := 0     # tier of the last drift boost (for the game to react)
var turn := 0.0
var pitch_in := 0.0
var boost_in := false
var coast_t := 0.0             # > 0: boost just released, speed holds
var coasting := false          # after a boost: slow down gently (COAST_DECEL) until cruise
var _last_stage := 0
var drift := false
var fire_cd := 0.0
var last_hit_by_player := 0.0  # seconds since the player last shot it (takedown credit)
var prop_t := 0.0
var _meta := {}


func setup(k: String, pos: Vector3, heading: float) -> void:
	kind = k
	var d: Dictionary = KINDS[k]
	speed = d.speed
	hp = d.hp
	max_hp = d.hp
	radius = d.radius
	yaw = heading
	position = pos
	vel = forward() * speed

## Baked multi-angle sprites for this kind (cached for every match).
## Where hits are measured from (the gunship's origin is its bottom slice: use its middle).
func hit_center() -> Vector3:
	return position + basis.y * 17.0 if kind == "boss" else position

const BOSS_SPAN := 70.0         # m: the gunship's width
const BOSS_PX := BOSS_SPAN / 46.0   # m per art pixel

## Called every frame for every jet: keep it a dictionary lookup. (Slice 16r: it used to
## rebuild the voxel model and re-read the PNG strip from disk on every call = ~25 ms per
## frame at wave 8, the whole "16 ms fixed draw cost".)
static var _spr_cache := {}     # art name -> DfSprites

func sprites() -> DfSprites:
	return sprites_for(kind)

## Also used to pre-bake every kind at match start (DfRender.setup): a first bake mid-fight
## froze the game for 0.4-1 s.
static func sprites_for(kind: String) -> DfSprites:
	var art := "gunship"
	if kind != "boss":
		art = "kamikaze" if kind == "kamikaze" else "jet_" + kind
		if kind == "player":
			art = Challenges.ship_strip()   # alt jets from the Challenges wall (cosmetic only)
	var hit: DfSprites = _spr_cache.get(art)
	if hit != null:
		return hit
	var s: DfSprites
	if kind == "boss":    # 70 m across (art/stacks/gunship.png is 46 px: ~1.52 m per px)
		# bake_art scales art to the fallback's size: undo that (BOSS_SPAN / extent of the player model)
		s = DfSprites.bake_art("gunship", func(): return model("player"), 32, [-80, -55, -25, 0, 18, 38, 65, 80], BOSS_SPAN / DfSprites.extent(model("player")))
	else:
		s = DfSprites.bake_art(art, func(): return model(kind), 32, [-80, -55, -25, 0, 18, 38, 65, 80], JET_M_PER_PX)
	_spr_cache[art] = s
	return s

func set_meta2(k: String, v) -> void:
	_meta[k] = v

func has_meta2(k: String) -> bool:
	return _meta.has(k)

func forward() -> Vector3:
	return -basis.z

func up() -> Vector3:
	return basis.y

func right() -> Vector3:
	return basis.x

func _set_yp(y: float, p: float) -> void:
	basis = Basis.from_euler(Vector3(p, y, 0.0))   # YXZ: heading, then pitch; no roll

## The attitude the renderer draws: the real one plus the cosmetic bank.
func vis_basis() -> Basis:
	return basis * Basis(Vector3(0, 0, -1), -roll_vis)

func rolling() -> bool:
	return roll_t > 0.0

## turn / pitch_in that point the nose at p, in the jet's own frame (works upside down).
func steer_to(p: Vector3, gain := 2.2) -> Vector2:
	var l := basis.inverse() * (p - position)
	return Vector2(clampf(atan2(l.x, -l.z) * gain, -1.0, 1.0), clampf(atan2(l.y, -l.z) * gain * 1.1, -1.0, 1.0))

## world: anything with ground_y(pos) -> float
func step(dt: float) -> void:
	if not alive:
		return
	var d: Dictionary = KINDS[kind]
	var turn_rate: float = d.turn * (DRIFT_TURN_MULT if drift else 1.0)
	if free:
		_free_rotate(dt, turn_rate)
	else:
		var y := yaw - turn * turn_rate * dt
		var pt := clampf(pitch + pitch_in * PITCH_RATE * dt, -MAX_PITCH, MAX_PITCH)
		if absf(pitch_in) < 0.05:
			pt = move_toward(pt, 0.0, 0.35 * dt)   # gentle auto-level
		_set_yp(y, pt)
	boosting = boost_in and boost > 0.0 and kind == "player"
	# drift charge + release
	if kind == "player":
		if drift:
			drift_time += dt
		else:
			var tier := drift_tier()
			if tier > 0:
				drift_boost_t = DRIFT_BOOST_TIME[tier]
				boost = minf(100.0, boost + DRIFT_BOOST_REFILL[tier])
				drift_boost_fired = tier
			drift_time = 0.0
		drift_boost_t = maxf(0.0, drift_boost_t - dt)
	var target: float = d.speed
	if drift_boost_t > 0.0 and not drift:
		target = BOOST_STAGE_SPEED[3]
		speed = maxf(speed, BOOST_STAGE_SPEED[2])     # kick: it snaps forward
	elif boosting:
		boost_time += dt
		target = d.boost_speed if kind != "player" else BOOST_STAGE_SPEED[boost_stage()]
		boost = maxf(0.0, boost - BOOST_DRAIN * dt)
	elif drift:
		target = DRIFT_SPEED
	var rate := ACCEL
	if kind == "player":
		var stage_now := boost_stage()
		if stage_now == 0 and _last_stage > 0 and drift_boost_t <= 0.0:
			coast_t = BOOST_HOLD[_last_stage]          # just let go: hold, then coast
			coasting = true
		_last_stage = stage_now
		if drift or boosting or launch_t > 0.0:
			coast_t = 0.0
			coasting = false
		if coasting and target < speed:
			if coast_t > 0.0:
				coast_t -= dt
				target = speed                         # hold
			else:
				rate = COAST_DECEL
		elif coasting:
			coasting = false                           # back at cruise
	if not boosting:
		boost_time = 0.0
	speed = move_toward(speed, minf(target, speed_cap), rate * dt)
	speed -= forward().y * 22.0 * dt    # climbing costs speed, diving gains it
	speed = clampf(speed, 60.0, 260.0)
	var grip := DRIFT_GRIP if drift else GRIP
	if launch_t > 0.0:
		launch_t -= dt
		speed = maxf(speed, launch_speed)
		var up_hint := Vector3.UP if absf(launch_dir.y) < 0.95 else -basis.z
		var tgt := Basis.looking_at(launch_dir, up_hint)
		basis = basis.slerp(tgt, clampf(LAUNCH_TURN * dt, 0.0, 1.0)).orthonormalized()
		vel = launch_dir * speed
	else:
		vel = vel.lerp(forward() * speed, clampf(grip * dt, 0.0, 1.0))
	position += vel * dt
	var bank := -turn * (1.15 if drift else 0.75)
	roll_vis = lerpf(roll_vis, bank, clampf(6.0 * dt, 0.0, 1.0))
	fire_cd = maxf(0.0, fire_cd - dt)
	last_hit_by_player += dt
	prop_t += dt

## Free flight: pull = rotate about the wing axis, turn = rotate about the canopy axis,
## barrel roll = one turn about the nose. ASSIST rolls the wings level (and eases the nose
## to the horizon) when you are not pulling hard, so letting go at the top of a loop gives
## a half roll upright (an Immelmann).
func _free_rotate(dt: float, turn_rate: float) -> void:
	roll_cd = maxf(0.0, roll_cd - dt)
	if roll_in != 0 and roll_cd <= 0.0 and roll_t <= 0.0:
		roll_dir = signf(roll_in)
		roll_t = ROLL_TIME
		roll_cd = ROLL_COOLDOWN
		vel += right() * roll_dir * ROLL_DODGE
	roll_in = 0
	basis = basis * Basis(Vector3.RIGHT, pitch_in * FREE_PITCH_RATE * dt)
	basis = basis * Basis(Vector3.UP, -turn * turn_rate * dt)
	if roll_t > 0.0:
		var step := minf(dt, roll_t)
		roll_t -= dt
		basis = basis * Basis(Vector3(0, 0, -1), roll_dir * TAU * step / ROLL_TIME)
	elif assist and absf(pitch_in) < 0.3:
		var f := forward()
		if absf(f.y) < 0.97:
			var level_r := f.cross(Vector3.UP).normalized()
			var a := atan2(f.dot(right().cross(level_r)), right().dot(level_r))
			var k := LEVEL_RATE * (1.0 - absf(pitch_in) / 0.3)
			basis = Basis(f, clampf(a, -k * dt, k * dt)) * basis
		if absf(pitch_in) < 0.05 and up().y > 0.3:
			var pt := asin(clampf(f.y, -1.0, 1.0))
			basis = Basis(right(), -clampf(pt, -LEVEL_PITCH * dt, LEVEL_PITCH * dt)) * basis
	basis = basis.orthonormalized()

## 0 while not drifting long enough, 1 or 2 once the drift is charged.
func drift_tier() -> int:
	if drift_time >= DRIFT_TIERS[1]:
		return 2
	if drift_time >= DRIFT_TIERS[0]:
		return 1
	return 0

## 0 = not boosting, 1 = boost 1 (red/orange), 2 = boost 2 (purple), 3 = top speed (blue blast).
## A drift boost always counts as top speed.
func boost_stage() -> int:
	if drift_boost_t > 0.0 and not drift:
		return 3
	if not boosting:
		return 0
	if boost_time >= BOOST_STAGE_TIME[2]:
		return 3
	if boost_time >= BOOST_STAGE_TIME[1]:
		return 2
	return 1

func damage(v: float) -> bool:
	if not alive:
		return false
	hp -= v
	if hp <= 0.0:
		hp = 0.0
		alive = false
		return true
	return false

# ------------------------------------------------------------------ AI
## Sets turn/pitch for an AI plane chasing `target`. ground_fn(pos) -> ground y.
func ai_think(target: DfPlane, ground_fn: Callable, dt: float) -> void:
	var lead := 0.6 if kind == "fighter" else 0.25
	var aim := target.position + target.vel * lead
	var to := aim - position
	var dist := to.length()
	var want_yaw := atan2(-to.x, -to.z)
	var want_pitch := asin(clampf(to.y / maxf(dist, 0.001), -1.0, 1.0))
	turn = clampf(-wrapf(want_yaw - yaw, -PI, PI) * 2.2, -1.0, 1.0)
	pitch_in = clampf((want_pitch - pitch) * 2.5, -1.0, 1.0)
	# fighters break off when too close so they do not ram you
	if kind == "fighter" and dist < 70.0:
		turn = 1.0 if turn >= 0.0 else -1.0
		pitch_in = 0.6
	# terrain avoidance: look ahead
	var f := forward()
	for ahead in [60.0, 140.0, 240.0]:
		var p: Vector3 = position + f * ahead
		var g: float = ground_fn.call(p)
		if p.y < g + 20.0:
			pitch_in = 1.0
			break
	if position.y > 200.0:
		pitch_in = minf(pitch_in, -0.4)

## Angle (radians) between this plane's nose and the direction to p.
func angle_to_point(p: Vector3) -> float:
	var to := (p - position).normalized()
	return acos(clampf(forward().dot(to), -1.0, 1.0))

# ------------------------------------------------------------------ art
## Pixel-stack JET models. x = right, y = slice (height), z: nose at -z. 1 px = 1 m.
static func model(k: String) -> Dictionary:
	match k:
		"fighter":
			return _fighter()
		"kamikaze":
			return _kamikaze()
	return _player()

static func _player() -> Dictionary:
	var v := {}
	var body := DfPal.BONE
	var trim := DfPal.ORANGE
	# fuselage: nose cone at z -11, wide body mid, engines at the back
	for z in range(-11, 11):
		var half := 0 if z < -8 else (1 if z < 6 else 2)
		for x in range(-half, half + 1):
			v[Vector3i(x, 1, z)] = trim if (z <= -10) else body
			if z > -9:
				v[Vector3i(x, 0, z)] = body
			if z > -7 and z < 8 and absi(x) < 2:
				v[Vector3i(x, 2, z)] = body
	# delta wings (slice 1), orange leading edge + tips
	for z in range(-3, 9):
		var span := mini(2 + int((z + 3) * 0.85), 11)
		for x in range(-span, span + 1):
			if absi(x) < 2:
				continue
			var edge: bool = absi(x) == span or z == -3 + int((absi(x) - 2) / 0.85)
			v[Vector3i(x, 1, z)] = trim if edge else body
	# canards
	for x in range(-4, 5):
		if absi(x) > 1:
			v[Vector3i(x, 1, -7)] = trim
	# twin tail fins (slices 2..6), raked back
	for y in range(2, 7):
		for z in range(5 + (y - 2) / 2, 10):
			for sx in [-3, 3]:
				v[Vector3i(sx, y, z)] = trim if y == 6 else body
	# canopy + Cadavire
	for z in range(-6, -2):
		v[Vector3i(0, 3, z)] = DfPal.CYAN
	v[Vector3i(0, 3, -2)] = DfPal.CADAVIRE
	v[Vector3i(0, 4, -2)] = DfPal.HAIR
	v[Vector3i(0, 4, -1)] = DfPal.HAIR
	v[Vector3i(-1, 3, -2)] = DfPal.ORANGE
	v[Vector3i(1, 3, -2)] = DfPal.ORANGE
	# afterburners
	for x in [-1, 1]:
		v[Vector3i(x, 1, 11)] = DfPal.FIRE
		v[Vector3i(x, 0, 11)] = DfPal.FIRE_RED
	return v

static func _fighter() -> Dictionary:
	var v := {}
	var body := DfPal.ENEMY
	var trim := DfPal.ENEMY_TRIM
	for z in range(-10, 10):
		var half := 0 if z < -7 else 1
		for x in range(-half, half + 1):
			v[Vector3i(x, 1, z)] = trim if z <= -9 else body
			if z > -7:
				v[Vector3i(x, 0, z)] = DfPal.ENEMY_DARK
	# swept wings
	for z in range(-2, 6):
		var span := mini(3 + (z + 2), 10)
		for x in range(-span, span + 1):
			if absi(x) < 2:
				continue
			v[Vector3i(x, 1, z)] = trim if absi(x) >= span - 1 else body
	for x in range(-4, 5):
		v[Vector3i(x, 1, 8)] = body
	for y in range(2, 7):
		for z in range(5 + (y - 2) / 2, 10):
			v[Vector3i(0, y, z)] = trim if y == 6 else body
	for z in range(-5, -2):
		v[Vector3i(0, 2, z)] = DfPal.ENEMY_DARK
	v[Vector3i(0, 1, 10)] = DfPal.FIRE
	return v

static func _kamikaze() -> Dictionary:
	var v := {}
	for z in range(-9, 9):
		for x in range(-1, 2):
			for y in range(0, 3):
				if absi(x) + absi(y - 1) <= 1:
					v[Vector3i(x, y, z)] = DfPal.KAMI if z > -6 else DfPal.BONE
	v[Vector3i(-1, 2, -7)] = DfPal.KAMI_DARK   # skull eye sockets
	v[Vector3i(1, 2, -7)] = DfPal.KAMI_DARK
	for k in range(-4, 5):
		v[Vector3i(k, 1, 6)] = DfPal.KAMI_DARK     # tail fins
		v[Vector3i(0, 1 + absi(k) / 2, 7)] = DfPal.KAMI_DARK
	v[Vector3i(0, 1, 9)] = DfPal.FIRE
	return v
