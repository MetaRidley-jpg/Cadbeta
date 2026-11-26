extends Node
## Autoload "Sfx": placeholder retro sound effects (tools/make_sfx.py writes audio/sfx/*.wav).
## Drop a real sound with the same name (.ogg or .wav) into audio/sfx/ to replace one.
## Sfx.play("gun"), Sfx.loop("boost_loop", true/false). Mute: Game.sfx_on (Fold page).

const DIR := "res://audio/sfx/"
const VOICES := 14
const MAX_SAME := 3          # at most 3 copies of one sound at once (guns fire fast)

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _loops := {}             # name -> AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# a hard limiter on the master bus: stacked explosions duck instead of clipping
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, lim)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

func _stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var s: AudioStream = null
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(DIR + name + ext):
			s = load(DIR + name + ext)
			break
	_streams[name] = s
	return s

func on() -> bool:
	return Game.sfx_on and DisplayServer.get_name() != "headless"

## pitch_var: random pitch spread (+/-), so repeated sounds do not drone.
func play(name: String, db := 0.0, pitch_var := 0.06) -> void:
	if not on():
		return
	var s := _stream(name)
	if s == null:
		return
	var same := 0
	var free: AudioStreamPlayer = null
	for p in _pool:
		if p.playing:
			if p.stream == s:
				same += 1
		elif free == null:
			free = p
	if same >= MAX_SAME or free == null:
		return
	free.stream = s
	free.volume_db = db
	free.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	free.play()

func loop(name: String, playing: bool, db := 0.0, pitch := 1.0) -> void:
	if not playing or not on():
		if _loops.has(name) and _loops[name].playing:
			_loops[name].stop()
		return
	if not _loops.has(name):
		var s := _stream(name)
		if s == null:
			return
		if s is AudioStreamWAV:
			s = s.duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		var p := AudioStreamPlayer.new()
		p.stream = s
		add_child(p)
		_loops[name] = p
	var lp: AudioStreamPlayer = _loops[name]
	lp.volume_db = db
	lp.pitch_scale = pitch
	if not lp.playing:
		lp.play()

func stop_loops() -> void:
	for k in _loops:
		_loops[k].stop()
