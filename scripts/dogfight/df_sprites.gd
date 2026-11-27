class_name DfSprites
extends RefCounted
## Pixel stack -> multi-angle sprites (baked once at load, no meshes at runtime).
## For every heading (yaw) and camera height (elevation) the stack's pixels are
## projected (slices 1 px apart, tight), drawn back to front, shaded top/side,
## then ONE dark outline is added around the finished sprite.
## At runtime DfRender picks the frame that matches where the camera sees it from
## and scales it like a SEGA "Super Scaler" sprite (nearest filtering).

const SIDE_SHADE := 0.70
const UNDER_SHADE := 0.55

var atlas: Texture2D          # ImageTexture (live bake) or the imported baked PNG
var frames: Array = []        # [elev_i * yaw_count + yaw_i] -> {rect: Rect2, anchor: Vector2}
var yaw_count := 32
var elevs: Array = []         # radians, ascending
var m_per_px := 1.0           # world meters per model pixel

static var _cache := {}

## --- Art pipeline (tools/carve_all.sh, danielwh2/sprite-stacking) ---
## art/stacks/NAME.png is a horizontal strip of top-down slices, ground first,
## front pointing DOWN. It becomes the voxel dictionary that bake() projects.
## The slicer already shaded the sides, so these bakes skip the extra shading.
const STACK_DIR := "res://art/stacks/"
## Visor: on these strips, pixels in the visor crimsons (hue 335-354 deg, saturation >= 0.45)
## are baked with alpha VISOR_ALPHA. df_units.gdshader finds that alpha and shimmers a red
## gradient over them. To get the effect in new art: paint the visor in those crimsons
## (other reds, like the fin tip ee2222, sit at hue ~0 and do not shimmer).
const VISOR_STRIPS := ["jet_player"]
const VISOR_ALPHA := 250.0 / 255.0

static func is_visor_color(c: Color) -> bool:
	return c.h >= 0.93 and c.h <= 0.985 and c.s >= 0.45 and c.v >= 0.3

static func has_strip(name: String) -> bool:
	return ResourceLoader.exists(STACK_DIR + name + ".png") or FileAccess.file_exists(STACK_DIR + name + ".png")

static func strip_voxels(name: String) -> Dictionary:
	var img: Image = null
	# Raw PNG first (dev builds): a freshly carved strip works without a re-import.
	var raw := ProjectSettings.globalize_path(STACK_DIR + name + ".png")
	if FileAccess.file_exists(raw):
		img = Image.load_from_file(raw)
	if img == null and ResourceLoader.exists(STACK_DIR + name + ".png"):
		var tex := load(STACK_DIR + name + ".png") as Texture2D
		if tex:
			img = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STACK_DIR + name + ".json"))
	var n := int(meta.slices)
	var w := img.get_width() / n
	var h := img.get_height()
	var visor := VISOR_STRIPS.has(name)
	var v := {}
	for k in n:
		for row in h:
			for col in w:
				var c := img.get_pixel(k * w + col, row)
				if c.a > 0.5:
					# front (row h-1) -> most negative z (forward = -z).
					# Nose-down top view: the pilot's right (+x) is on the image LEFT -> x = c - col.
					var a := VISOR_ALPHA if (visor and is_visor_color(c)) else 1.0
					v[Vector3i((w - 1) / 2 - col, k, (h - 1) / 2 - row)] = Color(c.r, c.g, c.b, a)
	# Drop fully hidden voxels: same picture, far less baking work.
	var shell := {}
	for p in v:
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			if not v.has(p + d):
				shell[p] = v[p]
				break
	return shell

static func extent(voxels: Dictionary) -> float:
	var mn := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var mx := -mn
	for p in voxels:
		mn = Vector3i(mini(mn.x, p.x), mini(mn.y, p.y), mini(mn.z, p.z))
		mx = Vector3i(maxi(mx.x, p.x), maxi(mx.y, p.y), maxi(mx.z, p.z))
	var d := mx - mn + Vector3i.ONE
	return float(maxi(d.x, maxi(d.y, d.z)))

## Bake from the carved strip when it exists. World size stays the same as the
## old code model (`fallback`), so collision radii and gameplay do not change.
static var _art_cache := {}    # name -> DfSprites: skip the disk read + voxel decode on repeat calls

