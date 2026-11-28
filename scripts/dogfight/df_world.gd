class_name DfWorld
extends RefCounted
## SEGA super-scaler world. The ground is FLAT (sea level 0) and drawn by a Mode-7
## shader from one painted map texture. Height comes from sprite obstacles:
## rock spires (cylinders), palm trees (small, no collision), and the volcano cone.
## Islands: sand, grass, rock, palms. NO houses.
##
## Map texture (RGBA8, 1 px = MAP_M m): R = ground band (0 sea, 1 wet sand, 2 sand,
## 3-5 grass, 6 rock, 7 volcanic rock), G = 1 scorched / 2 crater lava,
## B = sea depth near islands (0 = open sea; 1..255 = shore..deep) for the emerald shallows,
## A unused.

const AREA_RADIUS := 1150.0           # the ORIGINAL arena (now the tropical quadrant, zone 0)
## Slice 16t, T: "4x the map and make this just one quadrant". The arena is a square of 4
## quadrants, QUAD m each. Zone 0 (the old islands) keeps its coordinates: it is the NW
## quadrant. Zone 1 = NE (alien hive, slice 16v), zone 2 = SW, zone 3 = SE (T: decide later).
const QUAD := AREA_RADIUS * 2.0        # 2300 m
const ARENA_MIN := Vector2(-AREA_RADIUS, -AREA_RADIUS)
const ARENA_MAX := Vector2(-AREA_RADIUS + QUAD * 2.0, -AREA_RADIUS + QUAD * 2.0)
const ZONE_NAMES := ["ISLANDS", "ALIEN HIVE", "ZONE 3", "ZONE 4"]
const MAP_M := 4.0
const MAP_PX := 1280                   # 5120 m square (arena 4600 m + 260 m sea round it)
const CELL := 500.0                    # scenery grid (culling + fast ground_y)
const HOOP_RADIUS := 16.0

var map_img: Image
var map_tex: ImageTexture
var map_origin := (ARENA_MIN + ARENA_MAX) * 0.5 - Vector2(MAP_PX * MAP_M * 0.5, MAP_PX * MAP_M * 0.5)
var cells := {}                        # Vector2i -> {"palms": [i], "spires": [i]}
## Slice 16v, zone 1 = ALIEN HIVE (T: "StarCraft style aliens with Gatling guns in cliffs, and
## cannons in valleys ... 3 headed hydra plant aliens"). Map: alien land has B = 255 (B is
## only sea depth elsewhere); the shader paints it as creep. Spires there are tall alien
## cliffs ("alien": true). ground_units: {kind: gatling|cannon|hydra, pos} for DfGame.
const ALIEN_ZONE := 1
var ground_units: Array = []
var islands: Array = []                # {pos: Vector3, radius}
var spires: Array = []                 # {pos: Vector3, radius, height, alive}
var palms: Array = []                  # {pos: Vector3, alive, yaw (leans out to sea)}
var volcano := {"pos": Vector3(-560, 0, -520), "radius": 170.0, "height": 190.0}
var hoops: Array = []                  # {pos, normal, yaw, cooldown}
var rng := RandomNumberGenerator.new()

