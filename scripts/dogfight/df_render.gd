class_name DfRender
extends Node2D
## SEGA "Super Scaler" renderer for the dogfight (no meshes).
## - Ground + sky: Mode-7 shader (df_super.gdshader) with camera roll.
## - Every object: a baked pixel-stack sprite (DfSprites). Per frame we project it
##   through the chase camera, pick the frame for the angle we see it from, scale it
##   with nearest filtering (chunky pixels up close) and draw far -> near.
## Runs in a 1/3-resolution viewport, upscaled with hard pixels.

const FOV := 70.0
const NEAR := 2.0

var game: Node
var cam_pos := Vector3(0, 60, 100)
var cam_right := Vector3.RIGHT
var cam_up := Vector3.UP
var cam_fwd := Vector3.FORWARD
var focal := 240.0
var view_size := Vector2(240, 346)
var anchor := Vector2(120, 173)     # screen center (HUD uses it)
var fog_end := 2400.0
# T 2026-11-26: "lights should pierce fog". Light sources (explosions, tracers, lasers, the
# boss beam, nav beacons, holo glow) are not faded by fog; they only fade at light_end, far
# past it. In fog they also get a scatter halo (fog_k = fog density, 0..1).
var light_end := 7200.0
var fog_k := 0.0
var _screen_roll := 0.0
var _bg: ColorRect
var _units: Node2D
var _koi_body: Node2D       # holo koi: translucent core (normal blend), behind everything else
var _koi_glow: Node2D       # holo koi: additive light (halo, rim, scan bands, strand fins)
var _rain: Array = []
var _ash: Array = []
var clouds: Array = []              # {pos, img_i, size}
var sparks: Array = []              # boost sparks {pos, vel, life, t, col}
var _motion: Array = []             # top-speed motion lines (screen space)
var _t := 0.0
const NOZZLE_BACK := 8.5            # m behind the jet center
# Boost flame layers per stage: [radius m, length m, color]  (T's sheet)
const FLAME := [
	[[0.3, 1.2, Color("ffb000")], [0.16, 0.6, Color("fff2c0")]],
	[[0.85, 4.5, Color("ff2a1a")], [0.55, 3.0, Color("ff9a00")], [0.28, 1.4, Color("fff27a")]],
	[[1.05, 7.0, Color("4a1590")], [0.72, 5.0, Color("a040ff")], [0.32, 2.0, Color("f0d0ff")]],
	[[1.35, 10.0, Color("1428c8")], [0.9, 7.0, Color("00d8ff")], [0.38, 2.8, Color("ffffff")]],
]
const SPARK_RATE := [0.0, 0.0, 22.0, 44.0]   # top speed: twice boost 2

static var spr := {}                # name -> DfSprites
static var cloud_tex: Array = []    # ImageTexture
const BLAST_PATHS := {"fire": "res://art/fx/explosion.png", "laser": "res://art/fx/explosion_laser.png", "beam": "res://art/fx/explosion_beam.png"}   # 8 square frames in a row (placeholders: tools/make_fx_art.py)
const BLAST_PATH := "res://art/fx/explosion.png"
const BLAST_FRAMES := 8
static var blast_tex: Texture2D
static var blast_texs := {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg = ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/dogfight/df_super.gdshader")
	_bg.material = m
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_koi_body = Node2D.new()
	add_child(_koi_body)
	_koi_body.draw.connect(_draw_koi_layer.bind(false))
	_koi_glow = Node2D.new()
	var km := CanvasItemMaterial.new()
	km.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_koi_glow.material = km
	add_child(_koi_glow)
	_koi_glow.draw.connect(_draw_koi_layer.bind(true))
	_units = Node2D.new()
	var um := ShaderMaterial.new()
	um.shader = preload("res://scripts/dogfight/df_units.gdshader")   # visor gradient
	_units.material = um
	add_child(_units)
	_units.draw.connect(_draw_units)
	for k in 160:
		_rain.append(Vector2(randf() * 400.0, randf() * 600.0))
	for k in 70:
		_ash.append(Vector2(randf() * 400.0, randf() * 600.0))

## Bake every static sprite once (cached across matches).
static func bake_all() -> void:
	if spr.has("palm"):
		return
	spr["palm"] = DfSprites.bake_art("palm", _palm_model(), 16, [4, 20, 45, 75], 2.6)   # beach v2: tall leaning palms (~22 m)
	spr["spire"] = DfSprites.bake_art("spire", _spire_model(), 8, [4, 20, 45, 75], 5.0)
	spr["volcano"] = DfSprites.bake_art("volcano", _volcano_model(), 1, [2, 12, 25, 45, 75], 6.0)
	spr["ship"] = DfSprites.bake_art("ship", _ship_model(), 16, [8, 25, 50, 80], 2.0)
	spr["hoop"] = DfSprites.bake_art("hoop", _hoop_model(), 16, [-30, 0, 20, 45, 75], 2.0)
	for k in 3:
		cloud_tex.append(ImageTexture.create_from_image(_cloud_image(k)))
	for kind in BLAST_PATHS:
		var path: String = BLAST_PATHS[kind]
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path)) if FileAccess.file_exists(path) else null
		if img != null:
			blast_texs[kind] = ImageTexture.create_from_image(img)
		elif ResourceLoader.exists(path):
			blast_texs[kind] = load(path)
	blast_tex = blast_texs.get("fire")

func setup(g: Node) -> void:
	trails.clear()
	koi.build(randi() % 100000)
	_koi_threats.clear()
	g.weather.lightning.connect(_on_koi_lightning)
	g.weather.asteroid_impact.connect(_on_koi_impact)
	game = g
	bake_all()
	var m: ShaderMaterial = _bg.material
	m.set_shader_parameter("world_map", g.world.map_tex)
	m.set_shader_parameter("map_origin", g.world.map_origin)
	m.set_shader_parameter("map_m", DfWorld.MAP_M)
	m.set_shader_parameter("map_px", float(DfWorld.MAP_PX))
	clouds.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for k in 46:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * DfWorld.AREA_RADIUS * 1.3
		clouds.append({"pos": Vector3(cos(a) * r, rng.randf_range(150.0, 330.0), sin(a) * r), "img": k % 3, "size": rng.randf_range(2.6, 4.2)})

func clear() -> void:
	game = null

# ------------------------------------------------------------------ camera
func set_camera(pos: Vector3, target: Vector3, roll: float, fov_deg := FOV) -> void:
	cam_pos = pos
	var f := (target - pos).normalized()
	if absf(f.y) > 0.98:
		f = (f + Vector3(0, 0, -0.05)).normalized()
	var r := f.cross(Vector3.UP).normalized()
	var u := r.cross(f)
	r = r.rotated(f, roll)
	u = u.rotated(f, roll)
	cam_fwd = f
	cam_right = r
	cam_up = u
	focal = (view_size.y * 0.5) / tan(deg_to_rad(fov_deg) * 0.5)
	_screen_roll = atan2(Vector3.UP.dot(cam_right), Vector3.UP.dot(cam_up))

## Camera from a position, a look-at point and an "up" hint (any attitude: loops, inverted).
func set_camera_frame(pos: Vector3, target: Vector3, up_hint: Vector3, fov_deg := FOV) -> void:
	cam_pos = pos
	var f := (target - pos).normalized()
	var r := f.cross(up_hint)
	if r.length() < 0.01:
		r = f.cross(cam_up if absf(f.dot(cam_up)) < 0.99 else Vector3.FORWARD)
	r = r.normalized()
	cam_fwd = f
	cam_right = r
	cam_up = r.cross(f)
	focal = (view_size.y * 0.5) / tan(deg_to_rad(fov_deg) * 0.5)
	_screen_roll = atan2(Vector3.UP.dot(cam_right), Vector3.UP.dot(cam_up))

## (screen x, screen y, depth). depth <= 0 = behind the camera.
func project(p: Vector3) -> Vector3:
	var d := p - cam_pos
	var z := d.dot(cam_fwd)
	if z < NEAR:
		return Vector3(0, 0, -1)
	return Vector3(anchor.x + d.dot(cam_right) * focal / z, anchor.y - d.dot(cam_up) * focal / z, z)

## For the HUD: screen point, or a far point in the right direction when behind.
func world_to_screen(p: Vector3) -> Vector2:
	var pr := project(p)
	if pr.z > 0.0:
		return Vector2(pr.x, pr.y)
	var d := p - cam_pos
	return anchor + Vector2(d.dot(cam_right), -d.dot(cam_up)).normalized() * 9999.0

func on_screen(s: Vector2, margin := 0.0) -> bool:
	return Rect2(Vector2.ZERO, view_size).grow(margin).has_point(s)

# ------------------------------------------------------------------ frame
func _process(_d: float) -> void:
	if game == null or game.world == null:
		return
	_t += _d
	_step_sparks(_d)
	_step_trails(_d)
	_step_koi(_d)
	view_size = get_viewport_rect().size
	anchor = view_size * 0.5
	_bg.size = view_size
	var w: DfWeather = game.weather
	var fogc: Color = w.cur.fog
	fog_end = lerpf(2600.0, 700.0, fogc.a * fogc.a)
	light_end = maxf(3200.0, fog_end * 3.0)
	fog_k = clampf(fogc.a, 0.0, 1.0)
	var m: ShaderMaterial = _bg.material
	m.set_shader_parameter("cam_pos", cam_pos)
	m.set_shader_parameter("cam_right", cam_right)
	m.set_shader_parameter("cam_up", cam_up)
	m.set_shader_parameter("cam_fwd", cam_fwd)
	m.set_shader_parameter("focal", focal)
	m.set_shader_parameter("view_size", view_size)
	m.set_shader_parameter("sea_deep", w.cur.deep)
	m.set_shader_parameter("sea", w.cur.sea)
	m.set_shader_parameter("sea_light", w.cur.light)
	m.set_shader_parameter("sky_top", w.cur.sky_top)
	m.set_shader_parameter("sky_mid", w.cur.sky_mid)
	m.set_shader_parameter("horizon", w.cur.horizon)
	m.set_shader_parameter("fog", fogc)
	m.set_shader_parameter("fog_end", fog_end)
	m.set_shader_parameter("ambient", w.cur.get("ambient", Color.WHITE))
	_units.queue_redraw()
	_koi_body.queue_redraw()
	_koi_glow.queue_redraw()

# ------------------------------------------------------------------ contrails
## Two wingtip trails per jet. Faint in normal flight; bright when you pull hard, roll or
## drift (orange / blue once the drift is charged), cyan at top boost.
const TRAIL_LIFE := 0.9          # player
const TRAIL_LIFE_ENEMY := 1.4    # enemies: longer, so you can read where they came from
const TRAIL_TIP := 6.4          # m from the centre line (wingspan ~14 m)
var trails := {}                # plane instance id -> Array of {l, r, t, a, col}
var koi := DfKoi.new()          # giant sky koi (scenery)

