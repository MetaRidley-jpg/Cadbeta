class_name DfRings
extends RefCounted
## Ring courses (T, 2026-11-26): "Change the rings to be bigger and twinkle and push around a
## scripted path. Make 3-4 different variations. If this is completed your laser powers up to
## big and cyan and your ship sparks".
##
## One course at a time: RINGS big rings that each ride a scripted path. Fly through them IN
## ORDER (the next ring is gold) within TIME_LIMIT of the first ring. Done = the game
## supercharges the laser. Out of time = the course resets. After a course (done or abandoned)
## a different variation appears somewhere else.
##   slalom    the line snakes left and right
##   corkscrew the line twists like a drill
##   loop      the rings ride a slow vertical wheel (fly a loop through them)
##   stairs    the rings climb in steps and slide back and forth like a conveyor

const KINDS := ["slalom", "corkscrew", "loop", "stairs"]
const TITLES := {"slalom": "SLALOM", "corkscrew": "CORKSCREW", "loop": "LOOP WHEEL", "stairs": "SKY STAIRS"}
const RINGS := 5
const RING_RADIUS := 42.0        # hit radius (old hoops 16; first ring courses 29). T: "skinnier and larger"
const RING_SCALE := 1.5          # the thin ring model (radius 14 px x 2 m/px) x 1.5 = 42 m
const SPACING := 110.0           # m between rings along the course (bigger rings, launches)
const TIME_LIMIT := 25.0
const RESPAWN := 6.0             # s before the next course appears
const SPAWN_AHEAD := 650.0       # m in front of the player
const LOST_DIST := 2600.0        # player this far away and not started: move the course
const MAX_TOP := 275.0           # the top of a course stays under the 300 m ceiling
const LOOP_R := 95.0
# Path speeds are kept to ~15-20 m/s sideways (the jet flies 100-150 m/s): the rings drift
# and push around but can be caught. The first tune (~50 m/s) beat even the scripted pilot.

var kind := ""
var origin := Vector3.ZERO
var axis := Vector3.FORWARD      # horizontal course direction
var side := Vector3.RIGHT
var t := 0.0                     # course clock: drives every path
var next := 0                    # index of the ring to fly through next
var timer := -1.0                # s since the first ring; -1 = not started
var cooldown := 0.0              # > 0: no course on the map yet
var rings: Array = []            # {pos, normal, passed, pop}
var completed := 0               # courses cleared this match
var respawn := RESPAWN           # s before the next course; the game raises it in later waves
var last_event := ""             # "", "ring", "done", "fail" (for the game + tests)
var rng := RandomNumberGenerator.new()
var _ground: Callable            # func(p: Vector3) -> float

var _spires: Array = []          # world.spires: {pos, radius, height, alive}

func setup(ground_y: Callable, seed_value: int, spires: Array = []) -> void:
	_ground = ground_y
	_spires = spires
	rng.seed = seed_value
	rings.clear()
	completed = 0
	kind = ""
	cooldown = 2.0               # first course shortly after the start

func active() -> bool:
	return not rings.is_empty() and cooldown <= 0.0

## A new course in front of `pos`, heading along `fwd`. kind_override: tests / demos.
func spawn(pos: Vector3, fwd: Vector3, kind_override := "") -> void:
	var pool: Array = KINDS.filter(func(k): return k != kind)
	kind = kind_override if kind_override != "" else pool[rng.randi_range(0, pool.size() - 1)]
	var base := Vector3(fwd.x, 0.0, fwd.z)
	if base.length() < 0.1:
		base = Vector3.FORWARD
	base = base.normalized()
	# try a few headings, keep the one that sits lowest (spires and hills push a course up;
	# above the 300 m ceiling the game turns you back down)
	var best_clear := INF
	for k in 8:
		var ax := base.rotated(Vector3.UP, rng.randf_range(-0.5, 0.5) if k < 4 else rng.randf_range(-1.6, 1.6))
		var o := pos + ax * SPAWN_AHEAD
		var c := _clearance(o, ax)
		if c < best_clear - 1.0:
			best_clear = c
			axis = ax
			origin = o
		if c <= 5.0 and k >= 1:
			break
	side = axis.cross(Vector3.UP).normalized()
	var lift := LOOP_R + 45.0 if kind == "loop" else rng.randf_range(70.0, 110.0)
	origin.y = minf(best_clear + lift, MAX_TOP - _height(kind))
	t = 0.0
	next = 0
	timer = -1.0
	cooldown = 0.0
	rings.clear()
	for i in RINGS:
		rings.append({"pos": Vector3.ZERO, "normal": axis, "passed": false, "pop": 0.0, "ppos": Vector3.ZERO, "pnormal": axis})
	_update_poses()
	_update_poses()                           # ppos = pos at spawn

## Ground + spire tops under a course line.
func _clearance(o: Vector3, ax: Vector3) -> float:
	var clear := 0.0
	for k in 5:
		clear = maxf(clear, float(_ground.call(o + ax * SPACING * k)) if _ground.is_valid() else 0.0)
	for sp in _spires:
		if not sp.get("alive", true):
			continue
		for k in 5:
			var q := o + ax * SPACING * k
			if Vector2(q.x - sp.pos.x, q.z - sp.pos.z).length() < float(sp.radius) + 70.0:
				clear = maxf(clear, (float(_ground.call(sp.pos)) if _ground.is_valid() else 0.0) + float(sp.height) + 10.0)
	return clear

