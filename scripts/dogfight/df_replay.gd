class_name DfReplay
extends RefCounted
## Fighting-game KO replay (T, 2026-11-26: "I want a cinematic replay on ko like a fighting
## game and bars on top and bottom of the screen to make it cinematic").
## KO = the kill that clears a wave, or your own crash.
## - record(): every sim step, a snapshot of everything the renderer draws (jets, ships,
##   bolts, fx, debris, shockwave, lasers) goes into a ring buffer (last BUFFER s).
## - begin(): the game freezes; the snapshots play back through the live renderer from
##   KO-2 s to KO+1 s: normal-ish speed, then slow motion from just before the KO.
##   Jets are interpolated between snapshots, so the slow motion stays smooth.
## - Camera: three hard cuts like a fighting game: an orbit round the victim, an
##   over-the-shoulder shot from the attacker (for a crash: in front of you, looking back),
##   then a low close-up of the KO itself.
## - end(): the live state comes back exactly as it was.

const BUFFER := 3.4            # s of history kept
const BEFORE := 2.0            # replay starts this long before the KO
const AFTER := 1.0             # and runs this long after it
const SLOW_FROM := 0.35        # slow motion starts this long before the KO
const RATE_FAST := 0.8
const RATE_SLOW := 0.32
const PLANE_FIELDS := ["position", "basis", "roll_vis", "kind", "alive", "visible", "vel", "speed",
	"drift", "drift_time", "drift_boost_t", "boost_time", "boosting", "roll_t", "pitch_in", "turn", "free"]

var frames: Array = []         # {t, player, enemies: [{id, st}], projectiles, puffs, blasts, ships, debris, shock, lasers, burst, muzzle}
var active := false
var ko: Dictionary = {}        # {kind: "wave" | "crash", t, pos: Vector3, victim: int (instance id, 0 = none)}
var rt := 0.0                  # replay clock, in recorded time
var real_t := 0.0              # seconds the replay has been showing
var shot := -1                 # 0 orbit, 1 attacker, 2 KO close-up
var _saved: Dictionary = {}
var _ghosts := {}              # id -> DfPlane
var _ko_sound := false
var _side := Vector3.ZERO      # stage line (set on the first camera call of a replay)
var _dir := Vector3.ZERO

static func _pstate(p: DfPlane) -> Dictionary:
	var d := {}
	for f in PLANE_FIELDS:
		d[f] = p.get(f)
	return d

func record(g: Node) -> void:
	var en: Array = []
	for e in g.enemies:
		en.append({"id": e.get_instance_id(), "st": _pstate(e)})
	frames.append({
		"t": g.sim_time,
		"player": {"id": g.player.get_instance_id(), "st": _pstate(g.player)},
		"enemies": en,
		"projectiles": g.projectiles.duplicate(true),
		"puffs": g.fx.puffs.duplicate(true),
		"blasts": g.fx.blasts.duplicate(true),
		"ships": g.ships.duplicate(true),
		"debris": g.debris.duplicate(true),
		"shock": g.shock.duplicate(true),
		"lasers": g.lasers.duplicate(true),
		"zaps": g.zaps.duplicate(true),
		"burst": g.laser_burst_t,
		"muzzle": g.muzzle_t,
		"boss_id": g.boss.get_instance_id() if g.boss != null else 0,
		"boss_st": g.boss_st.duplicate(true),
	})
	var cut: float = g.sim_time - BUFFER
	while frames.size() > 2 and float(frames[0].t) < cut:
		frames.pop_front()

## Can a replay of this KO be shown (enough history)?
func can_play(ko_t: float) -> bool:
	return frames.size() > 10 and float(frames[0].t) < ko_t - 0.5

func begin(g: Node, ko_info: Dictionary) -> void:
	ko = ko_info
	active = true
	rt = maxf(float(ko.t) - BEFORE, float(frames[0].t))
	real_t = 0.0
	shot = -1
	_ko_sound = false
	_side = Vector3.ZERO
	_dir = Vector3.ZERO
	_plan = []
	_fixed.clear()
	_ghosts.clear()
	_saved = {"player": g.player, "enemies": g.enemies, "projectiles": g.projectiles, "puffs": g.fx.puffs,
		"blasts": g.fx.blasts, "ships": g.ships, "debris": g.debris, "shock": g.shock, "lasers": g.lasers, "zaps": g.zaps,
		"burst": g.laser_burst_t, "muzzle": g.muzzle_t, "target": g.laser_target,
		"boss": g.boss, "boss_st": g.boss_st}
	g.laser_target = null