func _step_trails(dt: float) -> void:
	var planes: Array = []
	if game.player.visible and game.player.alive and game.state != "crash":
		planes.append(game.player)
	for e in game.enemies:
		if e.alive:
			planes.append(e)
	var live := {}
	for pl in planes:
		var key: int = pl.get_instance_id()
		live[key] = true
		if not trails.has(key):
			trails[key] = []
		var b: Basis = pl.vis_basis()
		var back: Vector3 = pl.position + b.z * 2.0
		var a := 0.55                    # fighters: white vapor
		var col := Color.WHITE
		var life := TRAIL_LIFE_ENEMY
		if pl.kind == "kamikaze":
			# kamikazes: thick smoke that always contrasts with the sky (dark by day,
			# pale ash in the storm, the eruption and at night)
			a = 0.7
			col = Color("3a2f38") if game.weather.cur.sky_mid.get_luminance() > 0.42 else Color("f1e4d2")
		if pl == game.player:
			life = TRAIL_LIFE
			a = 0.24
			if absf(pl.pitch_in) > 0.5 or pl.rolling():
				a = 0.6
			if pl.drift:
				a = 0.75
				var tier: int = pl.drift_tier()
				col = Color.WHITE if tier == 0 else (Color("ffb000") if tier == 1 else Color("5aa0ff"))
			elif pl.boost_stage() == 3:
				a = 0.55
				col = Color("7ff3ff")
		trails[key].append({"l": back - b.x * TRAIL_TIP, "r": back + b.x * TRAIL_TIP, "t": 0.0, "a": a, "col": col, "life": life})
	for key in trails.keys():
		var keep: Array = []
		for p in trails[key]:
			p.t += dt
			if p.t < float(p.get("life", TRAIL_LIFE)):
				keep.append(p)
		if keep.is_empty() and not live.has(key):
			trails.erase(key)
		else:
			trails[key] = keep

func _queue_trails(list: Array) -> void:
	for key in trails:
		var pts: Array = trails[key]
		for i in range(pts.size() - 1):
			var p0: Dictionary = pts[i]
			var p1: Dictionary = pts[i + 1]
			for side in ["l", "r"]:
				var a := project(p0[side])
				var b := project(p1[side])
				if a.z <= 0.5 or b.z <= 0.5 or a.z > fog_end:
					continue
				var fade := 1.0 - float(p0.t) / float(p0.get("life", TRAIL_LIFE))
				var col: Color = p1.col
				col.a = float(p1.a) * fade * _fade(a.z) * smoothstep(8.0, 28.0, a.z)   # thin out next to the lens
				var w := clampf(focal / ((a.z + b.z) * 0.5) * (1.6 if p1.col != Color.WHITE and key != game.player.get_instance_id() else 0.9), 1.0, 4.0)
				list.append([(a.z + b.z) * 0.5, "trail", Vector2(a.x, a.y), Vector2(b.x, b.y), col, w])

# ------------------------------------------------------------------ sky koi
var _koi_threats: Array = []     # queued by signals (lightning, asteroid impact)

func _step_koi(dt: float) -> void:
	var threats: Array = _koi_threats
	_koi_threats = []
	for bl in game.fx.blasts:
		if float(bl.t) >= 0.0 and not bl.has("koi"):
			bl["koi"] = true
			threats.append({"pos": bl.pos, "power": 2.6 if bl.get("kind", "fire") == "laser" else clampf(float(bl.size) / 1.2, 0.6, 2.0)})
	var w: DfWeather = game.weather
	if w.asteroid_active:
		threats.append({"pos": w.asteroid_position(), "power": 1.6})
	koi.step(dt, w.preset, threats, game.world.volcano.pos)

func _on_koi_lightning() -> void:
	# a strike somewhere in the sky near you: the koi close to it flinch and scatter
	var p: Vector3 = game.player.position
	_koi_threats.append({"pos": Vector3(p.x + randf_range(-700, 700), 470.0, p.z + randf_range(-700, 700)), "power": 1.3})

func _on_koi_impact(point: Vector3) -> void:
	_koi_threats.append({"pos": point + Vector3.UP * 300.0, "power": 4.0})
## The koi swim above everything (390-540 m), so they draw on their own two layers behind
## the jets and clouds: far to near, core first (normal blend), then light (additive).
func _draw_koi_layer(glow: bool) -> void:
	if game == null or game.world == null:
		return
	var ci: CanvasItem = _koi_glow if glow else _koi_body
	var items: Array = []
	for f in koi.fish:
		var sp := koi.spine(f, _t)
		var pr: Array = []
		var seen := false
		var ok := true
		for p in sp:
			var a := project(p)
			if a.z <= 0.0:
				ok = false
				break
			pr.append(a)
			seen = seen or on_screen(Vector2(a.x, a.y), 260.0)
		if ok and seen:
			items.append([pr[SEGS_HALF].z, f, pr])
	items.sort_custom(func(x, y): return x[0] > y[0])
	for it in items:
		_draw_holo_koi(ci, it[1], it[2], glow)

const SEGS_HALF := DfKoi.SEGS / 2

## 0 = bright day sky .. 1 = night. Steep: the storm and the night both count as dark.
func koi_dark() -> float:
	var lum := Color(game.weather.cur.sky_mid).get_luminance()
	return 1.0 - clampf((lum - 0.12) / 0.4, 0.0, 1.0)