func build(seed_value := 7) -> void:
	rng.seed = seed_value
	islands = [
		{"pos": Vector3(0, 0, -150), "radius": 420.0},
		{"pos": Vector3(560, 0, -620), "radius": 190.0},
		{"pos": Vector3(-620, 0, 330), "radius": 220.0},
		{"pos": Vector3(640, 0, 480), "radius": 150.0},
		{"pos": Vector3(-140, 0, -900), "radius": 140.0},
		{"pos": volcano.pos, "radius": volcano.radius + 40.0},
	]
	for z in range(1, 4):              # placeholder islands in the 3 new quadrants
		var q0 := zone_origin(z)
		var placed: Array = []
		for tries in 40:
			if placed.size() >= 5:
				break
			var r := rng.randf_range(130.0, 330.0)
			var p := Vector3(q0.x + rng.randf_range(r + 120.0, QUAD - r - 120.0), 0.0, q0.y + rng.randf_range(r + 120.0, QUAD - r - 120.0))
			var ok := true
			for o in placed:
				if Vector2(p.x - o.pos.x, p.z - o.pos.z).length() < r + float(o.radius) + 160.0:
					ok = false
			if ok:
				placed.append({"pos": p, "radius": r, "zone": z})
		islands.append_array(placed)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var data := PackedByteArray()
	data.resize(MAP_PX * MAP_PX * 4)
	var best := PackedFloat32Array()
	best.resize(MAP_PX * MAP_PX)
	best.fill(-9.0)
	var touched := {}
	for isl in islands:   # only visit each island's bounding box
		var cx: float = (isl.pos.x - map_origin.x) / MAP_M
		var cz: float = (isl.pos.z - map_origin.y) / MAP_M
		var rp: float = isl.radius * 1.25 / MAP_M
		for z in range(maxi(0, int(cz - rp)), mini(MAP_PX, int(cz + rp) + 1)):
			for x in range(maxi(0, int(cx - rp)), mini(MAP_PX, int(cx + rp) + 1)):
				var d: float = Vector2(x + 0.5 - cx, z + 0.5 - cz).length() * MAP_M / isl.radius
				var v := 1.0 - d * d
				var i := z * MAP_PX + x
				if v > best[i]:
					best[i] = v
					touched[i] = true
	for i in touched:
		var x: int = i % MAP_PX
		var z: int = i / MAP_PX
		var w := map_origin + Vector2(x + 0.5, z + 0.5) * MAP_M
		var hval: float = best[i] * 6.5 + noise.get_noise_2d(x, z) * 2.6
		if hval <= 0.4:
			# sea next to an island: how far below the shoreline (0.4) = depth. The same field
			# that draws the coast, so the shallows follow every bay and point.
			data[i * 4 + 2] = 1 + int(clampf((0.4 - hval) / 4.0, 0.0, 1.0) * 254.0)
		if best[i] <= -0.5:
			continue
		var band := 0
		if hval > 0.4: band = 1
		if hval > 1.0: band = 2
		if hval > 1.9: band = 3
		if hval > 3.2: band = 4
		if hval > 4.4: band = 5
		if hval > 5.6: band = 6
		if band > 0 and Vector2(w.x - volcano.pos.x, w.y - volcano.pos.z).length() < volcano.radius:
			band = 7   # volcanic rock
		data[i * 4] = band
		if band > 0 and zone_of(Vector3(w.x, 0.0, w.y)) == ALIEN_ZONE:
			data[i * 4 + 2] = 255                  # alien creep
	map_img = Image.create_from_data(MAP_PX, MAP_PX, false, Image.FORMAT_RGBA8, data)
	map_tex = ImageTexture.create_from_image(map_img)
	# obstacles
	for isl in islands:
		if isl.pos == volcano.pos:
			continue
		var alien := zone_of(isl.pos) == ALIEN_ZONE
		var n_spires := int(isl.radius / (45.0 if alien else 70.0))
		for k in n_spires:
			var p := _random_on_island(isl, 0.55)
			if band_at(p) >= 4:
				if alien:   # cliffs: taller, wider
					spires.append({"pos": p, "radius": rng.randf_range(22.0, 32.0), "height": rng.randf_range(90.0, 150.0), "alive": true, "alien": true})
				else:
					spires.append({"pos": p, "radius": rng.randf_range(14.0, 24.0), "height": rng.randf_range(55.0, 110.0), "alive": true})
		# sea stacks: mossy pillars standing in the shallows along the beach (T's references)
		var n_sea := int(isl.radius / 55.0)
		for k in n_sea * 3:
			if n_sea <= 0:
				break
			var a := rng.randf() * TAU
			var p: Vector3 = isl.pos + Vector3(cos(a), 0.0, sin(a)) * isl.radius * rng.randf_range(0.95, 1.16)
			if band_at(p) <= 1:
				spires.append({"pos": p, "radius": rng.randf_range(10.0, 16.0), "height": rng.randf_range(45.0, 95.0), "alive": true, "alien": alien})
				n_sea -= 1
		if alien:
			continue                               # no palms in the hive
		var n_palms := int(isl.radius * 0.45)
		for k in n_palms:
			# half of them on the beach ring, leaning out over the water
			var p: Vector3 = _random_on_island(isl, 0.85) if k % 2 else isl.pos + Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU) * isl.radius * rng.randf_range(0.72, 0.95)
			var b := band_at(p)
			if b >= 2 and b <= 5:
				var out := Vector2(p.x - isl.pos.x, p.z - isl.pos.z)
				# the art leans to +x; yaw turns +x to (cos a, 0, sin a) with yaw = -a
				palms.append({"pos": p, "alive": true, "yaw": -atan2(out.y, out.x) + rng.randf_range(-0.5, 0.5)})
	# the old static hoops are replaced by moving ring courses (DfRings, slice 16n);
	# the hoop helpers stay for tests / tools

	_build_cells()
	_place_ground_units()