## Advance by real seconds. Returns false when the replay is over.
func step(g: Node, dt: float) -> bool:
	real_t += dt
	var t_ko: float = ko.t
	rt += dt * (RATE_SLOW if rt >= t_ko - SLOW_FROM else RATE_FAST)
	var t_end := minf(t_ko + AFTER, float(frames[frames.size() - 1].t))
	if rt >= t_end:
		return false
	if not _ko_sound and rt >= t_ko:
		_ko_sound = true
		Sfx.play("explosion_big", -4.0, 0.0)
	_apply(g)
	return true

func end(g: Node) -> void:
	active = false
	g.player = _saved.player
	g.enemies = _saved.enemies
	g.projectiles = _saved.projectiles
	g.fx.puffs = _saved.puffs
	g.fx.blasts = _saved.blasts
	g.ships = _saved.ships
	g.debris = _saved.debris
	g.shock = _saved.shock
	g.lasers = _saved.lasers
	g.zaps = _saved.get("zaps", [])
	g.laser_burst_t = _saved.burst
	g.muzzle_t = _saved.muzzle
	g.laser_target = _saved.target
	g.boss = _saved.boss
	g.boss_st = _saved.boss_st
	_saved = {}
	_ghosts.clear()

func _index() -> int:
	var i := 0
	while i < frames.size() - 2 and float(frames[i + 1].t) <= rt:
		i += 1
	return i

func _ghost(id: int, st: Dictionary) -> DfPlane:
	if not _ghosts.has(id):
		var p := DfPlane.new()
		p.setup(String(st.kind), st.position, 0.0)
		_ghosts[id] = p
	return _ghosts[id]

func _fill(p: DfPlane, a: Dictionary, b: Dictionary, k: float) -> void:
	for f in PLANE_FIELDS:
		p.set(f, a[f])
	p.position = (a.position as Vector3).lerp(b.position, k)
	p.basis = (a.basis as Basis).orthonormalized().slerp((b.basis as Basis).orthonormalized(), k)
	p.roll_vis = lerpf(a.roll_vis, b.roll_vis, k)

func _apply(g: Node) -> void:
	var i := _index()
	var fa: Dictionary = frames[i]
	var fb: Dictionary = frames[mini(i + 1, frames.size() - 1)]
	var span := maxf(0.0001, float(fb.t) - float(fa.t))
	var k := clampf((rt - float(fa.t)) / span, 0.0, 1.0)
	var pl := _ghost(int(fa.player.id), fa.player.st)
	_fill(pl, fa.player.st, fb.player.st, k)
	g.player = pl
	var next := {}
	for e in fb.enemies:
		next[int(e.id)] = e.st
	var en: Array = []
	for e in fa.enemies:
		var st: Dictionary = e.st
		if not st.alive:
			continue
		var gp := _ghost(int(e.id), st)
		_fill(gp, st, next.get(int(e.id), st), k)
		en.append(gp)
	g.enemies = en
	g.projectiles = fa.projectiles
	g.fx.puffs = fa.puffs
	g.fx.blasts = fa.blasts
	g.ships = fa.ships
	g.debris = fa.debris
	g.shock = fa.shock
	g.lasers = fa.lasers
	g.zaps = fa.get("zaps", [])
	g.laser_burst_t = fa.burst
	g.muzzle_t = fa.muzzle
	var bid: int = fa.get("boss_id", 0)       # the gunship + its beam play back too
	if bid != 0 and _ghosts.has(bid):
		g.boss = _ghosts[bid]
		g.boss_st = fa.boss_st
	else:
		g.boss = null
		g.boss_st = {}

## Where the victim is in the replay right now (it stops at the KO point once it is gone).
func victim_pos(g: Node) -> Vector3:
	var vid: int = ko.get("victim", 0)
	if ko.kind == "crash":
		return g.player.position if rt < float(ko.t) else ko.pos
	if _ghosts.has(vid):
		var gp: DfPlane = _ghosts[vid]
		for e in g.enemies:
			if e == gp:
				return gp.position
	return ko.pos