## Holo koi (T's reference: glowing hologram koi with feathery betta fins).
## Two passes: glow=false draws on the normal-blend layer (the colored-glass body, fin
## membranes and markings; strongest by day), glow=true on the ADDITIVE layer (halo,
## bright edge light, scale lattice, scan bands, glowing fin rays, eyes, whiskers,
## sparkles; strongest at night, when it turns to neon).
func _draw_holo_koi(ci: CanvasItem, f: Dictionary, pr: Array, glow: bool) -> void:
	var n := pr.size()
	var zm: float = pr[n / 2].z
	var fade := 1.0 - smoothstep(fog_end * 0.75, fog_end * 1.2, zm)
	if glow:                          # the hologram is light: its glow layer pierces fog
		fade = maxf(fade, 0.75 * _light_fade(zm))
	if fade <= 0.02:
		return
	var haze: Color = game.weather.cur.horizon
	var dark := koi_dark()
	var hz := clampf(zm / (fog_end * 1.2), 0.0, 1.0) * 0.25 * (1.0 - 0.8 * dark)
	var pal: Dictionary = f.pal
	var edge: Color = Color(pal.edge).lerp(haze, hz)
	var finc: Color = Color(pal.fin).lerp(haze, hz)
	var t := _t
	var ph: float = f.phase
	var wig: float = f.wig
	# --- spine in screen space
	var pts := PackedVector2Array()
	var rad: Array = []
	for i in n:
		pts.append(Vector2(pr[i].x, pr[i].y))
		rad.append(maxf(1.0, DfKoi.width(f, i) * focal / pr[i].z))
	var side: Array = []
	for i in n:
		var tg: Vector2 = pts[maxi(i - 1, 0)] - pts[mini(i + 1, n - 1)]
		tg = tg.normalized() if tg.length() > 0.001 else Vector2.RIGHT
		side.append(Vector2(-tg.y, tg.x))
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		left.append(pts[i] + side[i] * rad[i])
		right.append(pts[i] - side[i] * rad[i])
	var len_px: float = pts[0].distance_to(pts[n - 1])
	var lod := 2 if len_px > 70.0 else (1 if len_px > 22.0 else 0)
	var hf: Vector2 = (pts[0] - pts[1]).normalized()
	var back: Vector2 = (pts[n - 1] - pts[n - 3]).normalized()
	var glitch := fmod(t * 0.7 + ph, 4.0) < 0.08
	# --- fins first (behind the body). Each fin = a fan of curved rays + membrane between.
	var fins: Array = []    # [root, dirs, lens, wave, phase, membrane_alpha]
	var tl: float = rad[3] * 2.6
	var ntail := 13 if lod == 2 else (7 if lod == 1 else 4)
	var tdirs: Array = []
	var tlens: Array = []
	for k in ntail:
		var u := float(k) / (ntail - 1)
		var a := lerpf(-1.05, 1.05, u)
		tdirs.append(back.rotated(a * 0.85 + sin(wig - 2.5) * 0.15))
		var fork := 1.0 - 0.35 * exp(-pow(a / 0.25, 2.0))         # a soft fork in the middle
		tlens.append(tl * (1.0 + 0.25 * absf(a)) * fork * (0.9 + 0.1 * sin(k * 2.3)))
	fins.append([pts[n - 2], tdirs, tlens, 0.22, wig * 1.1 + ph, 1.0])
	if lod >= 1:
		for sgn in [-1.0, 1.0]:
			var pd: Array = []
			var pl: Array = []
			var np := 6 if lod == 2 else 3
			for k in np:
				var a := lerpf(-0.45, 0.45, float(k) / (np - 1))
				pd.append((side[4] * sgn * 0.7 - hf * 0.7).normalized().rotated(a * sgn))
				pl.append(rad[4] * (1.9 + 0.35 * k / np))
			fins.append([pts[4] + side[4] * sgn * rad[4] * 0.75, pd, pl, 0.3, wig * 0.9 + sgn, 0.8])
			if lod == 2:
				var vd: Array = []
				var vl: Array = []
				for k in 4:
					vd.append((side[10] * sgn * 0.55 + back * 0.85).normalized().rotated(0.18 * k * sgn))
					vl.append(rad[10] * (1.6 + 0.2 * k))
				fins.append([pts[10] + side[10] * sgn * rad[10] * 0.7, vd, vl, 0.3, wig - sgn, 0.6])
	for fn in fins:
		_fin_fan(ci, fn[0], fn[1], fn[2], fn[3], fn[4], finc, edge, fn[5] * fade, dark, glow)
	if lod == 2:   # dorsal crest: short swept strands along the back
		for i in range(3, 11):
			var dir: Vector2 = (side[i] * 0.7 + back * 0.7).normalized()
			if glow:
				_strand(ci, pts[i] + side[i] * rad[i] * 0.8, dir, rad[i] * (0.8 + 0.4 * sin(i * 0.9 + ph)), 0.25, wig * 1.2 - i * 0.4, Color(finc, 0.4 * fade * (0.6 + dark)), 4)
	# --- body
	if not glow:
		# colored glass: one smooth hue, solid by day, thin at night (the light takes over)
		for i in n - 1:
			var c0 := DfKoi.color(f, i, t).lerp(haze, hz)
			var c1 := DfKoi.color(f, i + 1, t).lerp(haze, hz)
			var a := lerpf(0.8, 0.14, dark) * (0.85 + 0.15 * sin(t * 2.2 - i * 0.7 + ph)) * fade
			c0.a = a
			c1.a = a
			var o: Vector2 = side[i] * 2.0 if glitch and i > 5 and i < 10 else Vector2.ZERO
			ci.draw_primitive(PackedVector2Array([left[i] + o, left[i + 1] + o, right[i + 1] + o, right[i] + o]), PackedColorArray([c0, c1, c1, c0]), PackedVector2Array())
		var hc := DfKoi.color(f, 0, t).lerp(haze, hz)
		hc.a = lerpf(0.8, 0.14, dark) * fade
		ci.draw_circle(pts[0] + hf * rad[0] * 0.25, rad[0] * 0.98, hc)
		# markings: soft patches on the back (edge color)
		if lod >= 1:
			for i in range(1, n - 4):
				for u in [-0.4, 0.15]:
					var pw := DfKoi.patch(f, i, u)
					if pw > 0.0:
						ci.draw_circle(pts[i] + side[i] * rad[i] * u, rad[i] * 0.42 * pw, Color(edge, 0.35 * pw * fade * (1.0 - 0.6 * dark)))
		# a darker outline by day keeps the silhouette readable on a bright sky
		var ol := Color(Color(pal.body).darkened(0.45), (1.0 - dark) * 0.7 * fade)
		ci.draw_polyline(left, ol, 1.0)
		ci.draw_polyline(right, ol, 1.0)
		ci.draw_arc(pts[0] + hf * rad[0] * 0.25, rad[0] * 0.98, hf.angle() - PI * 0.5, hf.angle() + PI * 0.5, 10, ol, 1.0)
		if rad[0] > 3.0:   # pupils
			for sgn in [-1.0, 1.0]:
				ci.draw_circle(pts[0] + hf * rad[0] * 0.45 + side[0] * sgn * rad[0] * 0.52, maxf(1.0, rad[0] * 0.14), Color(0.02, 0.02, 0.06, 0.85 * fade))
		return
	# ===================== additive light =====================
	var gl := fade * lerpf(0.3, 1.9, dark)           # neon at night, only a gleam by day (additive washes colors out on a bright sky)
	# halo: soft glow that fades from the body edge out to nothing (a cheap bloom);
	# wider and stronger at night. Flat-alpha halos looked like a muddy box on a black sky.
	var hw := lerpf(1.6, 2.6, dark)
	for i in n - 1:
		var c := DfKoi.color(f, i, t).lerp(haze, hz)
		c.a = lerpf(0.10, 0.28, dark) * gl
		var c0 := Color(c, 0.0)
		for sgn in [1.0, -1.0]:
			var e0: Vector2 = pts[i] + side[i] * rad[i] * sgn
			var e1: Vector2 = pts[i + 1] + side[i + 1] * rad[i + 1] * sgn
			var h0: Vector2 = pts[i] + side[i] * rad[i] * hw * sgn
			var h1: Vector2 = pts[i + 1] + side[i + 1] * rad[i + 1] * hw * sgn
			ci.draw_primitive(PackedVector2Array([e0, e1, h1, h0]), PackedColorArray([c, c, c0, c0]), PackedVector2Array())
	# head glow
	var hgc := Color(DfKoi.color(f, 0, t), lerpf(0.10, 0.28, dark) * gl)
	var hpts := PackedVector2Array()
	var hcols := PackedColorArray()
	for k in 9:
		var ang := hf.angle() - PI * 0.5 + PI * k / 8.0
		hpts.append(pts[0] + hf * rad[0] * 0.25 + Vector2(cos(ang), sin(ang)) * rad[0])
	for k in 8:
		var a0: Vector2 = hpts[k]
		var a1: Vector2 = hpts[k + 1]
		var c2: Vector2 = pts[0] + hf * rad[0] * 0.25
		ci.draw_primitive(PackedVector2Array([a0, a1, c2 + (a1 - c2) * hw, c2 + (a0 - c2) * hw]), PackedColorArray([hgc, hgc, Color(hgc, 0.0), Color(hgc, 0.0)]), PackedVector2Array())
	# body light: dim in the middle, BRIGHT at the edges (a hologram's fresnel rim)
	for i in n - 1:
		var c := DfKoi.color(f, i, t).lerp(haze, hz)
		var mid := Color(c, lerpf(0.06, 0.55, dark) * gl)      # saturated body light (the neon core)
		var rimc := Color(edge.lerp(c, 0.35 * (1.0 - dark)), 0.8 * gl)
		var band := fmod((pts[i].y + pts[i + 1].y) * 0.5 + t * 22.0 + ph * 10.0, 9.0) < 2.0
		if band:
			mid.a += 0.18 * gl
		var o: Vector2 = side[i] * 2.0 if glitch and i > 5 and i < 10 else Vector2.ZERO
		for sgn in [1.0, -1.0]:
			var e0: Vector2 = pts[i] + side[i] * rad[i] * sgn + o
			var e1: Vector2 = pts[i + 1] + side[i + 1] * rad[i + 1] * sgn + o
			ci.draw_primitive(PackedVector2Array([e0, e1, pts[i + 1] + o, pts[i] + o]), PackedColorArray([rimc, rimc, mid, mid]), PackedVector2Array())
	# scale lattice: little chevrons pointing at the head, twinkling in a wave
	if lod >= 1:
		for i in range(2, n - 4):
			for u in ([-0.5, 0.0, 0.5] if lod == 2 else [0.0]):
				var tw := 0.5 + 0.5 * sin(t * 2.6 - i * 0.8 + u * 4.0 + ph)
				if tw < 0.35:
					continue
				var cpt: Vector2 = pts[i] + side[i] * rad[i] * (u + (0.25 if i % 2 else 0.0)) * 0.9
				var s2: float = maxf(1.0, rad[i] * 0.18)
				var sc := Color(edge, 0.45 * tw * gl)
				ci.draw_line(cpt + side[i] * s2 - hf * s2 * 0.6, cpt + hf * s2 * 0.4, sc, 1.0)
				ci.draw_line(cpt - side[i] * s2 - hf * s2 * 0.6, cpt + hf * s2 * 0.4, sc, 1.0)
	# rim lines + spine glow
	var rim := Color(edge, 0.9 * gl)
	ci.draw_polyline(left, rim, 1.0)
	ci.draw_polyline(right, rim, 1.0)
	ci.draw_polyline(pts.slice(1, n - 3), Color(edge, 0.2 * gl), 1.0)
	# head: snout rim, gill arc, glowing eye rings, whiskers
	var hc2: Vector2 = pts[0] + hf * rad[0] * 0.25
	ci.draw_arc(hc2, rad[0] * 0.98, hf.angle() - PI * 0.5, hf.angle() + PI * 0.5, 12, rim, 1.0)
	if rad[0] > 3.0:
		ci.draw_arc(pts[1] + hf * rad[1] * 0.1, rad[1] * 0.85, hf.angle() - 1.2, hf.angle() + 1.2, 8, Color(edge, 0.45 * gl), 1.0)   # gill line
		for sgn in [-1.0, 1.0]:
			var ec: Vector2 = pts[0] + hf * rad[0] * 0.45 + side[0] * sgn * rad[0] * 0.52
			ci.draw_arc(ec, maxf(1.5, rad[0] * 0.25), 0.0, TAU, 10, Color(edge, 1.0 * gl), 1.0)
			ci.draw_circle(ec, maxf(1.0, rad[0] * 0.08), Color(1, 1, 1, 0.8 * gl))
		for sgn in [-1.0, 1.0]:     # barbels: a long and a short whisker each side
			var wroot: Vector2 = pts[0] + hf * rad[0] * 1.1 + side[0] * sgn * rad[0] * 0.3
			_strand(ci, wroot, (side[0] * sgn * 0.45 - hf * 0.3 + hf * 0.15).normalized(), rad[0] * 1.9, 0.3, t * 2.0 + sgn, Color(edge, 0.8 * gl), 5)
			_strand(ci, wroot, (side[0] * sgn * 0.8 + hf * 0.2).normalized(), rad[0] * 0.9, 0.2, t * 2.3 - sgn, Color(edge, 0.6 * gl), 3)
	# sparkles shed from the fins, drifting back and fading
	if lod == 2:
		for k in 14:
			var life := fmod(t * 0.7 + k * 0.137 + ph, 1.0)
			var src: Vector2 = pts[n - 2] if k % 2 else pts[4] + side[4] * (1.0 if k % 4 == 0 else -1.0) * rad[4] * 1.4
			var sp3: Vector2 = src + back.rotated(sin(k * 3.1) * 0.9) * tl * (0.4 + life * 1.6) + side[n - 1] * sin(k * 7.7 + t) * 4.0
			ci.draw_rect(Rect2(sp3.round(), Vector2.ONE * (2.0 if k % 3 == 0 else 1.0)), Color(edge, (1.0 - life) * 0.9 * gl))
	if glitch:
		for i in range(6, 10):
			ci.draw_line(left[i] + side[i] * 2.0, right[i] + side[i] * 2.0, Color(1, 1, 1, 0.35 * gl), 1.0)

## One fin: rays fan out from root along dirs; each ray is a wavy line (the wave lags down
## the ray so the fin flows). Normal layer: translucent membrane between the rays.
## Additive layer: a faint membrane glow + bright rays fading to the tips + a lit edge.
func _fin_fan(ci: CanvasItem, root: Vector2, dirs: Array, lens: Array, wave: float, phase: float, finc: Color, edge: Color, a: float, dark: float, glow: bool) -> void:
	var nr := dirs.size()
	var segs := 5
	var rays: Array = []
	for k in nr:
		var d: Vector2 = dirs[k]
		var perp := Vector2(-d.y, d.x)
		var ln: float = lens[k]
		var pts := PackedVector2Array()
		for s in segs + 1:
			var u := float(s) / segs
			pts.append(root + d * ln * u + perp * sin(phase - u * 3.0 + k * 0.25) * wave * u * u * ln)
		rays.append(pts)
	for k in nr - 1:
		var r0: PackedVector2Array = rays[k]
		var r1: PackedVector2Array = rays[k + 1]
		for s in segs:
			var u0 := float(s) / segs
			var u1 := float(s + 1) / segs
			var m0: float
			var m1: float
			if glow:
				m0 = 0.10 * (1.0 - u0 * 0.6)
				m1 = 0.10 * (1.0 - u1 * 0.6)
			else:
				m0 = lerpf(0.34, 0.1, dark) * (1.0 - u0 * 0.7)
				m1 = lerpf(0.34, 0.1, dark) * (1.0 - u1 * 0.7)
			var c0 := Color(finc, m0 * a * (1.0 + dark if glow else 1.0))
			var c1 := Color(finc, m1 * a * (1.0 + dark if glow else 1.0))
			ci.draw_primitive(PackedVector2Array([r0[s], r0[s + 1], r1[s + 1], r1[s]]), PackedColorArray([c0, c1, c1, c0]), PackedVector2Array())
	if not glow:
		return
	var ga := a * lerpf(0.5, 1.3, dark)
	for k in nr:
		var cs := PackedColorArray()
		var r: PackedVector2Array = rays[k]
		var edge_ray: bool = k == 0 or k == nr - 1
		for s in segs + 1:
			var u := float(s) / segs
			cs.append(Color(edge if edge_ray else finc, (0.75 if edge_ray else 0.5) * ga * (1.0 - u * 0.8)))
		ci.draw_polyline_colors(r, cs, 1.0)
	var tips := PackedVector2Array()     # the fin's outer edge
	for k in nr:
		tips.append(rays[k][segs])
	ci.draw_polyline(tips, Color(edge, 0.28 * ga), 1.0)

