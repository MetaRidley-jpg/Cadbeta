class_name DfWeather
extends RefCounted
## Weather = time passing. Data only; DfRender draws it (sky bands, haze, rain, ash, flashes).
## 1 morning, 2 rain, 3 fog + thunder, 4 volcano eruption (lava + smog), 5 asteroid, 6+ night storms.
## tint = multiplies the final picture (set on the view container, so shaders are not affected).

signal lightning
signal asteroid_impact(point: Vector3)

## sky_top / sky_mid / horizon = flat sky bands. fog = distance haze color (a = strength).
# "ambient" (16g): daylight on the ground + scenery. The beach set is drawn in daylight colors;
# without this the white sand, emerald shallows and green stacks glowed in storm and at night.
const PRESETS := {
	"morning":  {"ambient": Color(1, 1, 1), "tint": Color(1, 1, 1), "fog": Color(0.66, 0.86, 1.0, 0.55), "deep": DfPal.SEA_DEEP, "sea": DfPal.SEA, "light": DfPal.SEA_LIGHT,
		"sky_top": Color("1d6fe0"), "sky_mid": Color("4fa8ff"), "horizon": Color("a8dcff")},
	"rain":     {"ambient": Color(0.74, 0.8, 0.88), "tint": Color("dfe8f7"), "fog": Color(0.55, 0.64, 0.78, 0.75), "deep": Color("0b2f6b"), "sea": Color("17539c"), "light": Color("3f8fd6"),
		"sky_top": Color("3c4f78"), "sky_mid": Color("5f7398"), "horizon": Color("8e9db8")},
	"storm":    {"ambient": Color(0.5, 0.56, 0.68), "tint": Color("b9c2dc"), "fog": Color(0.36, 0.4, 0.52, 0.92), "deep": Color("0a2148"), "sea": Color("123c74"), "light": Color("2b6aad"),
		"sky_top": Color("1c2238"), "sky_mid": Color("2e3652"), "horizon": Color("4c5470")},
	"eruption": {"ambient": Color(0.72, 0.5, 0.46), "tint": Color("ffe6d6"), "fog": Color(0.42, 0.26, 0.28, 0.8), "deep": Color("101a45"), "sea": Color("232f6e"), "light": Color("ff6a00"),
		"sky_top": Color("2a1030"), "sky_mid": Color("6a1f2a"), "horizon": Color("ff5a1f")},
	"impact":   {"ambient": Color(0.9, 0.66, 0.66), "tint": Color("ffe0c8"), "fog": Color(0.98, 0.55, 0.28, 0.6), "deep": Color("171450"), "sea": Color("2e2a80"), "light": Color("ffb000"),
		"sky_top": Color("3a1a6a"), "sky_mid": Color("d0407a"), "horizon": Color("ffb35a")},
	"night":    {"ambient": Color(0.42, 0.5, 0.8), "tint": Color("8a94d8"), "fog": Color(0.07, 0.09, 0.22, 0.85), "deep": Color("05103a"), "sea": Color("0b2563"), "light": Color("1d4fa0"),
		"sky_top": Color("02040f"), "sky_mid": Color("0a1230"), "horizon": Color("1e2a5a")},
}

var world: DfWorld
var preset := "morning"
var cur := {}
## T (2026-11-26): "make the transitions between weather smoother and longer".
## Colors ease over BLEND_TIME (smoothstep, was a 4 s straight lerp). Rain, ash and thunder
## no longer switch on/off: their amounts (0..1) ramp over FX_RAMP. The old flags are
## derived from the amounts (rain shows from the first drop; lava + thunder only past half).
const BLEND_TIME := 12.0
const FX_RAMP := 9.0
var rain_on := false
var thunder_on := false
var erupting := false
var rain_amt := 0.0
var ash_amt := 0.0
var thunder_amt := 0.0
var _rain_to := 0.0
var _ash_to := 0.0
var _thunder_to := 0.0
var _from := {}
var _to := {}
var _blend := 1.0
var _lightning_t := 5.0
var _flash := 0.0
# asteroid
var asteroid_active := false
var asteroid_t := 0.0
var asteroid_time := 10.0
var asteroid_target := Vector3.ZERO
var _asteroid_start := Vector3.ZERO
var asteroid_pos := Vector3.ZERO
static var asteroid_sprites: DfSprites