## Where the attacker is: the gunship for a beam KO, else your jet (for a crash: you).
func attacker_pos(g: Node) -> Vector3:
	if ko.get("by", "") == "beam" and g.boss != null:
		return g.boss.position
	return g.player.position

## The replay camera: [position, look-at, HORIZONTAL fov, up]. The frame is a 2.39:1 strip
## (DfGame._letterbox), so the fov is set across the strip.
## 16g (T): "barely close enough to make out the planes, combine with randomly picked angles
## including side wing views overhead, turning into frame, from the front of the target plane".
## Every shot sits where the target jet is 8-12 px in the 1/3-res view.
## 16h (T): "Make a scoring system for the replay shots with events and multiple planes in the
## shot worth more and repeating shots takes away points. Manager budget for cool plays".
## So a DIRECTOR picks the 3 shots: it test-flies every candidate through the recorded
## footage, scores what lands in frame, takes points off for repeats, and spends a budget:
## fancy shots cost more, so it saves them for the coolest moments.
const JET_M := 9.0
const STRIP := 2.39
## Phones (T, 2026-11-26): "The mobile replays can remove the cinematic bars and just be a
## replay, pc will still have them". True = the shot is judged on the whole screen.
var full_frame := false
const SHOTS_EARLY := ["side", "overhead", "into_frame", "front", "chase", "orbit"]
const SHOTS_KO := ["side", "low", "front", "overhead", "into_frame"]
const SHOT_COST := {"side": 1, "chase": 1, "front": 2, "orbit": 2, "low": 2, "overhead": 3, "into_frame": 3}
const BUDGET := 6                 # per replay: e.g. overhead (3) + side (1) + low (2)
const PX_OPTIONS := [9.0, 11.5]   # how big the target jet is framed
const SAMPLES := 6                # test-flight samples per candidate shot
# score weights (per sample, then averaged x10): see score_shot()
const W_TARGET := 6.0             # the target jet is in frame
const W_NO_TARGET := -8.0         # ...or not
const W_PLANE := 4.0              # each OTHER jet in frame (the gunship counts 1.5x)
const W_MULTI := 3.0              # bonus when 2+ jets share the frame
const W_BLAST := 5.0              # an explosion in frame (laser / beam kills 8)
const W_LASER := 6.0              # your super laser in frame
const W_BEAM := 6.0               # the gunship's beam in frame
const W_BOLT := 0.5               # each bolt in frame (max 3)
const W_KO := 10.0                # the KO point in frame (KO shot, from the KO on)
const W_SET := 1.0                # looking at land (scenery)
const P_REPEAT := 30.0            # the same shot type twice in one replay
const P_HISTORY := 8.0            # per use of this shot type in the last replays (recent counts more)
static var history: Array = []    # shot types of the last replays, newest last (max 9)

var _plan: Array = []             # [kind, px, score] x 3
var _plan_total := 0.0
var _fixed := {}                  # slot -> {cam, look} for static shots (into_frame)
var _rng := RandomNumberGenerator.new()

## Distance at which a 9 m jet is `px` pixels across in the replay view with this fov.
func _dist_for(g: Node, px: float, hfov: float) -> float:
	var vs: Vector2 = g.render.view_size
	var f := (vs.x * 0.5) / tan(deg_to_rad(hfov) * 0.5)
	return f * JET_M / px

## The target jet's attitude (the victim; for a crash, you).
func victim_basis(g: Node) -> Basis:
	var vid: int = ko.get("victim", 0)
	if ko.kind == "crash" or vid == 0:
		return g.player.basis
	if _ghosts.has(vid):
		return (_ghosts[vid] as DfPlane).basis
	return g.player.basis

func _victim_id() -> int:
	var vid: int = ko.get("victim", 0)
	if ko.kind == "crash" or vid == 0:
		return int(frames[0].player.id)
	return vid

func _frame_at(t: float) -> Dictionary:
	var best: Dictionary = frames[0]
	for f in frames:
		best = f
		if float(f.t) >= t:
			break
	return best

## Recorded position of jet `id` at replay time t.
func pos_at(id: int, t: float) -> Vector3:
	var f := _frame_at(t)
	if int(f.player.id) == id:
		return f.player.st.position
	for e in f.enemies:
		if int(e.id) == id:
			return e.st.position
	return ko.pos