## One glowing fin strand: a wavy line that thins and fades toward its tip.
func _strand(ci: CanvasItem, root: Vector2, dir: Vector2, length: float, wave: float, phase: float, col: Color, segs: int) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var p := PackedVector2Array()
	var cs := PackedColorArray()
	for k in segs + 1:
		var u := float(k) / segs
		p.append(root + dir * length * u + perp * sin(phase - u * 3.2) * wave * u * u * length)
		var c := col
		c.a = col.a * (1.0 - u * 0.85)
		cs.append(c)
	ci.draw_polyline_colors(p, cs, 1.0)

# ------------------------------------------------------------------ QUAD GUNSHIP boss
const ROTOR_HUBS := [Vector3(-15, 16, 14) * DfPlane.BOSS_PX, Vector3(15, 16, 14) * DfPlane.BOSS_PX,
	Vector3(-15, 16, -14) * DfPlane.BOSS_PX, Vector3(15, 16, -14) * DfPlane.BOSS_PX]   # art px -> m, up from the bottom slice
const ROTOR_R := 6.8 * DfPlane.BOSS_PX
const BOSS_BEAM_W := 10.0          # m: the beam's half width at the body (yours is ~1.4)

## Rotors (blur discs + 2 blades each, spinning), the cannon glow (grows with the charge), the
## lock-on line + target ring, and the beam (split into depth-sorted pieces).
func _queue_boss(list: Array, b: DfPlane) -> void:
	var pr := project(b.position)
	if pr.z <= 1.0 or pr.z > light_end:
		return
	for i in ROTOR_HUBS.size():
		var hub: Vector3 = b.position + b.basis * (ROTOR_HUBS[i] as Vector3)
		var hz := project(hub)
		if hz.z > 1.0 and hz.z < fog_end:
			list.append([hz.z - 3.0, "rotor", b, i])
		# nav beacon on the outer rim of each duct: left red, right cyan, blinking in turn
		var hubv: Vector3 = ROTOR_HUBS[i]
		var rim: Vector3 = b.position + b.basis * (hubv + Vector3(signf(hubv.x) * (ROTOR_R + 1.5), -1.0, 0.0))
		var rz := project(rim)
		var alive_r: bool = float(game.boss_st.get("rotors", [1, 1, 1, 1])[i]) > 0.0
		if rz.z > 1.0 and alive_r:
			list.append([rz.z - 5.0, "navlight", rz, i])
	var bs: Dictionary = game.boss_st
	if bs.is_empty():
		return
	var m: Vector3 = game.boss_muzzle()
	var mz := project(m)
	var ch: float = bs.charge
	if mz.z > 1.0 and (ch > 0.2 or bs.phase == "fire"):
		list.append([mz.z - 4.0, "bossglow", mz, ch, bs.phase])
	if bs.phase == "lock":
		list.append([1.0, "bosslock", m, bs.aim])
	var parts: Array = bs.get("parts", [])
	if bs.phase == "fire" or (bs.phase == "cool" and not parts.is_empty()):
		# the bent beam: one depth-sorted piece per pair of points, clipped at the near plane
		# (so a beam passing right by the camera fills the screen instead of vanishing)
		var pts: PackedVector3Array = game.boss_beam_pts()
		var grow := clampf(float(bs.t) / 0.12, 0.0, 1.0) if bs.phase == "fire" else 1.0
		for k in pts.size() - 1:
			var a3 := pts[k]
			var b3 := pts[k + 1]
			var pa := project(a3)
			var pb := project(b3)
			if pa.z <= 2.0 and pb.z <= 2.0:
				continue
			if pa.z <= 2.0:
				pa = project(a3.lerp(b3, (2.5 - pa.z) / (pb.z - pa.z)))
			elif pb.z <= 2.0:
				pb = project(b3.lerp(a3, (2.5 - pb.z) / (pa.z - pb.z)))
			if pa.z > 1.0 and pb.z > 1.0:
				list.append([(pa.z + pb.z) * 0.5, "bossbeam", pa, pb, grow])
		# the beam's head while its light is still flying out (not yet on the ground)
		if not parts.is_empty():
			var p0: Dictionary = parts[parts.size() - 1]
			var flown: float = (float(bs.beam_t) - float(p0.t0)) * float(game.BOSS_BEAM_SPEED)
			if flown < float(p0.len) - 0.01 and pts.size() > 0:
				var hz := project(pts[pts.size() - 1])
				if hz.z > 1.0:
					list.append([hz.z - 2.0, "bossglow", hz, 0.7, "fire"])

func _draw_rotor(ci: CanvasItem, b: DfPlane, i: int) -> void:
	var hub: Vector3 = b.position + b.basis * (ROTOR_HUBS[i] as Vector3)
	var ax: Vector3 = b.basis.x
	var az: Vector3 = b.basis.z
	var disc := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		var p := project(hub + (ax * cos(a) + az * sin(a)) * ROTOR_R)
		if p.z <= 1.0:
			return
		disc.append(Vector2(p.x, p.y))
	var fade := _fade(project(hub).z)
	var rotors: Array = game.boss_st.get("rotors", [1, 1, 1, 1])
	if float(rotors[i]) <= 0.0:               # shot off: a dark, still, broken disc
		ci.draw_colored_polygon(disc, Color(0.08, 0.06, 0.08, 0.55 * fade))
		var a0 := 0.7 + i
		var p0 := project(hub + (ax * cos(a0) + az * sin(a0)) * ROTOR_R * 0.7)
		var p1 := project(hub - (ax * cos(a0) + az * sin(a0)) * ROTOR_R * 0.3)
		ci.draw_line(Vector2(p0.x, p0.y), Vector2(p1.x, p1.y), Color(0.3, 0.3, 0.35, fade), 1.0)
		return
	ci.draw_colored_polygon(disc, Color(0.75, 0.8, 0.9, 0.18 * fade))
	var spin := _t * (38.0 if i % 2 == 0 else -38.0) + i
	for k in 2:
		var a := spin + PI * 0.5 * k
		var p0 := project(hub + (ax * cos(a) + az * sin(a)) * ROTOR_R)
		var p1 := project(hub - (ax * cos(a) + az * sin(a)) * ROTOR_R)
		ci.draw_line(Vector2(p0.x, p0.y), Vector2(p1.x, p1.y), Color(0.9, 0.93, 1.0, 0.75 * fade), 1.0)
		var a2 := a - 0.25                               # motion smear
		var q0 := project(hub + (ax * cos(a2) + az * sin(a2)) * ROTOR_R)
		var q1 := project(hub - (ax * cos(a2) + az * sin(a2)) * ROTOR_R)
		ci.draw_line(Vector2(q0.x, q0.y), Vector2(q1.x, q1.y), Color(0.9, 0.93, 1.0, 0.25 * fade), 1.0)

func _draw_navlight(ci: CanvasItem, p: Vector3, i: int) -> void:
	var side_red := i % 2 == 0                         # hubs 0/2 are on the left (-x)
	var col := Color(1.0, 0.15, 0.2) if side_red else Color(0.3, 0.9, 1.0)
	var on := fmod(_t * 1.6 + (0.5 if i >= 2 else 0.0), 1.0) < 0.35     # front pair, then back pair
	var c2 := Vector2(p.x, p.y)
	var lf := _light_fade(p.z)
	var r := maxf(1.0, focal / p.z * 1.6)
	_halo(ci, c2, r * 3.0, Color(col, (1.0 if on else 0.25) * lf))
	if on:
		ci.draw_circle(c2, r * 1.8, Color(col, 0.35 * lf))
		ci.draw_rect(Rect2(c2.round() - Vector2.ONE, Vector2(2, 2)), Color(1, 1, 1, lf))
	else:
		ci.draw_rect(Rect2(c2.round() - Vector2(0.5, 0.5), Vector2(1, 1)), Color(col, 0.6 * lf))

func _draw_boss_glow(ci: CanvasItem, mz: Vector3, ch: float, phase: String) -> void:
	var c2 := Vector2(mz.x, mz.y)
	var r := focal / mz.z * lerpf(0.8, 3.6, ch) * (1.0 + 0.15 * sin(_t * (30.0 if phase == "lock" else 12.0)))
	if phase == "fire":
		r = focal / mz.z * 4.5 * (1.0 + 0.1 * sin(_t * 40.0))
	_halo(ci, c2, r * 2.0, Color(0.3, 0.7, 1.0, 1.0))
	ci.draw_circle(c2, r * 1.6, Color(0.2, 0.55, 1.0, 0.22))
	ci.draw_circle(c2, r, Color(0.45, 0.85, 1.0, 0.7))
	ci.draw_circle(c2, r * 0.45, Color(0.95, 1.0, 1.0, 0.95))

func _draw_boss_lock(ci: CanvasItem, m: Vector3, aim: Vector3) -> void:
	var a := project(m)
	var b := project(aim)
	if a.z <= 1.0 or b.z <= 1.0:
		return
	var on := fmod(_t * 8.0, 1.0) < 0.6
	ci.draw_line(Vector2(a.x, a.y), Vector2(b.x, b.y), Color(0.5, 0.9, 1.0, 0.85 if on else 0.35), 1.0)
	var rr := clampf(focal / b.z * 16.0, 4.0, 40.0)
	ci.draw_arc(Vector2(b.x, b.y), rr, 0.0, TAU, 20, Color(0.5, 0.9, 1.0, 0.9 if on else 0.4), 1.0)
	ci.draw_arc(Vector2(b.x, b.y), rr * 0.5, _t * 4.0, _t * 4.0 + PI, 10, Color(1, 1, 1, 0.8), 1.0)

## One piece of the beam: a quad whose width follows perspective at each end. Outer glow,
## cyan body, white core, plus a flicker. Bigger than the player's laser (9 m vs ~1.4 m).
func _draw_boss_beam(ci: CanvasItem, pa: Vector3, pb: Vector3, grow: float) -> void:
	var a := Vector2(pa.x, pa.y)
	var b := Vector2(pb.x, pb.y)
	var d := b - a
	if d.length() < 0.5:
		return
	var n := Vector2(-d.y, d.x).normalized()
	var wa := focal / pa.z * BOSS_BEAM_W
	var wb := focal / pb.z * BOSS_BEAM_W
	var fl := (0.85 + 0.15 * sin(_t * 47.0)) * grow
	if fog_k > 0.05:                                     # fog scatters the beam into a wide blue haze
		var hk := 2.2 + 2.6 * fog_k
		var hc := Color(0.1, 0.4, 1.0, 0.14 * fog_k * grow)
		ci.draw_primitive(PackedVector2Array([a + n * wa * hk, b + n * wb * hk, b - n * wb * hk, a - n * wa * hk]), PackedColorArray([hc, hc, hc, hc]), PackedVector2Array())
	var layers := [[2.2, Color(0.05, 0.25, 1.0, 0.35)], [1.3, Color(0.1, 0.5, 1.0, 0.8)], [0.75, Color(0.35, 0.8, 1.0, 0.95)], [0.28, Color(0.9, 1.0, 1.0, 1)]]
	for L in layers:
		var k: float = L[0] * fl
		var c: Color = L[1]
		c.a *= grow
		ci.draw_primitive(PackedVector2Array([a + n * wa * k, b + n * wb * k, b - n * wb * k, a - n * wa * k]), PackedColorArray([c, c, c, c]), PackedVector2Array())
		if c.a >= 0.9:                                   # round joint: smooth bends in the solid core
			ci.draw_circle(b, wb * k, c)