## How far above its origin a course reaches (top ring + its radius).
func _height(k: String) -> float:
	match k:
		"loop": return LOOP_R + RING_RADIUS
		"stairs": return RINGS * 20.0 + 6.0 + RING_RADIUS
		"corkscrew": return 30.0 + RING_RADIUS
	return RING_RADIUS

## Ring i's pose at course time `at`: [position, normal (the way you fly through it)].
func pose(i: int, at: float) -> Array:
	var s := i * SPACING
	match kind:
		"slalom":
			var x := sin(at * 0.55 - i * 0.9) * 34.0
			var dx := cos(at * 0.55 - i * 0.9) * 34.0 * -0.9 / SPACING
			return [origin + axis * s + side * x, (axis + side * dx).normalized()]
		"corkscrew":
			var a := at * 0.6 + i * 0.85
			return [origin + axis * s + (side * cos(a) + Vector3.UP * sin(a)) * 30.0, axis]
		"loop":
			var c := origin + axis * LOOP_R
			var b := -PI * 0.5 + TAU * i / RINGS + at * 0.18    # i = 0 at the bottom, then up and over
			var p := c + axis * cos(b) * LOOP_R + Vector3.UP * sin(b) * LOOP_R
			var tng := (-axis * sin(b) + Vector3.UP * cos(b)).normalized()
			return [p, tng]
		"stairs":
			var slide := sin(at * 0.5 + i * 1.1) * 32.0
			var bob := sin(at * 1.2 + i * 1.7) * 6.0
			return [origin + axis * (s + slide) + Vector3.UP * (i * 20.0 + bob), (axis + Vector3.UP * 0.2).normalized()]
	return [origin + axis * s, axis]

func _update_poses() -> void:
	for i in rings.size():
		var ps := pose(i, t)
		rings[i].ppos = rings[i].pos          # last step's pose: the crossing test needs both
		rings[i].pnormal = rings[i].normal
		rings[i].pos = ps[0]
		rings[i].normal = ps[1]

## Per sim step. Returns last_event for this step.
func tick(dt: float, player_pos: Vector3, player_fwd: Vector3) -> String:
	last_event = ""
	if rings.is_empty() or cooldown > 0.0:
		cooldown -= dt
		if cooldown <= 0.0:
			spawn(player_pos, player_fwd)
		return last_event
	t += dt
	_update_poses()
	for r in rings:
		r.pop = maxf(0.0, float(r.pop) - dt)
	if timer >= 0.0:
		timer += dt
		if timer > TIME_LIMIT:
			for r in rings:
				r.passed = false
			next = 0
			timer = -1.0
			last_event = "fail"
	elif player_pos.distance_to(origin) > LOST_DIST:
		spawn(player_pos, player_fwd)            # you flew off: bring a course to you
	return last_event

## The flight from a (last step) to b (now) went through the NEXT ring? Only the next one
## counts. The ring moves too, so a is measured against the ring's LAST pose and b against
## its current one (testing both against the current pose missed passes: the plane slid
## past a jet that had stopped 0.1 m short of it).
func crossed(a: Vector3, b: Vector3) -> bool:
	if not active() or next >= rings.size():
		return false
	var r: Dictionary = rings[next]
	var p0: Vector3 = r.get("ppos", r.pos)
	var n0: Vector3 = r.get("pnormal", r.normal)
	var da: float = (a - p0).dot(n0)
	var db: float = (b - r.pos).dot(r.normal)
	if da * db > 0.0:
		return false
	var k := da / (da - db) if absf(da - db) > 0.0001 else 0.0
	return a.lerp(b, k).distance_to(p0.lerp(r.pos, k)) < RING_RADIUS

## Mark the next ring passed. Returns true when that finished the course.
func pass_ring() -> bool:
	rings[next].passed = true
	rings[next].pop = 0.5
	next += 1
	if timer < 0.0:
		timer = 0.0
	if next >= rings.size():
		completed += 1
		cooldown = respawn
		timer = -1.0
		last_event = "done"
		return true
	last_event = "ring"
	return false

## Replays (T: "make loops appear in replays"): a small per-frame record of the course,
## enough to rebuild every ring's pose at any course time.
func snapshot() -> Dictionary:
	var passed: Array = []
	var pops: Array = []
	for r in rings:
		passed.append(r.passed)
		pops.append(r.pop)
	return {"kind": kind, "origin": origin, "axis": axis, "side": side, "t": t, "next": next,
		"cooldown": cooldown, "passed": passed, "pop": pops}

## Put the course back as recorded (at course time `at`, default the recorded one).
func restore(snap: Dictionary, at := -1.0) -> void:
	if snap.is_empty():
		return
	kind = snap.kind
	origin = snap.origin
	axis = snap.axis
	side = snap.side
	t = float(snap.t) if at < 0.0 else at
	next = snap.next
	cooldown = snap.cooldown
	var passed: Array = snap.passed
	var pops: Array = snap.pop
	rings.clear()
	for i in passed.size():
		var ps := pose(i, t)
		rings.append({"pos": ps[0], "normal": ps[1], "passed": passed[i], "pop": pops[i], "ppos": ps[0], "pnormal": ps[1]})

func time_left() -> float:
	return TIME_LIMIT - timer if timer >= 0.0 else TIME_LIMIT
