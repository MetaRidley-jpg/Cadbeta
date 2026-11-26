class_name DfKoi
extends RefCounted
## Giant sky koi. T, 2026-11-25:
##   "giant colored koi fish in the sky above the clouds but visible, to add to aesthetic"
##   "Multicolored koi, translucent effect wavering on them semi translucent, reacts to the
##    effects and swims away from explosions and weather"
## Pure scenery: they never touch gameplay. Each koi swims a slow wide circle 345-470 m up
## (clouds 150-330 m, flight ceiling 300 m).
##   Then T sent the Cyberpunk 2077 Japantown holo-koi as the target: "More like this".
## - Holographic + multicolored: two-tone hologram palettes (body / rim light / fin strands).
##   DfRender draws a translucent dark core (normal blend) plus an ADDITIVE glow layer: halo,
##   bright rim, moving scan bands, scale lights, long flowing strand fins and tail,
##   whiskers, a glowing eye ring, drifting sparkles and a rare glitch.
## - Translucent: body alpha wavers in a wave that runs down the body.
## - Reacts (step()): explosions, laser kills, the asteroid and lightning SCARE nearby koi:
##   they bolt (6x speed, frantic tail), get pushed away from the blast and climb, then
##   calm down and drift back. Weather moves them: they climb away from rain, mostly hide
##   above the storm, scatter from the erupting volcano and the asteroid.

const SEGS := 18
const OUTLINE := Color("1a1016")
# Holographic koi (T's reference: the Japantown holo-koi in Cyberpunk 2077): each fish is a
# two-tone hologram. body = core hue, edge = rim / scan / scale light, fin = fin strand hue.
const PALETTES := [
	{"name": "cyan ghost", "body": Color("1f9dff"), "edge": Color("aef7ff"), "fin": Color("62e6ff")},
	{"name": "gold leaf", "body": Color("ff951f"), "edge": Color("ffe8a6"), "fin": Color("ffc84a")},
	{"name": "gold + ice", "body": Color("ffa832"), "edge": Color("fff0c4"), "fin": Color("4fc8ff")},
	{"name": "sakura", "body": Color("ff3d7a"), "edge": Color("ffc6dc"), "fin": Color("ff8ab4")},
	{"name": "violet + pink", "body": Color("7a4dff"), "edge": Color("dcd0ff"), "fin": Color("ff6ad5")},
	{"name": "jade", "body": Color("19d99a"), "edge": Color("c4ffe8"), "fin": Color("7affd0")},
	{"name": "rainbow", "body": Color("ff5ca8"), "edge": Color("ffffff"), "fin": Color("5ad8ff"), "rainbow": true},
]
# extra height (m) each weather pushes them to; storm/impact mostly hide them in the fog
const WEATHER_LIFT := {"morning": 0.0, "rain": 50.0, "storm": 230.0, "eruption": 110.0, "impact": 180.0, "night": 0.0}

var fish: Array = []