# ------------------------------------------------------------------ asteroid
## The impact shockwave: a white foam ring racing out over the water with an orange fire
## ring inside it and a faint air ring above. Flat on the ground, so it is drawn with the
## ground shadows (under everything).
func _draw_shockwave(ci: CanvasItem) -> void:
	var sh: Dictionary = game.shock
	if sh.is_empty() or not sh.alive:
		return
	var r: float = sh.r
	var c: Vector3 = sh.center
	var k: float = r / float(game.SHOCK_MAX)
	# [radius, width px, color]: the white front, a foam band behind it, the fire ring, the air ring
	var rings := [[r, 4.0, Color(1, 1, 1, 0.95 * (1.0 - k))], [r - 22.0, 3.0, Color(0.8, 0.93, 1.0, 0.7 * (1.0 - k))],
		[r - 50.0, 2.0, Color(0.7, 0.88, 1.0, 0.45 * (1.0 - k))],
		[r * 0.62, 3.0, Color(1.0, 0.55, 0.15, 0.8 * (1.0 - k * 1.6))], [r * 0.9, 2.0, Color(1, 1, 1, 0.3 * (1.0 - k))]]
	for ri in rings.size():
		var rr: float = rings[ri][0]
		var col: Color = rings[ri][2]
		if rr <= 5.0 or col.a <= 0.01:
			continue
		var y := 0.6 if ri != 4 else 70.0           # the last one is the air ring, up in the sky
		var pts := PackedVector2Array()
		var segs := 72
		for s in segs + 1:
			var a := TAU * s / segs
			var p3 := project(c + Vector3(cos(a) * rr, y, sin(a) * rr))
			if p3.z <= 1.0 or p3.z > fog_end * 1.1:
				if pts.size() > 1:
					ci.draw_polyline(pts, col, float(rings[ri][1]))
				pts = PackedVector2Array()
				continue
			pts.append(Vector2(p3.x, p3.y))
		if pts.size() > 1:
			ci.draw_polyline(pts, col, float(rings[ri][1]))

## As the rock comes in, its glow lights the whole scene orange (stronger at the end).
func _draw_asteroid_tint(ci: CanvasItem) -> void:
	var w: DfWeather = game.weather
	if not w.asteroid_active:
		return
	var k := clampf(w.asteroid_t / w.asteroid_time, 0.0, 1.0)
	var a := 0.2 * k * k * k * (0.9 + 0.1 * sin(_t * 17.0))
	ci.draw_rect(Rect2(Vector2(-view_size.x, -view_size.y), view_size * 3.0), Color(1.0, 0.42, 0.1, a))
const ASTEROID_SCALE := 4.0          # the rock: ~300 m across, the size of its crater (was ~75 m)
const STREAK_LEN := 3600.0           # m of burning trail behind it (a long line across the sky)

## The burning streak: from the rock back along its path. Hot white-yellow at the rock,
## orange, red, then grey smoke that fades out. Ignores fog, so you see it from the
## start of the countdown. Drawn just behind the rock.
func _queue_asteroid_streak(list: Array) -> void:
	var w: DfWeather = game.weather
	var ap := w.asteroid_position()
	# full length from the first second (it has been burning on its way in), a bit longer
	# as it speeds up
	var back := (w.asteroid_start() - w.asteroid_target).normalized()
	var bl := STREAK_LEN * (0.7 + 0.3 * clampf(w.asteroid_t / w.asteroid_time, 0.0, 1.0))
	var pr := project(ap)
	if pr.z <= 1.0:
		return
	var pts: Array = []
	for k in 13:
		var u := float(k) / 12.0
		var p3 := project(ap + back * bl * u * u)     # denser near the rock
		if p3.z <= 1.0:
			break
		pts.append([Vector2(p3.x, p3.y), p3.z, u])
	if pts.size() < 2:
		return
	list.append([pr.z + 2.0, "streak", pts])

func _draw_asteroid_streak(ci: CanvasItem, pts: Array) -> void:
	var rock_r := 9.3 * DfWeather.asteroid_sprites.m_per_px * ASTEROID_SCALE   # m
	var cols := [Color(1.0, 0.98, 0.85), Color("ffd04a"), Color("ff7a1a"), Color("d8321e"), Color(0.32, 0.26, 0.26)]
	for k in range(pts.size() - 1, 0, -1):          # tail first, so the hot head sits on top
		var a: Array = pts[k - 1]
		var b: Array = pts[k]
		var u: float = a[2]
		var wpx := maxf(1.0, rock_r * 1.6 * (1.0 - u * 0.55) * focal / float(a[1]))
		var ci_f := u * (cols.size() - 1)
		var c: Color = (cols[int(ci_f)] as Color).lerp(cols[mini(int(ci_f) + 1, cols.size() - 1)], fmod(ci_f, 1.0))
		c.a = (1.0 - u) * (0.95 if u < 0.5 else 0.7)
		ci.draw_line(a[0], b[0], Color(c, c.a * 0.35), wpx * 1.8)     # glow
		ci.draw_line(a[0], b[0], c, wpx)
		if u < 0.35:
			ci.draw_line(a[0], b[0], Color(1, 1, 0.9, (0.35 - u) * 2.0), maxf(1.0, wpx * 0.35))   # white-hot core
	# the rock burns: an orange glow around it that flickers
	var h: Array = pts[0]
	var hr := rock_r * focal / float(h[1])
	var fl := 0.85 + 0.15 * sin(_t * 23.0)
	ci.draw_circle(h[0], hr * 1.55 * fl, Color(1.0, 0.45, 0.1, 0.22))
	ci.draw_circle(h[0], hr * 1.25 * fl, Color(1.0, 0.7, 0.25, 0.25))

# ------------------------------------------------------------------ replay clouds
# T: "Clouds need to be obscured or translucent in replays". In a replay every cloud is
# translucent; a cloud IN FRONT of the action that overlaps it on screen goes nearly clear
# around it (a soft window, so it reads as glass, not a hole).
var _rp_pts: Array = []        # [Vector2 screen pos, depth] of the victim, the attacker, the KO

func _replay_focus() -> void:
	_rp_pts.clear()
	if game.state != "replay":
		return
	var pts: Array = [game.replay.victim_pos(game), game.replay.attacker_pos(game), game.replay.ko.get("pos", Vector3.ZERO)]
	if game.boss != null:
		pts.append(game.boss.hit_center())
	for p in pts:
		var q := project(p)
		if q.z > 1.0:
			_rp_pts.append([Vector2(q.x, q.y), q.z])

## Replays: a sea stack / the volcano standing IN FRONT of the action and covering it on
## screen is ghosted to 30% (soft edge); everything else stays solid. Live play: always 1.
func _replay_occluder_alpha(base: Vector3, height_m: float, width_m: float) -> float:
	if game.state != "replay" or _rp_pts.is_empty():
		return 1.0
	var c := project(base + Vector3.UP * height_m * 0.5)
	if c.z <= 1.0:
		return 1.0
	var half := Vector2(width_m, height_m) * 0.5 * focal / c.z
	var a := 1.0
	for f in _rp_pts:
		if c.z < float(f[1]):
			var dn := ((f[0] as Vector2) - Vector2(c.x, c.y)) / half.max(Vector2.ONE)
			a = minf(a, lerpf(0.3, 1.0, smoothstep(0.7, 1.3, maxf(absf(dn.x), absf(dn.y)))))
	return a

func _replay_cloud_alpha(at: Vector2, depth: float, sz: Vector2) -> float:
	var a := 0.45
	var front := false
	var clear := 1.0
	for f in _rp_pts:
		if depth < float(f[1]):
			front = true
			# how far the action is from the cloud's center, in cloud half-sizes
			var dn := ((f[0] as Vector2) - at) / (sz * 0.5).max(Vector2.ONE)
			clear = minf(clear, smoothstep(0.35, 1.15, dn.length()))
	if not front:
		return 0.6                 # behind the action: scenery
	return lerpf(0.12, a, clear)

func _fade(depth: float) -> float:
	return 1.0 - smoothstep(fog_end * 0.55, fog_end, depth)

## Fade for light sources: they pierce fog and only drop out far beyond it.
func _light_fade(depth: float) -> float:
	return 1.0 - smoothstep(light_end * 0.7, light_end, depth)

## Fog scatter round a light: two soft discs, stronger in thick fog and at night.
func _halo(ci: CanvasItem, c2: Vector2, r: float, col: Color) -> void:
	var k := fog_k * (0.6 + 0.6 * koi_dark())
	if k <= 0.03 or r < 0.5:
		return
	var c := col
	c.a = col.a * 0.16 * k
	ci.draw_circle(c2, minf(r * 2.6, 260.0), c)
	c.a = col.a * 0.22 * k
	ci.draw_circle(c2, minf(r * 1.5, 180.0), c)

## Queue one sprite. yaw = object heading. bank = extra screen rotation (jets).
## sky = true: ignores fog (the asteroid burns through it and is seen from far away).
func _queue_sprite(list: Array, s: DfSprites, pos: Vector3, yaw: float, scale_mult := 1.0, bank := 0.0, mod := Color.WHITE, att: Variant = null, sky := false) -> void:
	var pr := project(pos)
	if pr.z <= 0.0 or (pr.z > fog_end * 1.05 and not sky):
		return
	var k: float = focal / pr.z * s.m_per_px * scale_mult
	if pr.z < 5.0 or (k > 6.0 and s.m_per_px < 3.0):
		return   # near clip: a jet passing the lens would fill the screen as giant pixels
	if not on_screen(Vector2(pr.x, pr.y), 70.0 * k + 8.0):
		return
	var c := mod
	if not sky:
		c.a *= _fade(pr.z)
	if att != null:     # full attitude (jets): pick the frame in the jet's own frame, then turn it
		var b: Basis = att
		var v := (b.inverse() * (cam_pos - pos)).normalized()
		var rel2 := atan2(v.x, v.z)
		var el2 := asin(clampf(v.y, -1.0, 1.0))
		var fr2: Dictionary = s.frame_for(rel2, el2)
		list.append([pr.z, "sprite", s, fr2, Vector2(pr.x, pr.y), k, _frame_turn(b, v) - _screen_roll, c])
		return
	var d_local := (cam_pos - pos).rotated(Vector3.UP, -yaw)
	var rel := atan2(d_local.x, d_local.z)
	var el := asin(clampf(d_local.y / maxf(d_local.length(), 0.001), -1.0, 1.0))
	var fr: Dictionary = s.frame_for(rel, el)
	list.append([pr.z, "sprite", s, fr, Vector2(pr.x, pr.y), k, bank * cos(rel), c])

