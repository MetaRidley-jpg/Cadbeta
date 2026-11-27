class_name DfProf
## Opt-in per-stage timer for the dogfight (flag `--dfprof`). Off = one bool check per call.
## Usage: var t := DfProf.t0()  ...work...  DfProf.add("stage", t)
## Prints "PROF <stage> avg_ms max_ms" for every stage once per WINDOW frames (from tick()).

const WINDOW := 120
static var on := _detect()

## On: the `--dfprof` flag, or `?prof` in the web page address (T's phone:
## https://metaridley-jpg.github.io/Cadbeta/?prof). Shows a readout in the dogfight HUD.
static func _detect() -> bool:
	if OS.get_cmdline_user_args().has("--dfprof"):
		return true
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("window.location.search", true)
		return q is String and String(q).contains("prof")
	return false

## HUD readout: fps, script ms per frame (sum of stages), the 3 costliest stages.
static func readout() -> PackedStringArray:
	var lines := PackedStringArray()
	if last.is_empty():
		lines.append("PROF: measuring...")
		return lines
	var tot := 0.0
	var st: Array = []
	for k in last:
		if not String(k).begins_with("n_"):
			tot += last[k]
			st.append([last[k], k])
	st.sort_custom(func(a, b): return a[0] > b[0])
	lines.append("FPS %d  script %.1f ms" % [Engine.get_frames_per_second(), tot])
	for i in mini(3, st.size()):
		lines.append("%s %.1f" % [st[i][1], st[i][0]])
	return lines
static var _sum := {}
static var _max := {}
static var _frames := 0
static var last := {}     # last window's averages (ms), for tests / the on-screen readout

static func t0() -> int:
	return Time.get_ticks_usec() if on else 0

static func add(stage: String, start: int) -> void:
	if not on:
		return
	var ms := (Time.get_ticks_usec() - start) / 1000.0
	_sum[stage] = _sum.get(stage, 0.0) + ms
	_max[stage] = maxf(_max.get(stage, 0.0), ms)

## Record a plain number (item counts): averaged like the times.
static func val(stage: String, v: float) -> void:
	if not on:
		return
	_sum[stage] = _sum.get(stage, 0.0) + v
	_max[stage] = maxf(_max.get(stage, 0.0), v)

## Call once per frame (DfGame._process).
static func tick() -> void:
	if not on:
		return
	_frames += 1
	if _frames < WINDOW:
		return
	var keys: Array = _sum.keys()
	keys.sort()
	var line := "PROF fps=%d" % Engine.get_frames_per_second()
	last.clear()
	for k in keys:
		last[k] = _sum[k] / _frames
		line += "  %s=%.2f/%.1f" % [k, last[k], _max[k]]
	print(line)
	_sum.clear()
	_max.clear()
	_frames = 0