func _basis_at(id: int, t: float) -> Basis:
	var f := _frame_at(t)
	if int(f.player.id) == id:
		return f.player.st.basis
	for e in f.enemies:
		if int(e.id) == id:
			return e.st.basis
	return Basis.IDENTITY

## Where the attacker was at time t (the gunship for a beam KO, else you).
func _attacker_at(t: float) -> Vector3:
	var f := _frame_at(t)
	if ko.get("by", "") == "beam" and int(f.get("boss_id", 0)) != 0:
		for e in f.enemies:
			if int(e.id) == int(f.boss_id):
				return e.st.position
	return f.player.st.position

## The slot windows in replay time: [start, length] for slots 0 (early), 1 (early), 2 (KO).
func _slot_window(slot: int) -> Array:
	var t_ko: float = ko.t
	var t0 := maxf(t_ko - BEFORE, float(frames[0].t))
	var s0_end := t_ko - 1.1
	var s1_end := t_ko - 0.12
	return [[t0, maxf(0.3, s0_end - t0)], [s0_end, maxf(0.3, s1_end - s0_end)], [s1_end, 1.2]][slot]

## Pure shot geometry: where the camera is for shot `kind` framing the target at `px`, at
## progress u (0..1) through slot `slot`, given the target / attacker state. `fixed` caches
## the static into_frame camera for that slot.
func _shot_cam(g: Node, kind: String, px: float, slot: int, u: float, v: Vector3, a: Vector3, vb: Basis, fixed: Dictionary) -> Array:
	var fwd := -vb.z
	var flat := Vector3(fwd.x, 0.0, fwd.z)
	flat = flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
	var right := flat.cross(Vector3.UP).normalized()
	var hfov := 60.0
	var d := _dist_for(g, px, hfov)
	var cam: Vector3
	var look := v
	var up := Vector3.UP
	var t_ko: float = ko.t
	match kind:
		"side":        # wing-on, tracking: the jet crosses the frame side-on
			var sgn := 1.0 if int(t_ko * 10.0) % 2 == 0 else -1.0
			cam = v + right * d * sgn + Vector3.UP * d * 0.08 - flat * d * lerpf(0.25, -0.1, u)
		"overhead":    # straight down from above, the jet pointing up the frame
			cam = v + Vector3.UP * d + flat * d * 0.05
			up = flat
			hfov = 62.0
		"into_frame":  # a fixed camera where the jet is ABOUT to be: it flies / turns into frame
			if not fixed.has(slot):
				var w: Array = _slot_window(slot)
				var tp: float = minf(float(w[0]) + float(w[1]) * 0.65, float(frames[frames.size() - 1].t))
				var p_future: Vector3 = pos_at(_victim_id(), tp) if slot < 2 else (ko.pos as Vector3)
				var side_sgn := 1.0 if int(t_ko * 7.0) % 2 == 0 else -1.0
				fixed[slot] = {"cam": p_future + right * side_sgn * d * 0.85 + flat * d * 0.45 + Vector3.UP * d * 0.15, "look": p_future}
			cam = fixed[slot].cam
			look = (fixed[slot].look as Vector3).lerp(v, 0.35)      # a slow pan toward the jet
		"front":       # head-on from the target's nose, the attacker behind it
			cam = v + flat * d + Vector3.UP * d * 0.12 + right * d * 0.12
			look = v.lerp(a, 0.15)
		"chase":       # over the attacker's shoulder, past it to the target
			var dir := (v - a)
			dir.y = 0.0
			dir = dir.normalized() if dir.length() > 1.0 else flat
			cam = v - dir * d * 1.15 + Vector3.UP * d * 0.18 + dir.cross(Vector3.UP) * d * 0.2
		"orbit":       # a slow 70-degree arc round the target
			var ang := lerpf(-0.6, 0.6, u) + (0.0 if int(t_ko) % 2 == 0 else PI)
			cam = v + (right * cos(ang) + flat * sin(ang)) * d + Vector3.UP * d * 0.2
		"low":         # under the KO, looking up at it against the sky, pushing in
			var kp: Vector3 = ko.pos if slot == 2 and u > 0.08 else v
			cam = kp + right * d * lerpf(0.9, 0.7, u) - flat * d * 0.3 + Vector3.DOWN * d * 0.35
			look = kp + Vector3.UP * 4.0
			hfov = 64.0
	cam.y = maxf(cam.y, g.world.ground_y(cam) + 12.0)
	return [cam, look, hfov, up]