## fallback: the code model (Dictionary), or a Callable that returns it (lazy: not built
## when a baked file is used).
static func bake_art(name: String, fallback: Variant, yaw_count: int, elevs_deg: Array, m_per_px: float) -> DfSprites:
	if _art_cache.has(name):
		return _art_cache[name]
	var s: DfSprites
	if not has_strip(name):
		s = bake(name, fallback, yaw_count, elevs_deg, m_per_px)
	else:
		var fb := _lazy(fallback)
		s = _cached("art_" + name, [yaw_count, elevs_deg, m_per_px, "art"],
			func() -> String:
				return FileAccess.get_md5(STACK_DIR + name + ".png") + FileAccess.get_md5(STACK_DIR + name + ".json") + str(extent(fb.call())),
			func() -> DfSprites:
				var vox := strip_voxels(name)
				var mpp := m_per_px * extent(fb.call()) / maxf(1.0, extent(vox))
				return _bake_now(vox, yaw_count, elevs_deg, mpp, false))
	_art_cache[name] = s
	return s

# =====================================================================
# Baked-atlas cache (slice 16r). Baking in GDScript costs ~6.5 s on desktop at match start
# (boss alone 3.2 s); on a phone (WebAssembly) several times more. So the bakes are saved
# once to art/baked/<key>.png + .json (tools/bake_sprites.sh; CI re-bakes before every web
# export) and loaded in milliseconds.
# - Exported build: trusts the baked files (no hashing, no model building).
# - Dev run: checks a hash of the source (strip PNG + JSON, or the code model) and the bake
#   settings. Stale or missing = bake live, as before, and print a WARN.
# =====================================================================
const BAKED_DIR := "res://art/baked/"
static var write_baked := OS.get_cmdline_user_args().has("--bakesprites")
static var trust_baked := OS.has_feature("template")    # exported game
static var stats := {"loaded": 0, "baked": 0}            # for tests

## Memo wrapper: Dictionary or Callable -> Callable that builds the value once.
static func _lazy(v: Variant) -> Callable:
	if v is Callable:
		var memo := []
		return func() -> Dictionary:
			if memo.is_empty():
				memo.append(v.call())
			return memo[0]
	return func() -> Dictionary: return v

static func _cached(key: String, params: Array, src_hash: Callable, build: Callable) -> DfSprites:
	if _cache.has(key):
		return _cache[key]
	var h := ""
	if not trust_baked:
		h = "%d_%s" % [var_to_str(params).hash(), src_hash.call()]
	var s: DfSprites = null if write_baked else _load_baked(key, h)
	if s != null:
		stats.loaded += 1
	else:
		if FileAccess.file_exists(BAKED_DIR + key + ".json") and not write_baked:
			push_warning("DfSprites: art/baked/%s is stale, baking live. Run: bash tools/bake_sprites.sh" % key)
		s = build.call()
		stats.baked += 1
		if write_baked:
			_save_baked(key, s, h)
	_cache[key] = s
	return s

static func _load_baked(key: String, h: String) -> DfSprites:
	var jp := BAKED_DIR + key + ".json"
	if not FileAccess.file_exists(jp):
		return null
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(jp))
	if not meta is Dictionary or (h != "" and String(meta.get("hash", "")) != h):
		return null
	var tex: Texture2D = null
	var raw := ProjectSettings.globalize_path(BAKED_DIR + key + ".png")
	if not trust_baked and FileAccess.file_exists(raw):
		var img := Image.load_from_file(raw)     # dev: the fresh PNG, even before a re-import
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex == null and ResourceLoader.exists(BAKED_DIR + key + ".png"):
		tex = load(BAKED_DIR + key + ".png")
	if tex == null:
		return null
	var s := DfSprites.new()
	s.atlas = tex
	s.yaw_count = int(meta.yaw_count)
	s.m_per_px = float(meta.m_per_px)
	for e in meta.elevs:
		s.elevs.append(float(e))
	for f in meta.frames:
		s.frames.append({"rect": Rect2(f[0], f[1], f[2], f[3]), "anchor": Vector2(f[4], f[5])})
	return s