## Screen rotation for a baked frame of an object with attitude b, seen along v (object ->
## camera, in the object's frame). Frames were baked with a level camera (its right axis
## horizontal in the model), so the only thing left is a turn about the view axis: match
## where one model axis (the canopy, or the nose when seen from above/below) points on
## the baked image vs on the real screen.
func _frame_turn(b: Basis, v: Vector3) -> float:
	var a := Vector3.UP if absf(v.y) < 0.8 else Vector3(0, 0, -1)
	var br := Vector3.UP.cross(v).normalized()
	var bu := v.cross(br)
	var ang_exp := atan2(a.dot(br), a.dot(bu))
	var aw := b * a
	var ang_act := atan2(aw.dot(cam_right), aw.dot(cam_up))
	return ang_act - ang_exp

func _draw_units() -> void:
	if game == null or game.world == null:
		return
	var ci := _units
	var world: DfWorld = game.world
	var weather: DfWeather = game.weather
	var list: Array = []
	# ground shadows (drawn first, they lie on the floor)
	var jets: Array = []
	for e in game.enemies:
		if e.alive:
			jets.append(e)
	if game.player.visible:
		jets.append(game.player)
	for j in jets:
		var g := world.ground_y(j.position)
		if j.position.y - g < 260.0:
			_ground_disc(ci, Vector3(j.position.x, g + 0.3, j.position.z), 7.0, Color(DfPal.SHADOW, 0.45))
	_draw_shockwave(ci)
	if weather.asteroid_active:
		var ap := weather.asteroid_position()
		var grow := clampf(weather.asteroid_t / weather.asteroid_time, 0.0, 1.0)
		_ground_disc(ci, Vector3(ap.x, 0.3, ap.z), lerpf(40.0, 220.0, grow), Color(DfPal.SHADOW, 0.25 + 0.35 * grow))
	# scenery
	var vp: Dictionary = world.volcano
	_replay_focus()
	var amb: Color = game.weather.cur.get("ambient", Color.WHITE)     # scenery takes the weather's daylight
	_queue_sprite(list, spr.volcano, vp.pos, 0.0, 1.0, 0.0, Color(amb, _replay_occluder_alpha(vp.pos, 190.0, 340.0)))
	for sp in world.spires:
		if sp.alive:
			_queue_sprite(list, spr.spire, sp.pos, float(int(sp.pos.x) % 8), sp.height / 70.0, 0.0,
				Color(amb, _replay_occluder_alpha(sp.pos, sp.height, sp.height * 0.5)))
	for p in world.palms:
		if p.alive:
			_queue_sprite(list, spr.palm, p.pos, float(p.get("yaw", float(int(p.pos.z) % 8))), 1.0, 0.0, amb)
	for s in game.ships:
		if s.alive:
			_queue_sprite(list, spr.ship, s.pos + Vector3(0, sin(s.bob * 1.3) * 0.8, 0), s.yaw)
	for h in world.hoops:
		if h.cooldown <= 0.0:
			_queue_sprite(list, spr.hoop, h.pos, h.yaw)
	var glow_e: Variant = null
	if game.laser_ready() and game.laser_target != null and game.laser_target.has("e"):
		glow_e = game.laser_target.e
	for j in jets:
		var mod := Color.WHITE
		if j.kind != "player" and j.last_hit_by_player < 0.08:
			mod = Color(2.2, 2.2, 2.2)
		if j == glow_e:
			mod = Color(1.6, 0.7, 0.7)
			var gp := project(j.position)
			if gp.z > 0.0:
				list.append([gp.z + 0.5, "glow", gp])
		_queue_sprite(list, j.sprites(), j.position, j.yaw, 1.0, 0.0, mod, j.vis_basis())
		if j.kind == "boss":
			_queue_boss(list, j)
	var pl: DfPlane = game.player
	if pl.visible and pl.alive and game.state != "crash":
		var nz := project(pl.position - pl.forward() * NOZZLE_BACK + pl.up() * 0.4)
		if nz.z > 0.5:
			list.append([nz.z, "flame", pl])
		if game.muzzle_t > 0.0:
			var mz := project(pl.position + pl.forward() * 9.5)
			if mz.z > 0.5:
				list.append([mz.z, "muzzle", mz])
	for sk in sparks:
		var a := project(sk.pos)
		if a.z > 0.5 and a.z < light_end:
			list.append([a.z, "spark", sk, a])
	_queue_trails(list)
	# beam drawn just behind the player's jet: it leaves the nose, which the jet hides from the chase cam
	var pz := project(game.player.position).z
	for b in game.lasers:
		list.append([pz + 0.5 if pz > 0.0 else 0.01, "laser", b])
	if game.laser_burst_t > 0.0:     # the burst sits ON TOP of the jet: it comes out of the visor
		var vz := project(game.visor_pos())
		if vz.z > 0.5:
			list.append([maxf(0.02, pz - 0.5), "burst", vz])
	if weather.asteroid_active:
		_queue_sprite(list, DfWeather.asteroid_sprites, weather.asteroid_position(), weather.asteroid_t * 0.8, ASTEROID_SCALE, 0.0, Color.WHITE, null, true)
		_queue_asteroid_streak(list)
	for d in game.debris:            # burning rocks thrown out of the crater
		_queue_sprite(list, DfWeather.rock_sprites(), d.pos, d.spin, d.size)
		var tr: PackedVector3Array = d.trail
		for k in tr.size() - 1:
			var a := project(tr[k])
			var b := project(tr[k + 1])
			if a.z > 2.0 and b.z > 2.0 and a.z < light_end:
				var u := float(k) / 7.0
				var c := Color("ffd04a").lerp(Color("d8321e"), u)
				c.a = (1.0 - u) * 0.9 * _light_fade(a.z)
				list.append([a.z + 0.5, "trail", Vector2(a.x, a.y), Vector2(b.x, b.y), c, clampf(focal / a.z * float(d.size) * 40.0, 2.0, 7.0)])
	for c in clouds:
		var pr := project(c.pos)
		if pr.z > 0.0 and pr.z < fog_end:
			list.append([pr.z, "cloud", c, pr])
	for pr in game.projectiles:
		var a := project(pr.p)
		if a.z > 0.0 and a.z < light_end:
			list.append([a.z, "proj", pr, a])
	for bl in game.fx.blasts:
		if float(bl.t) < 0.0:
			continue
		var a := project(bl.pos)
		if a.z > 1.0 and a.z < light_end:
			list.append([a.z, "blast", bl, a])
	for f in game.fx.puffs:
		var a := project(f.pos)
		if a.z > 0.0 and a.z < fog_end:
			list.append([a.z, "puff", f, a])
	list.sort_custom(func(x, y): return x[0] > y[0])
	for it in list:
		match it[1]:
			"sprite":
				_draw_sprite(ci, it[2], it[3], it[4], it[5], it[6], it[7])
			"cloud":
				var c: Dictionary = it[2]
				var a: Vector3 = it[3]
				var tex: ImageTexture = cloud_tex[c.img]
				var k: float = focal / a.z * c.size
				var sz := tex.get_size() * k
				var col := Color(1, 1, 1, _fade(a.z) * 0.95)
				if game.state == "replay":
					col.a *= _replay_cloud_alpha(Vector2(a.x, a.y), a.z, sz)
				ci.draw_set_transform(Vector2(a.x, a.y).round(), _screen_roll, Vector2.ONE)
				ci.draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, col)
				ci.draw_set_transform_matrix(Transform2D.IDENTITY)
			"proj":
				_draw_projectile(ci, it[2], it[3])
			"blast":
				var bl: Dictionary = it[2]
				var bt: Texture2D = blast_texs.get(bl.get("kind", "fire"), blast_tex)
				if bt != null:
					var a: Vector3 = it[3]
					var c2 := Vector2(a.x, a.y)
					var k01 := float(bl.t) / float(bl.life)
					if bl.get("ring", false):     # laser kill: a shock ring races out first (red, or blue for the beam)
						var blue: bool = bl.get("kind", "") == "beam"
						var rr := focal / a.z * 26.0 * float(bl.size) * sqrt(k01)
						ci.draw_arc(c2, minf(rr, 400.0), 0.0, TAU, 32, (Color(0.2, 0.65, 1.0) if blue else Color(1.0, 0.12, 0.3)) * Color(1, 1, 1, (1.0 - k01) * _light_fade(a.z)), 2.0)
						ci.draw_arc(c2, minf(rr * 0.8, 320.0), 0.0, TAU, 32, (Color(0.8, 0.97, 1.0) if blue else Color(1.0, 0.75, 0.8)) * Color(1, 1, 1, (1.0 - k01) * 0.6 * _light_fade(a.z)), 1.0)
					var fs: float = bt.get_height()
					var fi := clampi(int(k01 * BLAST_FRAMES), 0, BLAST_FRAMES - 1)
					var px := minf(roundf(focal / a.z * 18.0 * float(bl.size)), 300.0)
					var lf := _light_fade(a.z)
					var hot := 1.0 - k01                       # the fireball is brightest early
					var bk: String = bl.get("kind", "fire")
					_halo(ci, c2, px * 0.55, Color(1.0, 0.35, 0.3, hot * lf) if bk == "laser" else (Color(0.3, 0.7, 1.0, hot * lf) if bk == "beam" else Color(1.0, 0.6, 0.2, hot * lf)))
					var col := Color(1, 1, 1, lf)
					ci.draw_texture_rect_region(bt, Rect2((c2 - Vector2(px, px) * 0.5).round(), Vector2(px, px)), Rect2(fi * fs, 0, fs, fs), col)
			"streak":
				_draw_asteroid_streak(ci, it[2])
			"rotor":
				_draw_rotor(ci, it[2], it[3])
			"bossglow":
				_draw_boss_glow(ci, it[2], it[3], it[4])
			"bosslock":
				_draw_boss_lock(ci, it[2], it[3])
			"bossbeam":
				_draw_boss_beam(ci, it[2], it[3], it[4])
			"navlight":
				_draw_navlight(ci, it[2], it[3])
			"trail":
				ci.draw_line(it[2], it[3], it[4], it[5])
			"flame":
				_draw_flame(ci, it[2])
			"spark":
				var sk: Dictionary = it[2]
				var a: Vector3 = it[3]
				var b3 := project(sk.pos - (sk.vel - game.player.vel) * 0.03)
				var col: Color = sk.col
				col.a = 1.0 - sk.t / sk.life
				if b3.z > 0.0:
					ci.draw_line(Vector2(a.x, a.y).round(), Vector2(b3.x, b3.y).round(), col, 1.0)
			"muzzle":
				var m: Vector3 = it[2]
				var mc := Vector2(m.x, m.y)
				var r := clampf(focal / m.z * 3.0, 3.0, 12.0)
				_halo(ci, mc, r, Color(1.0, 0.3, 0.25, 1.0))
				for k in 6:
					var ang := TAU * k / 6.0 + randf() * 0.6
					ci.draw_line(mc, mc + Vector2(cos(ang), sin(ang)) * r * randf_range(0.6, 1.4), Color("ff1f2e"), 1.0)
				ci.draw_rect(Rect2(mc.round() - Vector2.ONE, Vector2(2, 2)), Color("fff2c0"))
			"glow":
				var g: Vector3 = it[2]
				var gr := focal / g.z * 13.0 * (1.0 + 0.12 * sin(_t * 12.0))
				for k in 3:
					ci.draw_circle(Vector2(g.x, g.y), gr * (1.0 - k * 0.25), Color(1.0, 0.1, 0.15, 0.13 + k * 0.07))
			"laser":
				_draw_laser(ci, it[2])
			"burst":
				_draw_visor_burst(ci, it[2])
			"puff":
				var f: Dictionary = it[2]
				var a: Vector3 = it[3]
				var kk: float = f.t / f.life
				var cap: float = minf(float(f.get("cap", 70.0)), 4.0 if f.col == DfPal.OUTLINE else 70.0)   # debris stays a fleck; a blast next to the lens is not a wall
				var sz := clampf(roundf(lerpf(f.s0, f.s1, kk) * focal / a.z), 2.0 if cap < 10.0 and f.col != DfPal.OUTLINE else 1.0, cap)   # embers never shrink below 2 px
				var col: Color = f.col
				col.a *= (1.0 - kk * kk) * _fade(a.z) * smoothstep(6.0, 22.0, a.z)
				ci.draw_rect(Rect2((Vector2(a.x, a.y) - Vector2(sz, sz) * 0.5).round(), Vector2(sz, sz)), col)
	_draw_weather(ci, weather)
	_draw_asteroid_tint(ci)
	if game.state == "replay":
		_draw_replay_marks(ci)

