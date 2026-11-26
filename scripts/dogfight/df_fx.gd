class_name DfFx
extends RefCounted
## Effect particles as data: square pixel puffs (fire, smoke, foam, debris).
## DfRender draws them. Sizes are in meters; positions are world 3D.

const MAX := 220

var puffs: Array = []   # {pos, vel, t, life, s0, s1, col, grav}
var blasts: Array = []  # {pos, t, life, size}: drawn from the explosion sheet (art/fx/explosion.png)

## cap: max size on screen in low-res pixels (debris stays a fleck even next to the lens).
func puff(pos: Vector3, col: Color, s0: float, s1: float, life: float, vel := Vector3.ZERO, grav := 0.0, cap := 70.0) -> void:
	puffs.append({"pos": pos, "vel": vel, "t": 0.0, "life": life, "s0": s0, "s1": s1, "col": col, "grav": grav, "cap": cap})
	if puffs.size() > MAX:
		puffs.pop_front()

## One animated fireball sprite (8 frames: flash, fireball, smoke) + flying debris.
func explosion(pos: Vector3, size := 1.0) -> void:
	blasts.append({"pos": pos, "t": 0.0, "life": 0.62 * sqrt(size), "size": size, "kind": "fire"})
	# (the sheet's last frames are the smoke, so no square smoke puffs here any more)
	for k in 8:
		var dir := Vector3(randf_range(-1, 1), randf_range(0, 1.2), randf_range(-1, 1)).normalized()
		puff(pos, DfPal.OUTLINE, 1.3 * sqrt(size), 1.0 * sqrt(size), 1.1, dir * 30.0 * size, 40.0)   # small debris: big dark squares near the lens looked like holes

## Super laser kill: a big crimson blast (the beam's colors), a second pop just after,
## a red shock ring, and a spray of burning fragments + dark chunks.
func laser_explosion(pos: Vector3) -> void:
	blasts.append({"pos": pos, "t": 0.0, "life": 0.95, "size": 3.8, "kind": "laser", "ring": true})
	var off := Vector3(randf_range(-1, 1), randf_range(0.2, 1), randf_range(-1, 1)).normalized() * 9.0
	blasts.append({"pos": pos + off, "t": -0.14, "life": 0.7, "size": 2.2, "kind": "laser"})
	for k in 24:          # burning fragments: fast, arcing down, leave a short spark streak
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.3, 1.2), randf_range(-1, 1)).normalized()
		var col := Color("ff1f4b") if k % 3 else Color("ffb000")
		puff(pos, col, 2.8, 1.0, randf_range(0.9, 1.6), dir * randf_range(45.0, 85.0), 38.0, 6.0)
	for k in 14:          # dark wreck chunks
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 1.3), randf_range(-1, 1)).normalized()
		puff(pos, DfPal.OUTLINE, 1.6, 1.3, randf_range(1.1, 1.8), dir * randf_range(25.0, 55.0), 45.0, 4.0)

## Killed by the gunship's blue beam: everything blue/cyan (kind "beam" sheet + blue ring).
func beam_explosion(pos: Vector3, big := 1.0) -> void:
	blasts.append({"pos": pos, "t": 0.0, "life": 1.05, "size": 4.2 * big, "kind": "beam", "ring": true})
	for k in 3:
		var off := Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized() * (8.0 + 4.0 * k)
		blasts.append({"pos": pos + off, "t": -0.1 - 0.12 * k, "life": 0.8, "size": 2.0 + 0.4 * k, "kind": "beam"})
	for k in 30:          # cyan sparks + white-hot bits
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.3, 1.2), randf_range(-1, 1)).normalized()
		var col := Color("2fa8ff") if k % 3 else (Color("e8fbff") if k % 2 else Color("78e6ff"))
		puff(pos, col, 2.8, 1.0, randf_range(0.9, 1.7), dir * randf_range(45.0, 95.0), 38.0, 6.0)
	for k in 14:          # dark wreck chunks
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 1.3), randf_range(-1, 1)).normalized()
		puff(pos, DfPal.OUTLINE, 1.6, 1.3, randf_range(1.1, 1.8), dir * randf_range(25.0, 55.0), 45.0, 4.0)
	puff(pos, Color(0.6, 0.9, 1.0, 0.8), 10.0, 46.0, 0.45)   # blue flash

func splash(pos: Vector3, size := 1.0) -> void:
	for k in 8:
		var dir := Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6)).normalized()
		puff(Vector3(pos.x, 0.5, pos.z), DfPal.FOAM, 3.0 * size, 5.0 * size, 0.9, dir * randf_range(14.0, 32.0) * size, 30.0)
	puff(Vector3(pos.x, 0.2, pos.z), Color(DfPal.FOAM, 0.8), 6.0 * size, 22.0 * size, 0.7)

func flak_burst(pos: Vector3) -> void:
	puff(pos, DfPal.FLAK, 4.0, 13.0, 1.5)
	puff(pos, DfPal.FIRE, 3.0, 6.0, 0.14)

func tick(dt: float) -> void:
	var kb: Array = []
	for b in blasts:
		b.t += dt
		if b.t < b.life:      # t < 0 = not started yet (a delayed second pop)
			b.pos += Vector3.UP * 4.0 * dt    # hot air rises
			kb.append(b)
	blasts = kb
	var keep: Array = []
	for p in puffs:
		p.t += dt
		if p.t >= p.life:
			continue
		p.vel.y -= p.grav * dt
		p.pos += p.vel * dt
		keep.append(p)
	puffs = keep

func clear() -> void:
	puffs.clear()
	blasts.clear()
