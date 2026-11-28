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
## T (2026-11-28): "create potential paths for figure 8, big loop and helix shapes":
##   figure8   8 rings on a flat figure 8 (two lobes), swaying side to side
##   bigloop   6 rings on a big round loop (radius 140 m) TILTED 50 deg from vertical, an
##             oblique loop: under the 300 m ceiling a round vertical loop can only be the
##             95 m LOOP WHEEL. (A flat oval was tried: its ends were 36 m hairpins, the jet
##             needs ~110 m, the test pilot flew into the sea.) Rings cover the climb, the
##             top and half the way down; the wheel rocks a little.
##   helix     7 rings on a climbing spiral turn (330 deg round a 110 m column, +108 m),
##             the whole spiral turns slowly round its column

const KINDS := ["slalom", "corkscrew", "loop", "stairs", "figure8", "bigloop", "helix"]
const TITLES := {"slalom": "SLALOM", "corkscrew": "CORKSCREW", "loop": "LOOP WHEEL", "stairs": "SKY STAIRS",
	"figure8": "FIGURE 8", "bigloop": "BIG LOOP", "helix": "HELIX"}
const COUNT := {"figure8": 8, "bigloop": 6, "helix": 7}   # rings per course (others: RINGS)
const F8_L := 230.0              # figure 8: lobe reach along the course line (m)
const F8_W := 110.0              # figure 8: half width
const BIG_R := 140.0             # big loop: radius
const BIG_TILT := deg_to_rad(50.0)   # big loop: lean from vertical (vertical size 2 R cos = 180 m)
const HELIX_R := 110.0           # helix: column radius (the jet turns ~110 m at cruise)
const HELIX_CLIMB := 18.0        # helix: m up per ring
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
const EDGE_PAD := 110.0          # the whole course stays this far inside the arena walls (T: "rings can spawn out of bounds")
const SWAY := 40.0               # m a ring can move sideways off the course line (slalom 34, corkscrew 30)
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
## Highways (slice 16u, T: "ring course highways"): when `highway` is set (the game sets it),
## every course the game spawns points at ANOTHER zone; `target` = that zone's centre, or
## Vector3.INF for a plain course. Clearing it launches you there (DfGame._ring_launch).
var highway := false
var target := Vector3.INF
var target_zone := -1

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
	target = Vector3.INF
	target_zone = -1
	if highway and kind_override == "":
		var here := DfWorld.zone_of(pos)
		var others: Array = [0, 1, 2, 3].filter(func(z): return z != here)
		target_zone = others[rng.randi_range(0, others.size() - 1)]
		var zc := DfWorld.zone_origin(target_zone) + Vector2(DfWorld.QUAD, DfWorld.QUAD) * 0.5
		target = Vector3(zc.x, 0.0, zc.y)
		fwd = target - Vector3(pos.x, 0.0, pos.z)     # the course points down the route
	var base := Vector3(fwd.x, 0.0, fwd.z)
	if base.length() < 0.1:
		base = Vector3.FORWARD
	base = base.normalized()
	# try a few headings, keep the one that sits lowest (spires and hills push a course up;
	# above the 300 m ceiling the game turns you back down)
	# Every candidate is moved inside the arena first (`_inside`); a candidate that had to move
	# far scores worse, so a course near the edge prefers a heading back toward the middle.
	var best_score := INF
	var best_clear := 0.0
	var home := DfWorld.center() - Vector3(pos.x, 0.0, pos.z)
	for k in 12:
		var ax: Vector3
		if k < 4 or target != Vector3.INF:          # a highway keeps close to its route
			ax = base.rotated(Vector3.UP, rng.randf_range(-0.5, 0.5))
		elif k < 8:
			ax = base.rotated(Vector3.UP, rng.randf_range(-1.6, 1.6))
		else:                        # toward the middle of the arena
			ax = (home.normalized() if home.length() > 1.0 else base).rotated(Vector3.UP, rng.randf_range(-0.7, 0.7))
		var o0 := pos + ax * SPAWN_AHEAD
		var o := _inside(o0, ax, kind)
		var c := _clearance(o, ax, kind)
		var score := c + Vector2(o.x - o0.x, o.z - o0.z).length() * 0.5
		if score < best_score - 1.0:
			best_score = score
			best_clear = c
			axis = ax
			origin = o
		if score <= 5.0 and k >= 1:
			break
	side = axis.cross(Vector3.UP).normalized()
	var lift := rng.randf_range(70.0, 110.0)
	match kind:
		"loop": lift = LOOP_R + 45.0
		"bigloop": lift = 45.0       # origin = the bottom ring
		"helix": lift = rng.randf_range(60.0, 90.0)
	if kind_override == "" and best_clear + 35.0 > MAX_TOP - _height(kind):
		spawn(pos, fwd, ["slalom", "figure8"][rng.randi_range(0, 1)])   # too tall for this spot
		return
	origin.y = minf(best_clear + lift, MAX_TOP - _height(kind))
	t = 0.0
	next = 0
	timer = -1.0
	cooldown = 0.0
	rings.clear()
	for i in count_for(kind):
		rings.append({"pos": Vector3.ZERO, "normal": axis, "passed": false, "pop": 0.0, "ppos": Vector3.ZERO, "pnormal": axis})
	_update_poses()
	_update_poses()                           # ppos = pos at spawn

static func count_for(k: String) -> int:
	return int(COUNT.get(k, RINGS))