## Replay glow trails: in the far shots a jet is a few pixels, so you and the victim get a
## light trail + a glowing dot (lights pierce fog). They fade out when the jet is big on screen.
func _draw_replay_marks(ci: CanvasItem) -> void:
	for tr in game.replay.trails(game):
		var pts: PackedVector3Array = tr[0]
		var col: Color = tr[1]
		if pts.size() < 2:
			continue
		var last := project(pts[pts.size() - 1])
		if last.z <= 1.0:
			continue
		var jet_px := focal / last.z * 9.0
		var vis := clampf(1.0 - (jet_px - 3.0) / 5.0, 0.0, 1.0)   # only when the jet is a dot (shots now frame it at 8-12 px)
		if vis <= 0.0:
			continue
		var prev := Vector3.ZERO
		for k in pts.size():
			var p := project(pts[k])
			if k > 0 and p.z > 1.0 and prev.z > 1.0:
				var u := float(k) / pts.size()
				var c := col
				c.a = vis * (0.2 + 0.8 * u)
				ci.draw_line(Vector2(prev.x, prev.y), Vector2(p.x, p.y), Color(col, c.a * 0.35), 3.0)   # soft glow
				ci.draw_line(Vector2(prev.x, prev.y), Vector2(p.x, p.y), c, 1.0)                        # core
			prev = p
		# the jet itself: halo, a dark ring (reads on bright sky AND on the blue beam), color, white core
		var c2 := Vector2(last.x, last.y).round()
		_halo(ci, c2, 6.0, Color(col, vis))
		ci.draw_circle(c2, 4.5, Color(col, 0.3 * vis))
		ci.draw_arc(c2, 3.5, 0.0, TAU, 12, Color(0.02, 0.02, 0.06, 0.8 * vis), 1.0)
		ci.draw_circle(c2, 2.5, Color(col, vis))
		ci.draw_rect(Rect2(c2 - Vector2.ONE, Vector2(2, 2)), Color(1, 1, 1, vis))