static func _save_baked(key: String, s: DfSprites, h: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BAKED_DIR))
	s.atlas.get_image().save_png(ProjectSettings.globalize_path(BAKED_DIR + key + ".png"))
	var fr: Array = []
	for f in s.frames:
		var r: Rect2 = f.rect
		var a: Vector2 = f.anchor
		fr.append([r.position.x, r.position.y, r.size.x, r.size.y, a.x, a.y])
	var meta := {"key": key, "hash": h, "yaw_count": s.yaw_count, "m_per_px": s.m_per_px, "elevs": s.elevs, "frames": fr}
	var f := FileAccess.open(ProjectSettings.globalize_path(BAKED_DIR + key + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
	f.close()

## voxels: Vector3i(x, y, z) -> Color. y = slice (height), forward = -z.
## voxels: Dictionary, or a Callable that returns it (lazy: not built when a baked file is used).
static func bake(key: String, voxels: Variant, yaw_count: int, elevs_deg: Array, m_per_px := 1.0, shade := true) -> DfSprites:
	var vx := _lazy(voxels)
	return _cached(key, [yaw_count, elevs_deg, m_per_px, shade],
		func() -> String: return str(vx.call().hash()),
		func() -> DfSprites: return _bake_now(vx.call(), yaw_count, elevs_deg, m_per_px, shade))

static func _bake_now(voxels: Dictionary, yaw_count: int, elevs_deg: Array, m_per_px: float, shade: bool) -> DfSprites:
	var s := DfSprites.new()
	s.yaw_count = yaw_count
	s.m_per_px = m_per_px
	for e in elevs_deg:
		s.elevs.append(deg_to_rad(e))
	var imgs: Array = []
	var cell := Vector2i.ZERO
	for ei in s.elevs.size():
		for yi in yaw_count:
			var r := _bake_frame(voxels, TAU * yi / yaw_count, s.elevs[ei], shade)
			imgs.append(r)
			cell = Vector2i(maxi(cell.x, r.img.get_width()), maxi(cell.y, r.img.get_height()))
	var cols := int(ceilf(sqrt(float(imgs.size()))))
	var rows := int(ceilf(float(imgs.size()) / cols))
	var atlas_img := Image.create(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	atlas_img.fill(Color(0, 0, 0, 0))
	for i in imgs.size():
		var o := Vector2i((i % cols) * cell.x, (i / cols) * cell.y)
		var im: Image = imgs[i].img
		atlas_img.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), o)
		s.frames.append({"rect": Rect2(o, im.get_size()), "anchor": imgs[i].anchor})
	s.atlas = ImageTexture.create_from_image(atlas_img)
	return s

## One view. Viewer looks from +Z (behind a -Z-facing model), raised by `elev`.
static func _bake_frame(voxels: Dictionary, a: float, elev: float, shade := true) -> Dictionary:
	var ca := cos(a)
	var sa := sin(a)
	var se := sin(elev)
	var ce := cos(elev)
	var pts: Array = []
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	var w := absf(ca) + absf(sa)
	var h := w * absf(se) + absf(ce)
	for v in voxels:
		var rx: float = v.x * ca - v.z * sa
		var rz: float = v.x * sa + v.z * ca
		var sx := rx
		var sy: float = rz * se - v.y * ce
		var depth: float = v.y * se + rz * ce
		var col: Color = voxels[v]
		var above := voxels.has(v + Vector3i(0, 1, 0))
		var below := voxels.has(v + Vector3i(0, -1, 0))
		if not shade:
			if elev < 0.0 and not below:
				col = col.darkened(0.35)   # belly: the slicer has no underside colour
		elif elev >= 0.0 and above:
			col = col.darkened(1.0 - SIDE_SHADE)
		elif elev < 0.0:
			col = col.darkened(1.0 - (UNDER_SHADE if not below else SIDE_SHADE))
		pts.append([depth, sx, sy, col])
		mn = Vector2(minf(mn.x, sx - w * 0.5), minf(mn.y, sy - h * 0.5))
		mx = Vector2(maxf(mx.x, sx + w * 0.5), maxf(mx.y, sy + h * 0.5))
	pts.sort_custom(func(p, q): return p[0] < q[0])
	var off := Vector2(floorf(mn.x) - 1.0, floorf(mn.y) - 1.0)
	var size := Vector2i(int(ceilf(mx.x - off.x)) + 2, int(ceilf(mx.y - off.y)) + 2)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for p in pts:
		var x0 := int(floorf(p[1] - w * 0.5 - off.x + 0.5))
		var x1 := int(floorf(p[1] + w * 0.5 - off.x - 0.5))
		var y0 := int(floorf(p[2] - h * 0.5 - off.y + 0.5))
		var y1 := int(floorf(p[2] + h * 0.5 - off.y - 0.5))
		for yy in range(y0, maxi(y0, y1) + 1):
			for xx in range(x0, maxi(x0, x1) + 1):
				img.set_pixel(xx, yy, p[3])
	_outline(img)
	return {"img": img, "anchor": -off}

## One dark outline around the finished sprite (never per slice).
static func _outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.0:
					img.set_pixel(x, y, DfPal.OUTLINE)
					break

## rel_yaw: heading of the camera around the object, in the object's frame (0 = from behind).
func frame_for(rel_yaw: float, elev: float) -> Dictionary:
	var yi := posmod(int(roundf(rel_yaw / TAU * yaw_count)), yaw_count)
	var ei := 0
	var best := INF
	for i in elevs.size():
		var d := absf(elevs[i] - elev)
		if d < best:
			best = d
			ei = i
	return frames[ei * yaw_count + yi]