func setup(w: DfWorld) -> void:
	world = w
	set_preset("morning", true)

func set_preset(name: String, instant := false) -> void:
	preset = name
	_from = cur.duplicate() if not cur.is_empty() else PRESETS[name].duplicate()
	_to = PRESETS[name].duplicate()
	_blend = 1.0 if instant else 0.0
	if instant:
		cur = _to.duplicate()
	_rain_to = 1.0 if name in ["rain", "storm", "night"] else 0.0
	_thunder_to = 1.0 if name in ["storm", "night"] else 0.0
	_ash_to = 1.0 if name in ["eruption", "impact", "night"] else 0.0
	if instant:
		rain_amt = _rain_to
		thunder_amt = _thunder_to
		ash_amt = _ash_to
	_update_flags()

func _update_flags() -> void:
	rain_on = rain_amt > 0.01
	thunder_on = thunder_amt > 0.5
	erupting = ash_amt > 0.5

## 0..1 progress of the color blend (tests).
func blend_progress() -> float:
	return _blend

func tick(dt: float) -> void:
	if _blend < 1.0:
		_blend = minf(1.0, _blend + dt / BLEND_TIME)
		var e := _blend * _blend * (3.0 - 2.0 * _blend)
		for k in _to:
			cur[k] = (_from[k] as Color).lerp(_to[k], e)
	rain_amt = move_toward(rain_amt, _rain_to, dt / FX_RAMP)
	ash_amt = move_toward(ash_amt, _ash_to, dt / FX_RAMP)
	thunder_amt = move_toward(thunder_amt, _thunder_to, dt / FX_RAMP)
	_update_flags()
	if thunder_on:
		_lightning_t -= dt
		if _lightning_t <= 0.0:
			_lightning_t = randf_range(4.0, 10.0)
			_flash = 1.0
			lightning.emit()
	_flash = maxf(0.0, _flash - dt * 3.0)
	if asteroid_active:
		asteroid_t += dt
		var k := clampf(asteroid_t / asteroid_time, 0.0, 1.0)
		asteroid_pos = _asteroid_start.lerp(asteroid_target, k * k)
		if k >= 1.0:
			asteroid_active = false
			asteroid_impact.emit(asteroid_target)

func flash_amount() -> float:
	return _flash

## viewer = player position, so the rock comes from the far side of the target.
func start_asteroid(target: Vector3, warn_time := 10.0, viewer := Vector3.ZERO) -> void:
	asteroid_active = true
	asteroid_t = 0.0
	asteroid_time = warn_time
	asteroid_target = target
	var away := Vector3(target.x - viewer.x, 0.0, target.z - viewer.z)
	away = away.normalized() if away.length() > 1.0 else Vector3.FORWARD
	# far out and high, on the far side of the target from the viewer: it is in view (as a
	# burning dot with a streak) for the whole countdown and grows as it comes in
	# it comes in at an angle across the view, so its burning streak shows (head-on, the
	# rock hides its own trail)
	away = away.rotated(Vector3.UP, 1.2)
	_asteroid_start = target + away * 4200.0 + Vector3.UP * 2300.0
	asteroid_pos = _asteroid_start
	rock_sprites()

## The burning rock sprite (asteroid + debris + boss wreckage). Baked once, on first use.
static func rock_sprites() -> DfSprites:
	if asteroid_sprites == null:
		asteroid_sprites = DfSprites.bake_art("asteroid", _rock_model, 8, [-20, 10, 40], 4.0)
	return asteroid_sprites

static func _rock_model() -> Dictionary:
	var v := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for x in range(-10, 11):
		for y in range(-10, 11):
			for z in range(-10, 11):
				var p := Vector3(x, y, z)
				var r := p.length()
				if r <= 9.3 + rng.randf() * 0.9 and r > 7.5:   # shell only
					v[Vector3i(x, y + 10, z)] = DfPal.FIRE if (rng.randf() < 0.22 or y > 5) else DfPal.ROCK
	return v

func asteroid_position() -> Vector3:
	return asteroid_pos

func asteroid_start() -> Vector3:
	return _asteroid_start