func _draw_sprite(ci: CanvasItem, s: DfSprites, fr: Dictionary, at: Vector2, k: float, bank: float, col: Color) -> void:
	var rect: Rect2 = fr.rect
	var anc: Vector2 = fr.anchor
	if k * rect.size.x < 1.5:
		ci.draw_rect(Rect2(at.round(), Vector2.ONE), Color(DfPal.OUTLINE, col.a))
		return
	ci.draw_set_transform(at.round(), _screen_roll + bank, Vector2.ONE)
	ci.draw_texture_rect_region(s.atlas, Rect2((-anc * k).round(), (rect.size * k).round()), rect, col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# =====================================================================
# T's effects: boost flames, sparks, laser
# =====================================================================
func _step_sparks(dt: float) -> void:
	var pl: DfPlane = game.player
	var stage := pl.boost_stage() if (pl.alive and pl.visible) else 0
	var rate: float = SPARK_RATE[stage]
	var n := int(rate * dt) + (1 if randf() < fmod(rate * dt, 1.0) else 0)
	var f := pl.forward()
	var noz := pl.position - f * NOZZLE_BACK + pl.up() * 0.4
	for k in n:
		var spread := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * (16.0 if stage == 3 else 10.0)
		sparks.append({"pos": noz, "vel": pl.vel * 0.8 - f * randf_range(15.0, 45.0) + spread,
			"life": randf_range(0.25, 0.45), "t": 0.0, "col": Color("00e5ff") if randf() < 0.75 else Color.WHITE})
	# drift charge sparks: orange once tier 1 is ready, blue at tier 2 (let go to boost)
	var tier := pl.drift_tier() if (pl.alive and pl.drift) else 0
	if tier > 0:
		var cn := int(30.0 * dt) + (1 if randf() < fmod(30.0 * dt, 1.0) else 0)
		for k in cn:
			var side := pl.right() * randf_range(-1.0, 1.0) * 14.0
			sparks.append({"pos": noz, "vel": pl.vel * 0.85 - f * randf_range(10.0, 30.0) + side + pl.up() * randf_range(-4, 8),
				"life": randf_range(0.2, 0.35), "t": 0.0, "col": Color("ffb000") if tier == 1 else Color("2a7bff")})
	var keep: Array = []
	for sk in sparks:
		sk.t += dt
		sk.pos += sk.vel * dt
		if sk.t < sk.life:
			keep.append(sk)
	sparks = keep

## A jagged flame shape around the nozzle, stretched toward the projected tail tip.
## Seen from behind it is a burst; from the side it is a cone.
func _draw_flame(ci: CanvasItem, pl: DfPlane) -> void:
	var stage := pl.boost_stage()
	var f := pl.forward()
	var nw := pl.position - f * NOZZLE_BACK + pl.up() * 0.4
	var n3 := project(nw)
	var c := Vector2(n3.x, n3.y)
	var k := focal / n3.z                 # px per meter at the nozzle
	var flick := 0.85 + 0.3 * randf()
	if stage == 3:                        # blast: spikes + shock ring around the outside
		var spikes := PackedVector2Array()
		var n := 20
		for i in n:
			var a := TAU * i / n + _t * 3.0
			var r := 1.7 * k * (1.9 if i % 2 == 0 else 0.9) * randf_range(0.8, 1.25)
			spikes.append(c + Vector2(cos(a), sin(a)) * r)
		ci.draw_colored_polygon(spikes, Color("1428c8", 0.75))
		var ring := fmod(_t * 3.5, 1.0)
		ci.draw_arc(c, k * (1.4 + ring * 2.4), 0.0, TAU, 24, Color(0.0, 0.85, 1.0, 1.0 - ring), 1.0)
	for layer in FLAME[stage]:
		var tip3 := project(nw - f * float(layer[1]) * flick)
		var axis := Vector2.ZERO if tip3.z <= 0.0 else Vector2(tip3.x, tip3.y) - c
		var r: float = float(layer[0]) * k * flick
		var pts := PackedVector2Array()
		var n2 := 14
		for i in n2:
			var a := TAU * i / n2
			var d := Vector2(cos(a), sin(a))
			var jag := randf_range(0.75, 1.2) if i % 2 == 0 else randf_range(0.5, 0.85)
			var p := c + d * r * jag
			var along := maxf(0.0, d.dot(axis.normalized())) if axis.length() > 0.5 else 0.0
			pts.append(p + axis * along * jag)
		ci.draw_colored_polygon(pts, layer[2])

## Super laser: a thick beam (glow, bright red edge, dark core, hot center) with
## 4 twisting strands. Width follows distance, so it is huge near the jet.
func _draw_laser(ci: CanvasItem, b: Dictionary) -> void:
	var head := clampf(float(b.t) / game.LASER_TRAVEL, 0.0, 1.0)
	var fade := 1.0 - clampf((float(b.t) - game.LASER_TRAVEL) / game.LASER_LINGER, 0.0, 1.0)
	var pts: Array = []
	var ws: Array = []
	var steps := 28
	for i in steps + 1:
		var u := head * i / steps
		var p3 := project(game.laser_point(b, u))
		if p3.z > 0.5:
			pts.append(Vector2(p3.x, p3.y))
			var pulse: float = 1.0 + 0.18 * sin(_t * 50.0 + i * 0.8)
			ws.append(clampf(focal / p3.z * 2.8, 3.0, 22.0) * pulse * (0.35 + 0.65 * fade))
	if pts.size() < 2:
		return
	var layers := [[2.2, Color(1.0, 0.1, 0.2, 0.28 * fade)], [1.0, Color(1.0, 0.13, 0.2, fade)],
		[0.55, Color(0.54, 0.03, 0.15, fade)], [0.18, Color(1.0, 0.9, 0.92, fade)]]
	for L in layers:
		for i in pts.size() - 1:
			var w: float = maxf(1.0, ws[i] * float(L[0]))
			ci.draw_line(pts[i], pts[i + 1], L[1], w)
			if w > 3.0:
				ci.draw_circle(pts[i + 1], w * 0.5, L[1])   # round joints, no gaps on the curve
	for strand in 4:
		var line := PackedVector2Array()
		for i in pts.size():
			var a: Vector2 = pts[i]
			var nx: Vector2 = pts[mini(i + 1, pts.size() - 1)]
			var pv: Vector2 = pts[maxi(i - 1, 0)]
			var nrm := (nx - pv).orthogonal().normalized()
			line.append(a + nrm * sin(i * 0.7 + _t * 30.0 + strand * 1.57) * float(ws[i]) * 0.95)
		ci.draw_polyline(line, Color(1.0, 0.35, 0.4, fade), 1.0)
	var tip: Vector2 = pts[pts.size() - 1]
	var tw: float = ws[ws.size() - 1]
	ci.draw_circle(tip, tw * 1.3, Color(1, 0.15, 0.25, 0.5 * fade))
	ci.draw_circle(tip, tw * 0.7, Color(1, 0.9, 0.92, fade))

## Burst out of the cyclops visor when the super laser fires: flash, a horizontal
## lens streak across the visor, red rays and a shock ring.
func _draw_visor_burst(ci: CanvasItem, v: Vector3) -> void:
	var c := Vector2(v.x, v.y)
	var k := focal / v.z
	var u: float = 1.0 - game.laser_burst_t / game.LASER_BURST      # 0 -> 1
	var a := 1.0 - u
	var grow := minf(1.0, u * 4.0)
	# horizontal cyclops streak
	var sw := k * 26.0 * grow
	ci.draw_rect(Rect2(c.x - sw, c.y - 2.0, sw * 2.0, 4.0), Color(1, 0.15, 0.2, 0.8 * a))
	ci.draw_rect(Rect2(c.x - sw * 0.7, c.y - 1.0, sw * 1.4, 2.0), Color(1, 0.95, 0.95, a))
	# rays
	var n := 14
	for i in n:
		var ang := TAU * i / n + sin(i * 7.3) * 0.2
		var length := k * (7.0 + 9.0 * absf(sin(i * 3.1 + _t * 20.0))) * grow
		var d := Vector2(cos(ang), sin(ang))
		ci.draw_line(c + d * k * 1.2, c + d * length, Color(1, 0.12, 0.2, a), maxf(1.0, k * 0.9 * a))
		ci.draw_line(c + d * k * 1.2, c + d * length * 0.6, Color(1, 0.9, 0.9, a), 1.0)
	# shock ring + core flash
	ci.draw_arc(c, k * (2.0 + 14.0 * u), 0.0, TAU, 32, Color(1, 0.3, 0.35, a), maxf(1.0, 2.0 * a))
	ci.draw_circle(c, k * 3.2 * (1.0 - u * 0.6), Color(1, 0.15, 0.25, 0.7 * a))
	ci.draw_circle(c, k * 1.8 * (1.0 - u * 0.6), Color(1, 1, 1, a))

func _draw_projectile(ci: CanvasItem, pr: Dictionary, a: Vector3) -> void:
	var at := Vector2(a.x, a.y).round()
	var size := clampf(focal / a.z * 1.2, 1.0, 4.0)
	if pr.kind == "bomb" and a.z > fog_end:
		return                        # a bomb is not a light: fog hides it
	var lf := _light_fade(a.z)
	match pr.kind:                    # tracers, flak and lava glow through fog
		"bullet":
			_halo(ci, at, 3.0, Color(1.0, 0.2, 0.25, lf))
		"enemy_bullet":
			_halo(ci, at, 3.0, Color(DfPal.ENEMY_BULLET, lf))
		"flak":
			_halo(ci, at, size * 2.0, Color(DfPal.FLAK, lf))
		"lava":
			_halo(ci, at, maxf(2.0, focal / a.z * 5.0), Color(1.0, 0.45, 0.1, lf))
	match pr.kind:
		"bullet":   # T's bolt: pale capsule with a red outline
			var b3 := project(pr.p - (pr.v as Vector3) * 0.03)
			var b := at if b3.z <= 0.0 else Vector2(b3.x, b3.y).round()
			var w := clampf(focal / a.z * 1.6, 1.0, 5.0)
			ci.draw_line(at, b, Color("ff1f2e"), w + 2.0)
			ci.draw_line(at, b, Color("ffe0e4"), w)
		"enemy_bullet":
			var b3 := project(pr.p - (pr.v as Vector3) * 0.022)
			var b := at if b3.z <= 0.0 else Vector2(b3.x, b3.y).round()
			ci.draw_line(at, b, DfPal.BULLET if pr.kind == "bullet" else DfPal.ENEMY_BULLET, size)
		"flak":
			ci.draw_rect(Rect2(at - Vector2(size, size), Vector2(size, size) * 2.0), DfPal.FLAK)
		"bomb":
			var s2 := maxf(2.0, size * 1.5)
			ci.draw_rect(Rect2(at - Vector2(s2, s2) * 0.5, Vector2(s2, s2)), DfPal.OUTLINE)
		"lava":
			var s3 := maxf(2.0, focal / a.z * 5.0)
			ci.draw_rect(Rect2(at - Vector2(s3, s3) * 0.5 - Vector2.ONE, Vector2(s3, s3) + Vector2(2, 2)), DfPal.OUTLINE)
			ci.draw_rect(Rect2(at - Vector2(s3, s3) * 0.5, Vector2(s3, s3)), DfPal.LAVA)

## A flat circle on the ground, projected (shadows, asteroid impact zone).
func _ground_disc(ci: CanvasItem, c: Vector3, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 14:
		var a := TAU * k / 14.0
		var pr := project(c + Vector3(cos(a) * r, 0.0, sin(a) * r))
		if pr.z <= 0.0:
			return
		pts.append(Vector2(pr.x, pr.y).round())
	var hull := Geometry2D.convex_hull(pts)
	if hull.size() < 4:
		return
	hull.remove_at(hull.size() - 1)   # convex_hull repeats the first point
	var area := 0.0
	for i in hull.size():
		area += hull[i].cross(hull[(i + 1) % hull.size()])
	if absf(area) < 4.0:
		return                         # a sliver near the horizon: skip
	col.a *= _fade(project(c).z)
	ci.draw_colored_polygon(hull, col)

func _draw_weather(ci: CanvasItem, weather: DfWeather) -> void:
	var dt := get_process_delta_time()
	if weather.rain_on:
		for i in _rain.size():
			var r: Vector2 = _rain[i] + Vector2(-90.0, 380.0) * dt
			if r.y > view_size.y:
				r = Vector2(randf() * (view_size.x + 90.0), -6.0)
			_rain[i] = r
			ci.draw_line(r.round(), (r + Vector2(-2, 7)).round(), DfPal.RAIN, 1.0)
	if weather.erupting:
		for i in _ash.size():
			var a: Vector2 = _ash[i] + Vector2(10.0, 30.0) * dt
			if a.y > view_size.y:
				a = Vector2(randf() * view_size.x, -2.0)
			_ash[i] = a
			ci.draw_rect(Rect2(a.round(), Vector2(1, 1)), DfPal.SMOKE if i % 3 else DfPal.FIRE)
	# motion lines: only at TOP SPEED (boost stage 3 or a drift boost). They stream outward.
	var top: bool = game.player.boost_stage() == 3 and game.state != "crash"
	if top:
		for k in 4:
			_motion.append({"a": randf() * TAU, "r": randf_range(0.42, 0.6), "v": randf_range(1.6, 2.6),
				"l": randf_range(0.08, 0.2), "c": Color(0.75, 0.95, 1.0) if randf() < 0.3 else Color.WHITE})
	var half := view_size.length() * 0.5
	var keep: Array = []
	for m in _motion:
		m.r += m.v * dt
		if m.r < 1.15:
			keep.append(m)
			var d := Vector2(cos(m.a), sin(m.a))
			var a0: Vector2 = anchor + d * half * m.r
			var a1: Vector2 = anchor + d * half * (m.r + m.l)
			ci.draw_line(a0.round(), a1.round(), Color(m.c, 0.75), 1.0)
	_motion = keep
	# inside a cloud: white-out (not in replays: the cinematic camera flies through them)
	for c in clouds:
		if game.state == "replay":
			break
		if cam_pos.distance_to(c.pos) < 30.0 * c.size:
			ci.draw_rect(Rect2(Vector2.ZERO, view_size), Color(1, 1, 1, 0.55))
			break

# ------------------------------------------------------------------ pixel models
static func _palm_model() -> Dictionary:
	var v := {}
	for y in 7:
		v[Vector3i(y / 3, y, 0)] = Color("bc5f21")
	var top := Vector3i(2, 7, 0)
	v[top] = DfPal.CYAN.lerp(Color("00ff80"), 0.8)
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
			Vector3i(1, 0, 1), Vector3i(-1, 0, -1), Vector3i(1, 0, -1), Vector3i(-1, 0, 1)]:
		for k in range(1, 4):
			v[top + d * k + Vector3i(0, -int(k > 1) - int(k > 2), 0)] = Color("00ff80") if k < 3 else Color("00b25f")
	return v

static func _spire_model() -> Dictionary:
	var v := {}
	for y in 14:
		var r := 3.6 - y * 0.12
		for x in range(-4, 5):
			for z in range(-4, 5):
				var d := Vector2(x, z).length()
				if d <= r and d > r - 1.5:
					var band := Color("b8afd5") if (y % 4 != 0) else Color("8f86b0")
					v[Vector3i(x, y, z)] = band
				elif y == 13 and d <= r:
					v[Vector3i(x, y, z)] = Color("2edf71")
	for x in range(-2, 3):
		for z in range(-2, 3):
			if Vector2(x, z).length() <= 2.2:
				v[Vector3i(x, 14, z)] = Color("2edf71")   # grass cap
	return v

static func _volcano_model() -> Dictionary:
	var v := {}
	var R := 28.0
	var H := 32
	for y in H:
		var r := R * (1.0 - float(y) / (H + 4))
		var inner := r - 1.6
		var crater := y >= H - 5
		for x in range(-29, 30):
			for z in range(-29, 30):
				var d := Vector2(x, z).length()
				if d > r:
					continue
				if d < inner and y < H - 1 and not crater:
					continue
				if crater and d < r * 0.55:
					continue
				var c := Color("5c3a63") if (y % 3) else Color("3b2747")
				if y >= H - 6:
					c = Color("2e2433")
				v[Vector3i(x, y, z)] = c
	for x in range(-9, 10):
		for z in range(-9, 10):
			if Vector2(x, z).length() < 8.5:
				v[Vector3i(x, H - 5, z)] = Color("ff4d00") if (x + z) % 3 else Color("ffb000")   # lava pool
	return v

static func _ship_model() -> Dictionary:
	var v := {}
	for z in range(-9, 10):
		var half := 3 if absi(z) < 6 else (2 if absi(z) < 8 else 1)
		for x in range(-half, half + 1):
			v[Vector3i(x, 0, z)] = DfPal.HULL
			v[Vector3i(x, 1, z)] = DfPal.HULL if absi(x) == half else DfPal.DECK
	for z in range(-3, 4):
		for x in range(-1, 2):
			v[Vector3i(x, 2, z)] = DfPal.TURRET
	for z in range(-7, -2):
		v[Vector3i(0, 3, z)] = DfPal.TURRET
	for y in range(2, 6):
		v[Vector3i(0, y, 6)] = DfPal.HULL
	v[Vector3i(1, 5, 6)] = DfPal.FLAG
	v[Vector3i(2, 5, 6)] = DfPal.FLAG
	return v

static func _hoop_model() -> Dictionary:
	var v := {}
	for y in range(-9, 10):
		for x in range(-9, 10):
			var e := Vector2(x, y).length()
			if e > 6.6 and e < 8.6:
				v[Vector3i(x, y, 0)] = DfPal.HOOP_HOT if y < 0 else DfPal.HOOP
	return v

static func _cloud_image(k: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + k
	var img := Image.create(56, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blobs: Array = []
	for b in 5:
		blobs.append([Vector2(rng.randf_range(12, 44), rng.randf_range(12, 18)), rng.randf_range(6, 11)])
	for y in 28:
		for x in 56:
			var inside := false
			var top := false
			for bl in blobs:
				var d := Vector2(x, y).distance_to(bl[0])
				if d < bl[1]:
					inside = true
					if y < (bl[0] as Vector2).y - 2:
						top = true
			if inside:
				img.set_pixel(x, y, Color("ffffff") if top else Color("d6e8ff"))
	return img