## Project p into the 2.39:1 strip (or the full frame on phones) of a camera: [in frame, size in px of a 9 m jet].
func _in_strip(g: Node, c: Array, p: Vector3) -> Array:
	var cam: Vector3 = c[0]
	var fwd := ((c[1] as Vector3) - cam).normalized()
	var rgt := fwd.cross(c[3]).normalized()
	if rgt.length() < 0.5:
		return [false, 0.0]
	var upv := rgt.cross(fwd)
	var rel := p - cam
	var z := rel.dot(fwd)
	if z < 5.0:
		return [false, 0.0]
	var vs: Vector2 = g.render.view_size
	var f := (vs.x * 0.5) / tan(deg_to_rad(float(c[2])) * 0.5)
	var x := rel.dot(rgt) / z * f
	var y := rel.dot(upv) / z * f
	var inside := absf(x) < vs.x * 0.47 and absf(y) < (vs.y if full_frame else vs.x / STRIP) * 0.47
	return [inside, f * JET_M / z]

## Score one candidate shot by test-flying it through its slot (see the W_ weights).
func score_shot(g: Node, kind: String, px: float, slot: int) -> float:
	var w: Array = _slot_window(slot)
	var vid := _victim_id()
	var fixed := {}
	var total := 0.0
	for k in SAMPLES:
		var u := (k + 0.5) / SAMPLES
		var t: float = float(w[0]) + float(w[1]) * u
		var f := _frame_at(t)
		var v: Vector3 = pos_at(vid, t) if (ko.kind != "crash" or t < float(ko.t)) else (ko.pos as Vector3)
		var c := _shot_cam(g, kind, px, slot, u, v, _attacker_at(t), _basis_at(vid, t), fixed)
		var sc := 0.0
		sc += W_TARGET if _in_strip(g, c, v)[0] else W_NO_TARGET
		var planes := 1 if _in_strip(g, c, v)[0] else 0
		var jets: Array = [f.player]
		jets.append_array(f.enemies)
		for j in jets:
			if int(j.id) == vid or not j.st.alive:
				continue
			var r := _in_strip(g, c, j.st.position)
			if r[0] and float(r[1]) >= 3.0:
				sc += W_PLANE * (1.5 if String(j.st.kind) == "boss" else 1.0)
				planes += 1
		if planes >= 2:
			sc += W_MULTI
		for b in f.get("blasts", []):
			if float(b.t) >= 0.0 and float(b.t) < float(b.life) and _in_strip(g, c, b.pos)[0]:
				sc += W_BLAST * (1.6 if String(b.get("kind", "fire")) in ["laser", "beam"] else 1.0)
		for l in f.get("lasers", []):
			if _in_strip(g, c, (f.player.st.position as Vector3).lerp(l.end, 0.5))[0]:
				sc += W_LASER
		var bs: Dictionary = f.get("boss_st", {})
		var parts: Array = bs.get("parts", [])
		if bs.get("phase", "") == "fire" and not parts.is_empty():
			var p0: Dictionary = parts[parts.size() / 2]
			var bp: Vector3 = (p0.o as Vector3) + (p0.d as Vector3) * minf((float(bs.beam_t) - float(p0.t0)) * 2200.0, float(p0.len))
			if _in_strip(g, c, bp)[0]:
				sc += W_BEAM
		var bolts := 0
		for pr in f.get("projectiles", []):
			if bolts < 6 and _in_strip(g, c, pr.p)[0]:
				bolts += 1
		sc += W_BOLT * minf(bolts, 6.0)
		if slot == 2 and t >= float(ko.t) and _in_strip(g, c, ko.pos)[0]:
			sc += W_KO
		if g.world.band_at(c[1]) > 0:
			sc += W_SET
		total += sc
	return total / SAMPLES * 10.0

## Points off for shot types the last replays used (newest counts double).
func _history_penalty(kind: String) -> float:
	var pen := 0.0
	for k in history.size():
		if history[k] == kind:
			pen += P_HISTORY * (2.0 if k >= history.size() - 3 else 1.0)
	return pen