func build(seed_value: int) -> void:
	fish.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	var order: Array = range(PALETTES.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for i in 6:
		var a := rng.randf() * TAU
		var cr := rng.randf_range(0.0, 700.0)
		fish.append({
			"center": Vector2(cos(a) * cr, sin(a) * cr),
			"radius": rng.randf_range(420.0, 1100.0),
			"alt": rng.randf_range(345.0, 470.0),
			"speed": rng.randf_range(0.018, 0.032),     # a calm lap takes 3-6 minutes
			"ang": rng.randf() * TAU,
			"phase": rng.randf() * TAU,
			"length": rng.randf_range(240.0, 380.0),    # GIANT: a jet is 9 m long
			"pal": PALETTES[order[i]],
			"dir": -1.0 if i % 2 else 1.0,
			"scare": 0.0,          # 0..1: how spooked it is right now
			"push": Vector3.ZERO,  # displacement away from what scared it (m)
			"push_v": Vector3.ZERO,
			"lift": 0.0,           # extra height from weather + fear (m)
			"wig": 0.0,            # tail-beat phase (beats faster when scared)
		})

## threats: Array of {pos: Vector3, power: float (1 = a normal kill)}. preset = weather name.
func step(dt: float, preset: String, threats: Array, volcano := Vector3.INF) -> void:
	for f in fish:
		var head := _head(f)
		for th in threats:
			var pw: float = th.power
			var reach := 650.0 * pw
			var to: Vector3 = head - th.pos
			var d := to.length()
			if d < reach:
				var s := (1.0 - d / reach) * clampf(pw, 0.3, 1.0)
				f.scare = maxf(f.scare, s)
				var away := (to + Vector3.UP * d * 0.4).normalized()
				f.push_v += away * 220.0 * s
		if preset == "eruption" and volcano != Vector3.INF:     # the volcano: keep clear
			var tv := Vector3(head.x - volcano.x, 0.0, head.z - volcano.z)
			if tv.length() < 1000.0:
				f.push_v += tv.normalized() * 30.0 * dt
		f.push += f.push_v * dt
		f.push_v *= exp(-1.6 * dt)
		f.push = f.push.lerp(Vector3.ZERO, clampf(0.05 * dt, 0.0, 1.0))   # drift slowly home
		f.scare = maxf(0.0, f.scare - 0.22 * dt)
		var s2: float = f.scare
		f.ang += float(f.speed) * float(f.dir) * (1.0 + 6.0 * s2) * dt
		f.wig += dt * 1.6 * (1.0 + 2.5 * s2)
		var want: float = WEATHER_LIFT.get(preset, 0.0) + s2 * 140.0
		f.lift = lerpf(f.lift, want, clampf(0.35 * dt, 0.0, 1.0))

func _head(f: Dictionary) -> Vector3:
	var c: Vector2 = f.center + Vector2(cos(f.ang), sin(f.ang)) * float(f.radius)
	return Vector3(c.x, float(f.alt) + float(f.lift), c.y) + f.push

## World positions of the spine, head first, at time t.
func spine(f: Dictionary, t: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var R: float = f.radius
	var L: float = f.length
	var step: float = (L / SEGS) / R * float(f.dir)
	var amp := 0.07 * (1.0 + 0.6 * float(f.scare))
	for i in SEGS:
		var ang: float = f.ang - step * i
		var c: Vector2 = f.center + Vector2(cos(ang), sin(ang)) * R
		var k := float(i) / (SEGS - 1)
		var sway := sin(float(f.wig) - i * 0.45 + float(f.phase)) * L * amp * (0.15 + k)
		c += Vector2(cos(ang), sin(ang)) * sway
		var y: float = float(f.alt) + float(f.lift) + sin(t * 0.25 + float(f.phase)) * 12.0
		pts.append(Vector3(c.x, y, c.y) + f.push)
	return pts

## Body half-width (m) at segment i: a chunky koi (T's reference). Big round head,
## deep body that stays wide to 55%, then a quick taper to a sturdy tail stalk.
static func width(f: Dictionary, i: int) -> float:
	var k := float(i) / (SEGS - 1)
	var prof: float
	if k < 0.22:
		prof = 0.7 + 0.3 * sin(k / 0.22 * PI * 0.5)
	elif k < 0.55:
		prof = 1.0 - (k - 0.22) * 0.25
	else:
		prof = lerpf(0.92, 0.26, pow((k - 0.55) / 0.45, 1.1))
	return float(f.length) * 0.135 * prof

## Core color of segment i: ONE body hue that melts smoothly into the fin hue toward the
## tail (no stripes: stripes read as a grub). The rainbow koi's hue runs down the body.
static func color(f: Dictionary, i: int, t := 0.0) -> Color:
	var p: Dictionary = f.pal
	var k := float(i) / (SEGS - 1)
	if p.get("rainbow", false):
		return Color.from_hsv(fposmod(float(f.phase) * 0.1 + i * 0.03 - t * 0.06, 1.0), 0.7, 1.0)
	return Color(p.body).lerp(p.fin, smoothstep(0.45, 1.0, k) * 0.6)

## Koi markings: 0..1 patch strength at segment i, across-body offset u (-1..1).
## Soft blobs on the back in the edge color (kohaku-style patches, a hologram version).
static func patch(f: Dictionary, i: int, u: float) -> float:
	var seed_f: float = f.phase
	var v := sin(i * 0.9 + seed_f * 3.0) * 0.6 + sin(i * 0.37 - seed_f) * 0.5 + u * 0.4 * sin(seed_f * 5.0)
	return clampf((v - 0.35) * 2.5, 0.0, 1.0)

## Translucency at segment i: a wave of alpha that runs down the body (0.5 .. 0.85).
static func alpha_at(f: Dictionary, i: int, t: float) -> float:
	return 0.675 + 0.175 * sin(t * 2.2 - i * 0.7 + float(f.phase))

## 0..1 shimmer highlight that travels head -> tail.
static func shimmer(f: Dictionary, i: int, t: float) -> float:
	return clampf((sin(t * 1.3 - i * 0.5 + float(f.phase) * 2.0) - 0.55) * 2.2, 0.0, 1.0)