## Gatlings on cliff tops, cannons on low ground (valleys), hydras between.
func _place_ground_units() -> void:
	ground_units.clear()
	for sp in spires:
		if sp.get("alien", false) and rng.randf() < 0.6:
			ground_units.append({"kind": "gatling", "pos": sp.pos + Vector3.UP * float(sp.height)})
	for isl in islands:
		if zone_of(isl.pos) != ALIEN_ZONE:
			continue
		for k in int(isl.radius / 90.0) + 1:
			for tries in 12:
				var p := _random_on_island(isl, 0.9)
				var b := band_at(p)
				if b >= 2 and b <= 3 and ground_y(p) < 1.0:
					ground_units.append({"kind": "cannon", "pos": p})
					break
			for tries in 12:
				var p2 := _random_on_island(isl, 0.8)
				var b2 := band_at(p2)
				if b2 >= 3 and b2 <= 5 and ground_y(p2) < 1.0:
					ground_units.append({"kind": "hydra", "pos": p2})
					break

# ------------------------------------------------------------------ arena + zones
static func zone_origin(z: int) -> Vector2:
	return ARENA_MIN + Vector2(QUAD * (z % 2), QUAD * (z / 2))

static func zone_of(p: Vector3) -> int:
	var zx := 1 if p.x >= ARENA_MIN.x + QUAD else 0
	var zz := 1 if p.z >= ARENA_MIN.y + QUAD else 0
	return zx + zz * 2

static func center() -> Vector3:
	var c := (ARENA_MIN + ARENA_MAX) * 0.5
	return Vector3(c.x, 0.0, c.y)

## p moved (flat) to lie at least `margin` m inside the arena walls.
static func clamp_inside(p: Vector3, margin := 0.0) -> Vector3:
	return Vector3(clampf(p.x, ARENA_MIN.x + margin, ARENA_MAX.x - margin), p.y, clampf(p.z, ARENA_MIN.y + margin, ARENA_MAX.y - margin))

static func inside(p: Vector3, margin := 0.0) -> bool:
	return p.x >= ARENA_MIN.x + margin and p.x <= ARENA_MAX.x - margin and p.z >= ARENA_MIN.y + margin and p.z <= ARENA_MAX.y - margin

static func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))

func _build_cells() -> void:
	cells.clear()
	for i in palms.size():
		var k := cell_of(palms[i].pos)
		if not cells.has(k):
			cells[k] = {"palms": [], "spires": []}
		cells[k].palms.append(i)
	for i in spires.size():
		var k := cell_of(spires[i].pos)
		if not cells.has(k):
			cells[k] = {"palms": [], "spires": []}
		cells[k].spires.append(i)

func _random_on_island(isl: Dictionary, frac: float) -> Vector3:
	var a := rng.randf() * TAU
	var r: float = sqrt(rng.randf()) * isl.radius * frac
	return isl.pos + Vector3(cos(a) * r, 0.0, sin(a) * r)

func band_at(p: Vector3) -> int:
	var px := int((p.x - map_origin.x) / MAP_M)
	var pz := int((p.z - map_origin.y) / MAP_M)
	if px < 0 or pz < 0 or px >= MAP_PX or pz >= MAP_PX:
		return 0
	return map_img.get_pixel(px, pz).r8