## Course footprint in its own frame: [along min, along max, side min, side max] (m, ring
## centres + their sway). Used to keep the whole course inside the arena.
static func box(k: String) -> Array:
	match k:
		"loop": return [0.0, LOOP_R * 2.0, -SWAY, SWAY]
		"stairs": return [0.0, (RINGS - 1) * SPACING + 32.0, -SWAY, SWAY]
		"figure8": return [-F8_L, F8_L, -F8_W - 14.0, F8_W + 14.0]
		"bigloop": return [-BIG_R - 8.0, BIG_R + 8.0, -8.0, BIG_R * 2.0 * sin(BIG_TILT) + 8.0]
		"helix": return [-HELIX_R - 8.0, HELIX_R + 8.0, -8.0, HELIX_R * 2.0 + 8.0]
	return [0.0, (RINGS - 1) * SPACING, -SWAY, SWAY]

## Where the ground is sampled under a course. The first 4 kinds keep their old line (the
## centre line, 0..440 m) so their placement does not change.
static func _clear_box(k: String) -> Array:
	if k in ["slalom", "corkscrew", "loop", "stairs", ""]:
		return [0.0, (RINGS - 1) * SPACING, 0.0, 0.0]
	return box(k)

## Move a course origin (flat) so the whole footprint sits EDGE_PAD inside the square arena.
## The arena is convex, so the 4 corners of the footprint suffice.
static func _inside(o: Vector3, ax: Vector3, k: String) -> Vector3:
	var sd := ax.cross(Vector3.UP).normalized()
	var bx := box(k)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for a in [bx[0], bx[1]]:
		for b in [bx[2], bx[3]]:
			var q: Vector3 = ax * float(a) + sd * float(b)
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.z))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.z))
	var mn := DfWorld.ARENA_MIN + Vector2(EDGE_PAD, EDGE_PAD) - lo
	var mx := DfWorld.ARENA_MAX - Vector2(EDGE_PAD, EDGE_PAD) - hi
	return Vector3(clampf(o.x, mn.x, mx.x), o.y, clampf(o.z, mn.y, mx.y))

## Ground + spire tops under a course line.
func _clearance(o: Vector3, ax: Vector3, k := "") -> float:
	var sd := ax.cross(Vector3.UP).normalized()
	var cb := _clear_box(k)
	var pts: Array = []
	for i in 5:
		for j in (1 if cb[2] == cb[3] else 3):
			pts.append(o + ax * lerpf(cb[0], cb[1], i / 4.0) + sd * lerpf(cb[2], cb[3], j / 2.0))
	var clear := 0.0
	for q in pts:
		clear = maxf(clear, float(_ground.call(q)) if _ground.is_valid() else 0.0)
	for sp in _spires:
		if not sp.get("alive", true):
			continue
		for q in pts:
			if Vector2(q.x - sp.pos.x, q.z - sp.pos.z).length() < float(sp.radius) + 70.0:
				clear = maxf(clear, (float(_ground.call(sp.pos)) if _ground.is_valid() else 0.0) + float(sp.height) + 10.0)
	return clear

## How far above its origin a course reaches (top ring + its radius).
func _height(k: String) -> float:
	match k:
		"loop": return LOOP_R + RING_RADIUS
		"stairs": return RINGS * 20.0 + 6.0 + RING_RADIUS
		"corkscrew": return 30.0 + RING_RADIUS
		"figure8": return 18.0 + RING_RADIUS
		"bigloop": return BIG_R * 2.0 * cos(BIG_TILT) + RING_RADIUS
		"helix": return (count_for(k) - 1) * HELIX_CLIMB + 6.0 + RING_RADIUS
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
		"figure8":
			# lemniscate: along = L sin u, side = W sin 2u. Rings sit off the crossing point
			# (u = 0 and PI), so no two rings overlap. The whole 8 sways side to side.
			var n := count_for(kind)
			var u := TAU * (i + 0.5) / n
			var sway := sin(at * 0.4) * 12.0
			var p := origin + axis * F8_L * sin(u) + side * (F8_W * sin(2.0 * u) + sway) + Vector3.UP * 18.0 * cos(u)
			var tng := axis * F8_L * cos(u) + side * 2.0 * F8_W * cos(2.0 * u) - Vector3.UP * 18.0 * sin(u)
			return [p, tng.normalized()]
		"bigloop":
			# a round wheel in a plane leaned BIG_TILT toward `side`: i = 0 at the bottom (at the
			# origin, flown along the line), then up, over the top inverted, and down
			var n2 := count_for(kind)
			var v := Vector3.UP * cos(BIG_TILT) + side * sin(BIG_TILT)
			var c2 := origin + v * BIG_R
			# rings from the bottom to half way down the back (-90..180 deg): never on the low
			# end of the dive. The wheel rocks +-9 deg (a full turn carried the last ring down to
			# 50 m and the test pilot dove into the sea after it)
			var b := -PI * 0.5 + deg_to_rad(270.0) * i / (n2 - 1) + sin(at * 0.3) * 0.15
			var p2 := c2 + (axis * cos(b) + v * sin(b)) * BIG_R
			var tg2 := -axis * sin(b) + v * cos(b)
			return [p2, tg2.normalized()]
		"helix":
			# a climbing turn round a column HELIX_R to the side: ring 0 at the origin, heading
			# along the line; each ring 55 deg further round and HELIX_CLIMB higher
			var ph := deg_to_rad(55.0) * i + at * 0.12     # the whole spiral turns slowly (~13 m/s)
			var col := origin + side * HELIX_R
			var p3 := col + (-side * cos(ph) + axis * sin(ph)) * HELIX_R + Vector3.UP * (i * HELIX_CLIMB + sin(at * 1.1 + i) * 6.0)
			var tg3 := (side * sin(ph) + axis * cos(ph)) * HELIX_R + Vector3.UP * HELIX_CLIMB / deg_to_rad(55.0)
			return [p3, tg3.normalized()]
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