## The director: score every candidate per slot, then buy the best 3-shot plan within BUDGET.
func _make_plan_scored(g: Node) -> void:
	_rng.randomize()
	var cands: Array = [[], [], []]
	for slot in 3:
		var kinds: Array = SHOTS_KO if slot == 2 else SHOTS_EARLY
		for kind in kinds:
			for px in PX_OPTIONS:
				var sc := score_shot(g, kind, px, slot) - _history_penalty(kind) + _rng.randf_range(-3.0, 3.0)
				cands[slot].append([kind, px, sc])
	var best: Array = []
	var best_total := -INF
	for a in cands[0]:
		for b in cands[1]:
			for c in cands[2]:
				var cost: int = SHOT_COST[a[0]] + SHOT_COST[b[0]] + SHOT_COST[c[0]]
				if cost > BUDGET:
					continue
				var tot: float = float(a[2]) + float(b[2]) + float(c[2])
				if a[0] == b[0]: tot -= P_REPEAT
				if b[0] == c[0]: tot -= P_REPEAT
				if a[0] == c[0]: tot -= P_REPEAT * 0.5
				if tot > best_total:
					best_total = tot
					best = [a, b, c]
	_plan = best
	_plan_total = best_total
	_fixed.clear()
	for p in _plan:
		history.append(p[0])
	while history.size() > 9:
		history.pop_front()

## Random plan (no scoring) - kept for tests and as a fallback with too little footage.
func _make_plan() -> void:
	_rng.randomize()
	var early := SHOTS_EARLY.duplicate()
	var a: String = early[_rng.randi() % early.size()]
	early.erase(a)
	var b: String = early[_rng.randi() % early.size()]
	var kos := SHOTS_KO.duplicate()
	kos.erase(b)
	var c: String = kos[_rng.randi() % kos.size()]
	_plan = [[a, _rng.randf_range(8.0, 12.0), 0.0], [b, _rng.randf_range(8.0, 12.0), 0.0], [c, _rng.randf_range(9.0, 12.0), 0.0]]
	_plan_total = 0.0
	_fixed.clear()

func camera(g: Node) -> Array:
	if _plan.is_empty():
		if frames.size() > 10:
			_make_plan_scored(g)
		else:
			_make_plan()
	var t_ko: float = ko.t
	var s0_end := t_ko - 1.1
	var s1_end := t_ko - 0.12
	shot = 0 if rt < s0_end else (1 if rt < s1_end else 2)
	var w: Array = _slot_window(shot)
	var u := clampf((rt - float(w[0])) / float(w[1]), 0.0, 1.0)
	return _shot_cam(g, _plan[shot][0], _plan[shot][1], shot, u, victim_pos(g), attacker_pos(g), victim_basis(g), _fixed)

## "SHOT 2/3 · FRONT · 74" for the debug readout in the replay bar.
func director_label() -> String:
	if _plan.is_empty() or shot < 0:
		return ""
	var p: Array = _plan[shot]
	return "DIRECTOR  %d/3 %s %d  (plan %d, cost %d/%d)" % [shot + 1, String(p[0]).to_upper(), int(p[2]), int(_plan_total), SHOT_COST[_plan[0][0]] + SHOT_COST[_plan[1][0]] + SHOT_COST[_plan[2][0]], BUDGET]

## Glow trails for the replay (the jets are small in the far shots): [points, color] lists,
## the last 1.6 s of recorded time up to now, for you and the victim.
func trails(g: Node) -> Array:
	var out: Array = []
	var pid: int = frames[0].player.id
	var vid: int = ko.get("victim", 0)
	var pp := PackedVector3Array()
	var vp := PackedVector3Array()
	for f in frames:
		var ft: float = f.t
		if ft > rt:
			break
		if ft < rt - 1.6:
			continue
		if f.player.st.alive:
			pp.append(f.player.st.position)
		if vid != pid:
			for e in f.enemies:
				if int(e.id) == vid and e.st.alive and String(e.st.kind) != "boss":
					vp.append(e.st.position)
	if g.player != null and g.player.alive:
		pp.append(g.player.position)
	out.append([pp, Color(0.35, 0.9, 1.0)])
	if vp.size() > 1:
		out.append([vp, Color(1.0, 0.3, 0.3)])
	return out