func is_sea(p: Vector3) -> bool:
	return band_at(p) == 0 and Vector2(p.x - volcano.pos.x, p.z - volcano.pos.z).length() > volcano.radius + 30.0

## Height of whatever solid is under pos: sea/flat ground = 0, spires, the volcano cone.
func ground_y(pos: Vector3) -> float:
	var g := 0.0
	var dv := Vector2(pos.x - volcano.pos.x, pos.z - volcano.pos.z).length()
	if dv < volcano.radius:
		g = volcano.height * (1.0 - dv / volcano.radius)
		if dv < volcano.radius * 0.16:
			g = volcano.height * 0.84 * 0.82   # crater bowl
	var c := cell_of(pos)             # spires (radius <= 24 m) sit in their own cell: 3x3 cells cover them
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var cl: Variant = cells.get(Vector2i(c.x + dx, c.y + dz))
			if cl == null:
				continue
			for i in cl.spires:
				var s: Dictionary = spires[i]
				if s.alive and Vector2(pos.x - s.pos.x, pos.z - s.pos.z).length() < s.radius:
					g = maxf(g, s.height)
	return g

## Asteroid crater: paint scorch + a lava bowl into the map, flatten spires and palms.
func carve(center: Vector3, radius: float, _depth_m := 0.0) -> int:
	var changed := 0
	var c := Vector2((center.x - map_origin.x) / MAP_M, (center.z - map_origin.y) / MAP_M)
	var r := radius / MAP_M
	for z in range(maxi(0, int(c.y - r * 1.25)), mini(MAP_PX, int(c.y + r * 1.25) + 1)):
		for x in range(maxi(0, int(c.x - r * 1.25)), mini(MAP_PX, int(c.x + r * 1.25) + 1)):
			var d := Vector2(x + 0.5, z + 0.5).distance_to(c) / r
			if d > 1.22:
				continue
			var px := map_img.get_pixel(x, z)
			var g := 2 if d < 0.55 else 1
			if d >= 1.0 and px.r8 == 0:
				continue
			map_img.set_pixel(x, z, Color8(1 if d < 0.55 else maxi(px.r8, 2), g, 0, 0))
			changed += 1
	map_tex.update(map_img)
	for s in spires:
		if s.alive and Vector2(s.pos.x - center.x, s.pos.z - center.z).length() < radius:
			s.alive = false
	for p in palms:
		if p.alive and Vector2(p.pos.x - center.x, p.pos.z - center.z).length() < radius * 1.1:
			p.alive = false
	return changed

func palms_alive() -> int:
	var n := 0
	for p in palms:
		if p.alive:
			n += 1
	return n

# ------------------------------------------------------------------ hoops
func _place_hoop(h: Dictionary) -> void:
	var ang := rng.randf() * TAU
	var r := rng.randf_range(150.0, AREA_RADIUS * 0.8)
	var p := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
	p.y = ground_y(p) + rng.randf_range(25.0, 120.0)
	var yaw := rng.randf() * TAU
	h.pos = p
	h.yaw = yaw
	h.normal = Vector3(-sin(yaw), 0, -cos(yaw))
	h.cooldown = 0.0

func hoop_crossed(a: Vector3, b: Vector3) -> int:
	for i in hoops.size():
		var h: Dictionary = hoops[i]
		if h.cooldown > 0.0:
			continue
		var da: float = (a - h.pos).dot(h.normal)
		var db: float = (b - h.pos).dot(h.normal)
		if da * db > 0.0:
			continue
		var t := da / (da - db) if absf(da - db) > 0.0001 else 0.0
		if a.lerp(b, t).distance_to(h.pos) < HOOP_RADIUS:
			return i
	return -1

func use_hoop(i: int) -> void:
	hoops[i].cooldown = 6.0

func tick(dt: float) -> void:
	for h in hoops:
		if h.cooldown > 0.0:
			h.cooldown -= dt
			if h.cooldown <= 0.0:
				_place_hoop(h)
